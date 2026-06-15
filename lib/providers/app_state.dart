import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class AppState extends ChangeNotifier {
  // ── Stock de insumos
  Map<Insumo, StockEntry> stock = {
    for (var i in Insumo.values) i: StockEntry(insumo: i, inicial: 0)
  };

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

    // Productos
    final productosDoc = await _db.collection('config').doc('productos').get();
    if (productosDoc.exists) {
      final list = productosDoc.data()?['items'] as List? ?? [];
      productos = list
          .map((j) => Producto.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
    }

    // Stock
    final stockDoc = await _db.collection('config').doc('stock').get();
    if (stockDoc.exists) {
      final data = stockDoc.data()!;
      final insumos = data['insumos'] as List? ?? [];
      for (final j in insumos) {
        final e = StockEntry.fromJson(Map<String, dynamic>.from(j as Map));
        if (stock.containsKey(e.insumo)) stock[e.insumo] = e;
      }
      final inicialProds = data['inicialProductos'] as Map<String, dynamic>? ?? {};
      stockInicialProductos = inicialProds.map((k, v) => MapEntry(k, (v as num).toInt()));
      final extra = data['vendidosExtra'] as Map<String, dynamic>? ?? {};
      _stockVendidosProductosExtra = extra.map((k, v) => MapEntry(k, (v as num).toInt()));
    }

    // Ventas
    final ventasSnap = await _db.collection('ventas').get();
    ventas = ventasSnap.docs
        .map((d) => Venta.fromJson(Map<String, dynamic>.from(d.data())))
        .toList();
    ventas.sort((a, b) => a.timestamp.compareTo(b.timestamp));
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

    final stockStr = prefs.getString(_kStock);
    if (stockStr != null) {
      final list = jsonDecode(stockStr) as List;
      for (final j in list) {
        final e = StockEntry.fromJson(j);
        if (stock.containsKey(e.insumo)) stock[e.insumo] = e;
      }
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

  Future<void> _saveStockToDb() => _db.collection('config').doc('stock').set({
        'insumos': stock.values.map((e) => e.toJson()).toList(),
        'inicialProductos': stockInicialProductos,
        'vendidosExtra': _stockVendidosProductosExtra,
      });

  Future<void> _saveVentaToDb(Venta v) =>
      _db.collection('ventas').doc(v.id).set(v.toJson());

  Future<void> _deleteVentaFromDb(String id) =>
      _db.collection('ventas').doc(id).delete();

  // ── Combos CRUD ────────────────────────────────────────────────────────────

  void agregarCombo({required String nombre, required int precio,
      Map<Insumo, int>? insumos, Map<String, int>? productosConsumidos}) {
    combos.add(Combo(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      nombre: nombre,
      precioFijo: precio,
      insumos: insumos,
      productosConsumidos: productosConsumidos,
    ));
    _saveCombosToDb();
    notifyListeners();
  }

  void editarCombo(String id,
      {String? nombre,
      int? precio,
      Map<Insumo, int>? insumos,
      Map<String, int>? productosConsumidos}) {
    final c = combos.firstWhere((c) => c.id == id);
    if (nombre != null) c.nombre = nombre;
    if (precio != null) c.precioFijo = precio;
    if (insumos != null) c.insumos = insumos;
    if (productosConsumidos != null) c.productosConsumidos = productosConsumidos;
    _saveCombosToDb();
    notifyListeners();
  }

  void eliminarCombo(String id) {
    combos.removeWhere((c) => c.id == id);
    _saveCombosToDb();
    notifyListeners();
  }

  // ── Stock ──────────────────────────────────────────────────────────────────

  void setStockInicial(Insumo insumo, int cantidad) {
    stock[insumo]!.inicial = cantidad;
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
      Map<Insumo, int>? insumosConsumidos,
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
    _saveProductosToDb();
    notifyListeners();
  }

  void editarProducto(String id,
      {String? nombre,
      int? precio,
      CategoriaProducto? categoria,
      TamanoBebida? tamanoBebida,
      bool updateTamano = false,
      Map<Insumo, int>? insumosConsumidos,
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
        if (stock.containsKey(e.insumo)) stock[e.insumo] = e;
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

  // ── Stock helpers ──────────────────────────────────────────────────────────

  void _descontarStock(List<ItemCarrito> items) {
    for (final item in items) {
      final comboIdx = combos.indexWhere((c) => c.id == item.comboId);
      if (comboIdx != -1) {
        final combo = combos[comboIdx];
        combo.insumos.forEach((insumo, qty) {
          stock[insumo]!.vendidos += qty * item.cantidad;
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
          stock[p.tamanoBebida!.vasoInsumo]!.vendidos += item.cantidad;
          stock[p.tamanoBebida!.tapaInsumo]!.vendidos += item.cantidad;
        }
        p.insumosConsumidos.forEach((insumo, qty) {
          stock[insumo]!.vendidos += qty * item.cantidad;
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
        combo.insumos.forEach((insumo, qty) {
          stock[insumo]!.vendidos -= qty * item.cantidad;
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
          stock[p.tamanoBebida!.vasoInsumo]!.vendidos -= item.cantidad;
          stock[p.tamanoBebida!.tapaInsumo]!.vendidos -= item.cantidad;
        }
        p.insumosConsumidos.forEach((insumo, qty) {
          stock[insumo]!.vendidos -= qty * item.cantidad;
        });
        p.productosConsumidos.forEach((prodId, qty) {
          _stockVendidosProductosExtra[prodId] =
              (_stockVendidosProductosExtra[prodId] ?? 0) - qty * item.cantidad;
        });
      }
    }
  }
}
