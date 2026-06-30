import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class AppState extends ChangeNotifier {
  // ── Insumos dinámicos
  List<InsumoModel> insumos = kDefaultInsumos();

  // ── Stock de insumos (insumoId → StockEntry)
  Map<String, StockEntry> stock = {};

  // ── Ventas registradas
  List<Venta> ventas = [];

  // ── Combos editables
  List<Combo> combos = [];

  // ── Productos del menú
  List<Producto> productos = [];

  // ── Stock inicial de productos (id → cantidad inicial)
  Map<String, int> stockInicialProductos = {};

  // ── Vendidos extra de productos (consumidos por combos, no directamente)
  Map<String, int> _stockVendidosProductosExtra = {};

  // ── Proveedores y pedidos
  List<Proveedor> proveedores = [];
  List<PedidoProveedor> pedidos = [];

  // ── Stock mínimo (para alertas)
  Map<String, int> stockMinimoInsumos = {};
  Map<String, int> stockMinimoProductos = {};

  // ── Precios de compra más recientes (para calcular márgenes)
  // key: "i_${insumo.index}" para insumos, "p_${id}" para productos
  Map<String, int> preciosCompra = {};

  // ── Firestore
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Estado de carga inicial
  bool isLoading = true;

  // ── Legacy SharedPreferences keys (solo para migración)
  static const _kStock          = 'stock_v3';
  static const _kVentas         = 'ventas_v2';
  static const _kCombos         = 'combos_v2';
  static const _kProductos      = 'productos_v1';
  static const _kStockProductos = 'stock_productos_v1';
  static const _kVendidosExtra  = 'vendidos_extra_v1';

  AppState() { _init(); }

  // ── Derived ────────────────────────────────────────────────────────────────

  int get totalRecaudado =>
      ventas.fold(0, (s, v) => s + v.precioTotal + v.propina);

  int get totalPropinas => ventas.fold(0, (s, v) => s + v.propina);

  int recaudadoPorMedio(MedioPago m) {
    final ventas_ = ventas.where((v) => v.medioPago == m).fold(0, (s, v) => s + v.precioTotal);
    final propinas = ventas.where((v) => v.propinaMedioPago == m).fold(0, (s, v) => s + v.propina);
    return ventas_ + propinas;
  }

  int ventasPorCombo(String comboId) => ventas
      .expand((v) => v.items)
      .where((it) => it.comboId == comboId)
      .length;

  int stockVendidosProducto(String id) {
    final directo = ventas
        .expand((v) => v.items)
        .where((it) => it.comboId == id)
        .fold(0, (s, it) => s + it.cantidad);
    return directo + (_stockVendidosProductosExtra[id] ?? 0);
  }

  int gastoConProveedor(String proveedorId) => pedidos
      .where((p) => p.proveedorId == proveedorId && p.estado == EstadoPedido.recibido)
      .fold(0, (s, p) => s + p.costoTotal);

  /// Costo estimado de un producto en base a precios de compra registrados.
  /// Retorna null si no hay suficiente información.
  int? costoEstimadoProducto(Producto p) {
    // Producto sin componentes: precio de compra directo
    if (p.insumosConsumidos.isEmpty && p.productosConsumidos.isEmpty) {
      return preciosCompra['p_${p.id}'];
    }
    int costo = 0;
    for (final e in p.insumosConsumidos.entries) {
      final precio = preciosCompra['i_${e.key}'];
      if (precio == null) return null;
      costo += precio * e.value;
    }
    for (final e in p.productosConsumidos.entries) {
      final precio = preciosCompra['p_${e.key}'];
      if (precio == null) return null;
      costo += precio * e.value;
    }
    return costo;
  }

  bool stockBajoMinimo(String insumoId) {
    final min = stockMinimoInsumos[insumoId];
    if (min == null || min == 0) return false;
    return (stock[insumoId]?.actual ?? 0) < min;
  }

  bool stockProductoBajoMinimo(String id) {
    final min = stockMinimoProductos[id];
    if (min == null || min == 0) return false;
    final actual = (stockInicialProductos[id] ?? 0) - stockVendidosProducto(id);
    return actual < min;
  }

  bool get hayStockBajoMinimo =>
      insumos.any((i) => stockBajoMinimo(i.id)) ||
      productos.any((p) => stockProductoBajoMinimo(p.id));

  // ── Init & Migration ───────────────────────────────────────────────────────

  Future<void> _init() async {
    try {
      final metaDoc = await _db.collection('config').doc('meta').get();
      if (!metaDoc.exists) {
        await _migrateFromSharedPreferences();
      } else {
        await _loadFromFirestore();
      }
    } catch (e) {
      debugPrint('AppState Firestore error, usando SharedPreferences: $e');
      await _loadFromSharedPrefs();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> _loadFromFirestore() async {
    // Insumos
    final insumosDoc = await _db.collection('config').doc('insumos').get();
    if (insumosDoc.exists) {
      final list = insumosDoc.data()?['items'] as List? ?? [];
      if (list.isNotEmpty) {
        insumos = list.map((j) => InsumoModel.fromJson(Map<String, dynamic>.from(j as Map))).toList();
        _sortInsumos();
      }
    }
    _ensureStockEntries();

    // Combos
    final combosDoc = await _db.collection('config').doc('combos').get();
    if (combosDoc.exists) {
      final list = combosDoc.data()?['items'] as List? ?? [];
      combos = list
          .map((j) => Combo.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
    } else {
      combos = kDefaultCombos();
    }
    _sortCombos();

    // Productos
    final productosDoc = await _db.collection('config').doc('productos').get();
    if (productosDoc.exists) {
      final list = productosDoc.data()?['items'] as List? ?? [];
      productos = list
          .map((j) => Producto.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
    }
    _sortProductos();

    // Stock
    final stockDoc = await _db.collection('config').doc('stock').get();
    if (stockDoc.exists) {
      final data = stockDoc.data()!;
      final stockList = data['insumos'] as List? ?? [];
      for (final j in stockList) {
        final e = StockEntry.fromJson(Map<String, dynamic>.from(j as Map));
        stock[e.insumoId] = e;
      }
      _ensureStockEntries();
      final inicialProds = data['inicialProductos'] as Map<String, dynamic>? ?? {};
      stockInicialProductos = inicialProds.map((k, v) => MapEntry(k, (v as num).toInt()));
      final extra = data['vendidosExtra'] as Map<String, dynamic>? ?? {};
      _stockVendidosProductosExtra = extra.map((k, v) => MapEntry(k, (v as num).toInt()));
    }

    // Stock mínimo y precios de compra
    final stockData = stockDoc.exists ? stockDoc.data()! : <String, dynamic>{};
    final minimoIns = stockData['minimoInsumos'] as Map<String, dynamic>? ?? {};
    stockMinimoInsumos = minimoIns.map((k, v) => MapEntry(k, (v as num).toInt()));
    final minimoProds = stockData['minimoProductos'] as Map<String, dynamic>? ?? {};
    stockMinimoProductos = minimoProds.map((k, v) => MapEntry(k, (v as num).toInt()));

    final preciosDoc = await _db.collection('config').doc('precios_compra').get();
    if (preciosDoc.exists) {
      final m = preciosDoc.data() ?? {};
      preciosCompra = m.map((k, v) => MapEntry(k, (v as num).toInt()));
    }

    // Ventas
    final ventasSnap = await _db.collection('ventas').get();
    ventas = ventasSnap.docs
        .map((d) => Venta.fromJson(Map<String, dynamic>.from(d.data())))
        .toList();
    ventas.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Proveedores
    final provSnap = await _db.collection('proveedores').get();
    proveedores = provSnap.docs
        .map((d) => Proveedor.fromJson(Map<String, dynamic>.from(d.data())))
        .toList();
    proveedores.sort((a, b) => a.nombre.compareTo(b.nombre));

    // Pedidos
    final pedidosSnap = await _db.collection('pedidos').get();
    pedidos = pedidosSnap.docs
        .map((d) => PedidoProveedor.fromJson(Map<String, dynamic>.from(d.data())))
        .toList();
    pedidos.sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  Future<void> _migrateFromSharedPreferences() async {
    debugPrint('AppState: migrando SharedPreferences → Firestore...');
    await _loadFromSharedPrefs();

    // Subir config en batch
    final batch = _db.batch();
    batch.set(_db.collection('config').doc('combos'), {
      'items': combos.map((c) => c.toJson()).toList(),
    });
    batch.set(_db.collection('config').doc('productos'), {
      'items': productos.map((p) => p.toJson()).toList(),
    });
    batch.set(_db.collection('config').doc('insumos'), {
      'items': insumos.map((i) => i.toJson()).toList(),
    });
    batch.set(_db.collection('config').doc('stock'), {
      'insumos': stock.values.map((e) => e.toJson()).toList(),
      'inicialProductos': stockInicialProductos,
      'vendidosExtra': _stockVendidosProductosExtra,
    });
    batch.set(_db.collection('config').doc('meta'), {
      'migratedAt': DateTime.now().toIso8601String(),
      'version': '1.0',
    });
    await batch.commit();

    // Ventas individualmente (evita límite de 500 del batch)
    for (final v in ventas) {
      await _db.collection('ventas').doc(v.id).set(v.toJson());
    }

    debugPrint('AppState: migración completa (${ventas.length} ventas).');
  }

  Future<void> _loadFromSharedPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    _ensureStockEntries();
    final stockStr = prefs.getString(_kStock);
    if (stockStr != null) {
      final list = jsonDecode(stockStr) as List;
      for (final j in list) {
        final e = StockEntry.fromJson(j);
        stock[e.insumoId] = e;
      }
      _ensureStockEntries();
    }

    final ventasStr = prefs.getString(_kVentas) ?? prefs.getString('ventas_v1');
    if (ventasStr != null) {
      final list = jsonDecode(ventasStr) as List;
      ventas = list.map((j) => Venta.fromJson(j)).toList();
    }

    final combosStr = prefs.getString(_kCombos);
    if (combosStr != null) {
      final list = jsonDecode(combosStr) as List;
      combos = list.map((j) => Combo.fromJson(j)).toList();
    } else {
      combos = kDefaultCombos();
    }

    final productosStr = prefs.getString(_kProductos);
    if (productosStr != null) {
      final list = jsonDecode(productosStr) as List;
      productos = list.map((j) => Producto.fromJson(j)).toList();
    }

    final stockProdStr = prefs.getString(_kStockProductos);
    if (stockProdStr != null) {
      final m = jsonDecode(stockProdStr) as Map<String, dynamic>;
      stockInicialProductos = m.map((k, v) => MapEntry(k, v as int));
    }

    final extraStr = prefs.getString(_kVendidosExtra);
    if (extraStr != null) {
      final m = jsonDecode(extraStr) as Map<String, dynamic>;
      _stockVendidosProductosExtra = m.map((k, v) => MapEntry(k, v as int));
    }
  }

  // ── Firestore helpers ──────────────────────────────────────────────────────

  Future<void> _saveCombosToDb() => _db.collection('config').doc('combos').set({
        'items': combos.map((c) => c.toJson()).toList(),
      });

  Future<void> _saveProductosToDb() =>
      _db.collection('config').doc('productos').set({
        'items': productos.map((p) => p.toJson()).toList(),
      });

  void _sortInsumos()  => insumos.sort((a, b) => a.nombre.compareTo(b.nombre));
  void _sortCombos()   => combos.sort((a, b) => a.nombre.compareTo(b.nombre));
  void _sortProductos() => productos.sort((a, b) => a.nombre.compareTo(b.nombre));

  void _ensureStockEntries() {
    for (final insumo in insumos) {
      stock.putIfAbsent(insumo.id, () => StockEntry(insumoId: insumo.id, inicial: 0));
    }
  }

  Future<void> _saveInsumosToDb() => _db.collection('config').doc('insumos').set({
        'items': insumos.map((i) => i.toJson()).toList(),
      });

  Future<void> _saveStockToDb() => _db.collection('config').doc('stock').set({
        'insumos': stock.values.map((e) => e.toJson()).toList(),
        'inicialProductos': stockInicialProductos,
        'vendidosExtra': _stockVendidosProductosExtra,
        'minimoInsumos': stockMinimoInsumos,
        'minimoProductos': stockMinimoProductos,
      });

  Future<void> _savePreciosCompraToDb() =>
      _db.collection('config').doc('precios_compra').set(preciosCompra);

  Future<void> _saveVentaToDb(Venta v) =>
      _db.collection('ventas').doc(v.id).set(v.toJson());

  Future<void> _deleteVentaFromDb(String id) =>
      _db.collection('ventas').doc(id).delete();

  Future<void> _saveProveedorToDb(Proveedor p) =>
      _db.collection('proveedores').doc(p.id).set(p.toJson());

  Future<void> _deleteProveedorFromDb(String id) =>
      _db.collection('proveedores').doc(id).delete();

  Future<void> _savePedidoToDb(PedidoProveedor p) =>
      _db.collection('pedidos').doc(p.id).set(p.toJson());

  Future<void> _deletePedidoFromDb(String id) =>
      _db.collection('pedidos').doc(id).delete();

  // ── Combos CRUD ────────────────────────────────────────────────────────────

  void agregarCombo({required String nombre, required int precio,
      Map<String, int>? insumos, Map<String, int>? productosConsumidos}) {
    combos.add(Combo(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      nombre: nombre,
      precioFijo: precio,
      insumos: insumos,
      productosConsumidos: productosConsumidos,
    ));
    _sortCombos();
    _saveCombosToDb();
    notifyListeners();
  }

  void editarCombo(String id,
      {String? nombre,
      int? precio,
      Map<String, int>? insumos,
      Map<String, int>? productosConsumidos}) {
    final c = combos.firstWhere((c) => c.id == id);
    if (nombre != null) c.nombre = nombre;
    if (precio != null) c.precioFijo = precio;
    if (insumos != null) c.insumos = insumos;
    if (productosConsumidos != null) c.productosConsumidos = productosConsumidos;
    _sortCombos();
    _saveCombosToDb();
    notifyListeners();
  }

  void eliminarCombo(String id) {
    combos.removeWhere((c) => c.id == id);
    _saveCombosToDb();
    notifyListeners();
  }

  // ── Stock ──────────────────────────────────────────────────────────────────

  void setStockInicial(String insumoId, int cantidad) {
    stock.putIfAbsent(insumoId, () => StockEntry(insumoId: insumoId, inicial: 0));
    stock[insumoId]!.inicial = cantidad;
    _saveStockToDb();
    notifyListeners();
  }

  void setStockInicialProducto(String id, int cantidad) {
    stockInicialProductos[id] = cantidad;
    _saveStockToDb();
    notifyListeners();
  }

  // ── Productos CRUD ─────────────────────────────────────────────────────────

  void agregarProducto(String nombre, int precio, CategoriaProducto categoria,
      {TamanoBebida? tamanoBebida,
      Map<String, int>? insumosConsumidos,
      Map<String, int>? productosConsumidos}) {
    productos.add(Producto(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      nombre: nombre,
      precio: precio,
      categoria: categoria,
      tamanoBebida: tamanoBebida,
      insumosConsumidos: insumosConsumidos,
      productosConsumidos: productosConsumidos,
    ));
    _sortProductos();
    _saveProductosToDb();
    notifyListeners();
  }

  void editarProducto(String id,
      {String? nombre,
      int? precio,
      CategoriaProducto? categoria,
      TamanoBebida? tamanoBebida,
      bool updateTamano = false,
      Map<String, int>? insumosConsumidos,
      Map<String, int>? productosConsumidos,
      bool updateConsumos = false}) {
    final p = productos.firstWhere((p) => p.id == id);
    if (nombre != null) p.nombre = nombre;
    if (precio != null) p.precio = precio;
    if (categoria != null) p.categoria = categoria;
    if (updateTamano) p.tamanoBebida = tamanoBebida;
    if (updateConsumos) {
      p.insumosConsumidos = insumosConsumidos ?? {};
      p.productosConsumidos = productosConsumidos ?? {};
    }
    _sortProductos();
    _saveProductosToDb();
    notifyListeners();
  }

  void toggleProductoActivo(String id) {
    final p = productos.firstWhere((p) => p.id == id);
    p.activo = !p.activo;
    _saveProductosToDb();
    notifyListeners();
  }

  void eliminarProducto(String id) {
    productos.removeWhere((p) => p.id == id);
    stockInicialProductos.remove(id);
    _saveProductosToDb();
    _saveStockToDb();
    notifyListeners();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void registrarVenta({
    required List<ItemCarrito> items,
    required MedioPago medioPago,
    int propina = 0,
    MedioPago? propinaMedioPago,
  }) {
    final total = items.fold(0, (s, it) => s + it.precioTotal);
    final venta = Venta(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      items: items,
      precioTotal: total,
      medioPago: medioPago,
      timestamp: DateTime.now(),
      propina: propina,
      propinaMedioPago: propina > 0 ? (propinaMedioPago ?? medioPago) : null,
    );
    ventas.add(venta);
    _descontarStock(items);
    _saveVentaToDb(venta);
    _saveStockToDb();
    notifyListeners();
  }

  void editarMedioPago(String id, MedioPago nuevo) {
    final idx = ventas.indexWhere((v) => v.id == id);
    if (idx == -1) return;
    final v = ventas[idx];
    ventas[idx] = Venta(
      id: v.id,
      items: v.items,
      precioTotal: v.precioTotal,
      medioPago: nuevo,
      timestamp: v.timestamp,
      propina: v.propina,
      propinaMedioPago: v.propinaMedioPago,
    );
    _saveVentaToDb(ventas[idx]);
    notifyListeners();
  }

  void editarPropina(String id, int propina, MedioPago propinaMedioPago) {
    final idx = ventas.indexWhere((v) => v.id == id);
    if (idx == -1) return;
    final v = ventas[idx];
    ventas[idx] = Venta(
      id: v.id,
      items: v.items,
      precioTotal: v.precioTotal,
      medioPago: v.medioPago,
      timestamp: v.timestamp,
      propina: propina,
      propinaMedioPago: propina > 0 ? propinaMedioPago : null,
    );
    _saveVentaToDb(ventas[idx]);
    notifyListeners();
  }

  void eliminarUltimaVenta() {
    if (ventas.isEmpty) return;
    final ultima = ventas.removeLast();
    _revertirStock(ultima.items);
    _deleteVentaFromDb(ultima.id);
    _saveStockToDb();
    notifyListeners();
  }

  void eliminarVenta(String id) {
    final idx = ventas.indexWhere((v) => v.id == id);
    if (idx == -1) return;
    final venta = ventas.removeAt(idx);
    _revertirStock(venta.items);
    _deleteVentaFromDb(venta.id);
    _saveStockToDb();
    notifyListeners();
  }

  void resetDia() {
    for (final v in ventas) {
      _deleteVentaFromDb(v.id);
    }
    ventas.clear();
    for (var e in stock.values) {
      e.vendidos = 0;
      e.inicial = 0;
    }
    _stockVendidosProductosExtra.clear();
    _saveStockToDb();
    notifyListeners();
  }

  // ── Backup / Restore ───────────────────────────────────────────────────────

  Future<void> importarBackup(Map<String, dynamic> data) async {
    if (data['combos'] != null) {
      combos = (data['combos'] as List)
          .map((j) => Combo.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
      await _saveCombosToDb();
    }
    if (data['productos'] != null) {
      productos = (data['productos'] as List)
          .map((j) => Producto.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
      await _saveProductosToDb();
    }
    if (data['stock'] != null) {
      for (final j in data['stock'] as List) {
        final e = StockEntry.fromJson(Map<String, dynamic>.from(j as Map));
        stock[e.insumoId] = e;
      }
    }
    if (data['stockInicialProductos'] != null) {
      final m = data['stockInicialProductos'] as Map<String, dynamic>;
      stockInicialProductos = m.map((k, v) => MapEntry(k, (v as num).toInt()));
    }
    await _saveStockToDb();
    for (final v in ventas) {
      await _deleteVentaFromDb(v.id);
    }
    if (data['ventas'] != null) {
      ventas = (data['ventas'] as List)
          .map((j) => Venta.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
      ventas.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      for (final v in ventas) {
        await _saveVentaToDb(v);
      }
    } else {
      ventas = [];
    }
    notifyListeners();
  }

  // ── Stock mínimo ──────────────────────────────────────────────────────────

  void setStockMinimoInsumo(String insumoId, int minimo) {
    stockMinimoInsumos[insumoId] = minimo;
    _saveStockToDb();
    notifyListeners();
  }

  // ── Insumos CRUD ───────────────────────────────────────────────────────────

  void agregarInsumo(String nombre) {
    final id = '${nombre.toLowerCase().replaceAll(RegExp(r'\W+'), '_')}_${DateTime.now().millisecondsSinceEpoch}';
    insumos.add(InsumoModel(id: id, nombre: nombre));
    stock.putIfAbsent(id, () => StockEntry(insumoId: id, inicial: 0));
    _sortInsumos();
    _saveInsumosToDb();
    _saveStockToDb();
    notifyListeners();
  }

  void editarInsumo(String id, String nuevoNombre) {
    final idx = insumos.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    insumos[idx].nombre = nuevoNombre;
    _sortInsumos();
    _saveInsumosToDb();
    notifyListeners();
  }

  void eliminarInsumo(String id) {
    insumos.removeWhere((i) => i.id == id);
    stock.remove(id);
    stockMinimoInsumos.remove(id);
    _saveInsumosToDb();
    _saveStockToDb();
    notifyListeners();
  }

  void setStockMinimoProducto(String id, int minimo) {
    stockMinimoProductos[id] = minimo;
    _saveStockToDb();
    notifyListeners();
  }

  // ── Proveedores CRUD ───────────────────────────────────────────────────────

  void agregarProveedor({required String nombre, String telefono = '', String notas = ''}) {
    final p = Proveedor(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      nombre: nombre,
      telefono: telefono,
      notas: notas,
    );
    proveedores.add(p);
    proveedores.sort((a, b) => a.nombre.compareTo(b.nombre));
    _saveProveedorToDb(p);
    notifyListeners();
  }

  void editarProveedor(String id, {String? nombre, String? telefono, String? notas}) {
    final idx = proveedores.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final p = proveedores[idx];
    if (nombre != null) p.nombre = nombre;
    if (telefono != null) p.telefono = telefono;
    if (notas != null) p.notas = notas;
    proveedores.sort((a, b) => a.nombre.compareTo(b.nombre));
    _saveProveedorToDb(p);
    notifyListeners();
  }

  void eliminarProveedor(String id) {
    proveedores.removeWhere((p) => p.id == id);
    _deleteProveedorFromDb(id);
    notifyListeners();
  }

  // ── Pedidos CRUD ───────────────────────────────────────────────────────────

  void agregarPedido({
    required String proveedorId,
    required String proveedorNombre,
    required DateTime fecha,
    required List<ItemPedido> items,
    String notas = '',
  }) {
    final p = PedidoProveedor(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      proveedorId: proveedorId,
      proveedorNombre: proveedorNombre,
      fecha: fecha,
      items: items,
      notas: notas,
    );
    pedidos.insert(0, p);
    _savePedidoToDb(p);
    notifyListeners();
  }

  Future<void> marcarPedidoRecibido(String id) async {
    final idx = pedidos.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final pedido = pedidos[idx];
    if (pedido.estado == EstadoPedido.recibido) return;

    for (final item in pedido.items) {
      if (item.tipo == TipoItemPedido.insumo) {
        stock.putIfAbsent(item.referenciaId, () => StockEntry(insumoId: item.referenciaId, inicial: 0));
        stock[item.referenciaId]!.inicial += item.cantidad;
        preciosCompra['i_${item.referenciaId}'] = item.precioUnitario;
      } else {
        stockInicialProductos[item.referenciaId] =
            (stockInicialProductos[item.referenciaId] ?? 0) + item.cantidad;
        preciosCompra['p_${item.referenciaId}'] = item.precioUnitario;
      }
    }

    pedido.estado = EstadoPedido.recibido;
    pedido.fechaRecepcion = DateTime.now();
    await _savePedidoToDb(pedido);
    await _saveStockToDb();
    await _savePreciosCompraToDb();
    notifyListeners();
  }

  Future<void> revertirPedido(String id) async {
    final idx = pedidos.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final pedido = pedidos[idx];
    if (pedido.estado != EstadoPedido.recibido) return;

    for (final item in pedido.items) {
      if (item.tipo == TipoItemPedido.insumo) {
        final e = stock[item.referenciaId];
        if (e != null) e.inicial = (e.inicial - item.cantidad).clamp(0, 99999);
      } else {
        final actual = stockInicialProductos[item.referenciaId] ?? 0;
        stockInicialProductos[item.referenciaId] =
            (actual - item.cantidad).clamp(0, 99999);
      }
    }

    pedido.estado = EstadoPedido.pendiente;
    pedido.fechaRecepcion = null;
    await _savePedidoToDb(pedido);
    await _saveStockToDb();
    notifyListeners();
  }

  void eliminarPedido(String id) {
    pedidos.removeWhere((p) => p.id == id);
    _deletePedidoFromDb(id);
    notifyListeners();
  }

  // ── Stock helpers ──────────────────────────────────────────────────────────

  void _descontarStock(List<ItemCarrito> items) {
    for (final item in items) {
      final comboIdx = combos.indexWhere((c) => c.id == item.comboId);
      if (comboIdx != -1) {
        final combo = combos[comboIdx];
        combo.insumos.forEach((insumoId, qty) {
          stock[insumoId]?.vendidos += qty * item.cantidad;
        });
        combo.productosConsumidos.forEach((prodId, qty) {
          _stockVendidosProductosExtra[prodId] =
              (_stockVendidosProductosExtra[prodId] ?? 0) + qty * item.cantidad;
        });
        continue;
      }
      final pIdx = productos.indexWhere((p) => p.id == item.comboId);
      if (pIdx != -1) {
        final p = productos[pIdx];
        if (p.categoria == CategoriaProducto.cafeteria && p.tamanoBebida != null) {
          stock[p.tamanoBebida!.vasoInsumoId]?.vendidos += item.cantidad;
          stock[p.tamanoBebida!.tapaInsumoId]?.vendidos += item.cantidad;
        }
        p.insumosConsumidos.forEach((insumoId, qty) {
          stock[insumoId]?.vendidos += qty * item.cantidad;
        });
        p.productosConsumidos.forEach((prodId, qty) {
          _stockVendidosProductosExtra[prodId] =
              (_stockVendidosProductosExtra[prodId] ?? 0) + qty * item.cantidad;
        });
      }
    }
  }

  void _revertirStock(List<ItemCarrito> items) {
    for (final item in items) {
      final comboIdx = combos.indexWhere((c) => c.id == item.comboId);
      if (comboIdx != -1) {
        final combo = combos[comboIdx];
        combo.insumos.forEach((insumoId, qty) {
          final e = stock[insumoId];
          if (e != null) e.vendidos -= qty * item.cantidad;
        });
        combo.productosConsumidos.forEach((prodId, qty) {
          _stockVendidosProductosExtra[prodId] =
              (_stockVendidosProductosExtra[prodId] ?? 0) - qty * item.cantidad;
        });
        continue;
      }
      final pIdx = productos.indexWhere((p) => p.id == item.comboId);
      if (pIdx != -1) {
        final p = productos[pIdx];
        if (p.categoria == CategoriaProducto.cafeteria && p.tamanoBebida != null) {
          final ev = stock[p.tamanoBebida!.vasoInsumoId];
          final et = stock[p.tamanoBebida!.tapaInsumoId];
          if (ev != null) ev.vendidos -= item.cantidad;
          if (et != null) et.vendidos -= item.cantidad;
        }
        p.insumosConsumidos.forEach((insumoId, qty) {
          final e = stock[insumoId];
          if (e != null) e.vendidos -= qty * item.cantidad;
        });
        p.productosConsumidos.forEach((prodId, qty) {
          _stockVendidosProductosExtra[prodId] =
              (_stockVendidosProductosExtra[prodId] ?? 0) - qty * item.cantidad;
        });
      }
    }
  }
}
