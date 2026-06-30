
// ─── Insumos ──────────────────────────────────────────────────────────────────

class InsumoModel {
  final String id;
  String nombre;

  InsumoModel({required this.id, required this.nombre});

  Map<String, dynamic> toJson() => {'id': id, 'nombre': nombre};

  factory InsumoModel.fromJson(Map<String, dynamic> j) =>
      InsumoModel(id: j['id'], nombre: j['nombre']);
}

// IDs semilla (usados también por TamanoBebida para descontar stock automáticamente)
const kVasoStdId = 'vaso';
const kTapaStdId = 'tapa';
const kVaso12Id  = 'vaso12';
const kTapa12Id  = 'tapa12';

/// Insumos por defecto que se cargan en la primera ejecución.
List<InsumoModel> kDefaultInsumos() => [
      InsumoModel(id: kVasoStdId,  nombre: 'Vaso 8oz'),
      InsumoModel(id: kTapaStdId,  nombre: 'Tapa 8oz'),
      InsumoModel(id: 'triangulos', nombre: 'Triángulos de Miga'),
      InsumoModel(id: kVaso12Id,   nombre: 'Vaso 12oz'),
      InsumoModel(id: kTapa12Id,   nombre: 'Tapa 12oz'),
      InsumoModel(id: 'croissant', nombre: 'Croissant'),
    ];

/// Mapeo de índice legacy (enum Insumo) → ID de cadena para migración.
const kLegacyInsumoIds = [
  kVasoStdId, kTapaStdId, 'triangulos', kVaso12Id, kTapa12Id, 'croissant'
];

// ─── Combo ────────────────────────────────────────────────────────────────────

class Combo {
  final String id;
  String nombre;
  int precioFijo;
  Map<String, int> insumos; // insumoId → qty
  Map<String, int> productosConsumidos; // productoId → qty

  Combo({
    required this.id,
    required this.nombre,
    required this.precioFijo,
    Map<String, int>? insumos,
    Map<String, int>? productosConsumidos,
  })  : insumos = insumos ?? {},
        productosConsumidos = productosConsumidos ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'precioFijo': precioFijo,
        'insumos': insumos,
        'productosConsumidos': productosConsumidos,
      };

  factory Combo.fromJson(Map<String, dynamic> j) {
    final insumos = <String, int>{};
    if (j['insumos'] != null) {
      (j['insumos'] as Map<String, dynamic>).forEach((k, v) {
        // Formato nuevo: clave ya es un id string; formato legacy: clave era índice int
        final id = int.tryParse(k) != null
            ? (int.parse(k) < kLegacyInsumoIds.length
                ? kLegacyInsumoIds[int.parse(k)]
                : k)
            : k;
        insumos[id] = v as int;
      });
    }
    final productos = <String, int>{};
    if (j['productosConsumidos'] != null) {
      (j['productosConsumidos'] as Map<String, dynamic>).forEach((k, v) => productos[k] = v as int);
    }
    return Combo(
      id: j['id'],
      nombre: j['nombre'],
      precioFijo: j['precioFijo'],
      insumos: insumos,
      productosConsumidos: productos,
    );
  }
}

/// Combos iniciales (sin insumos asignados — el usuario los configura)
List<Combo> kDefaultCombos() => [
      Combo(id: 'medialunas', nombre: 'Café + 2 Medialunas', precioFijo: 3600),
      Combo(id: 'tostado', nombre: 'Café + Tostado', precioFijo: 4000),
      Combo(id: 'brownie', nombre: 'Café + Brownie', precioFijo: 4300),
      Combo(id: 'lemonie', nombre: 'Café + Lemonie', precioFijo: 4300),
      Combo(id: 'cookie_rv', nombre: 'Café + Cookie Red Velvet', precioFijo: 4300),
      Combo(id: 'cookie_choco', nombre: 'Café + Cookie Choco', precioFijo: 4300),
    ];

// ─── Ítem de carrito ──────────────────────────────────────────────────────────

class ItemCarrito {
  final String comboId;
  final String comboNombre;
  final int cafesAdicionales;
  final int precioUnitario; // precio por unidad (combo + adicionales)
  final int cantidad; // unidades (siempre 1 para combos; ≥1 para productos)

  ItemCarrito({
    required this.comboId,
    required this.comboNombre,
    required this.cafesAdicionales,
    required this.precioUnitario,
    this.cantidad = 1,
  });

  int get precioTotal => precioUnitario * cantidad;

  Map<String, dynamic> toJson() => {
        'comboId': comboId,
        'comboNombre': comboNombre,
        'cafesAdicionales': cafesAdicionales,
        'precioUnitario': precioUnitario,
        'cantidad': cantidad,
      };

  factory ItemCarrito.fromJson(Map<String, dynamic> j) => ItemCarrito(
        comboId: j['comboId'],
        comboNombre: j['comboNombre'],
        cafesAdicionales: j['cafesAdicionales'],
        precioUnitario: j['precioUnitario'],
        cantidad: j['cantidad'] ?? 1,
      );
}

// ─── Medio de pago ────────────────────────────────────────────────────────────

enum MedioPago { efectivo, transferencia, posnet }

extension MedioPagoLabel on MedioPago {
  String get label {
    switch (this) {
      case MedioPago.efectivo:
        return 'Efectivo';
      case MedioPago.transferencia:
        return 'Transferencia';
      case MedioPago.posnet:
        return 'Posnet';
    }
  }

  String get emoji {
    switch (this) {
      case MedioPago.efectivo:
        return '💵';
      case MedioPago.transferencia:
        return '📲';
      case MedioPago.posnet:
        return '💳';
    }
  }
}

// ─── Venta ────────────────────────────────────────────────────────────────────

class Venta {
  final String id;
  final List<ItemCarrito> items; // uno o más ítems
  final int precioTotal;
  final MedioPago medioPago;
  final DateTime timestamp;
  final int propina;
  final MedioPago? propinaMedioPago; // null si propina == 0

  Venta({
    required this.id,
    required this.items,
    required this.precioTotal,
    required this.medioPago,
    required this.timestamp,
    this.propina = 0,
    this.propinaMedioPago,
  });

  // Helpers para retrocompatibilidad en historial/resumen
  String get resumenCorto {
    if (items.length == 1) {
      final it = items.first;
      var label = it.comboNombre;
      if (it.cafesAdicionales > 0) label += ' +${it.cafesAdicionales} café${it.cafesAdicionales > 1 ? 's' : ''}';
      if (it.cantidad > 1) label += ' ×${it.cantidad}';
      return label;
    }
    return '${items.length} ítems';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'items': items.map((i) => i.toJson()).toList(),
        'precioTotal': precioTotal,
        'medioPago': medioPago.index,
        'timestamp': timestamp.toIso8601String(),
        if (propina > 0) 'propina': propina,
        if (propinaMedioPago != null) 'propinaMedioPago': propinaMedioPago!.index,
      };

  factory Venta.fromJson(Map<String, dynamic> j) {
    // Migración de ventas antiguas (formato de un solo combo)
    if (j.containsKey('comboId')) {
      return Venta(
        id: j['id'],
        items: [
          ItemCarrito(
            comboId: j['comboId'],
            comboNombre: j['comboNombre'],
            cafesAdicionales: j['cafesAdicionales'] ?? 0,
            precioUnitario: j['precioTotal'],
          )
        ],
        precioTotal: j['precioTotal'],
        medioPago: MedioPago.values[j['medioPago']],
        timestamp: DateTime.parse(j['timestamp']),
      );
    }
    return Venta(
      id: j['id'],
      items: (j['items'] as List).map((i) => ItemCarrito.fromJson(i)).toList(),
      precioTotal: j['precioTotal'],
      medioPago: MedioPago.values[j['medioPago']],
      timestamp: DateTime.parse(j['timestamp']),
      propina: j['propina'] ?? 0,
      propinaMedioPago: j['propinaMedioPago'] != null ? MedioPago.values[j['propinaMedioPago']] : null,
    );
  }
}

// ─── Categoría de producto ────────────────────────────────────────────────────

enum CategoriaProducto { cafeteria, deliciasDulces, salados, combos }

extension CategoriaProductoLabel on CategoriaProducto {
  String get label {
    switch (this) {
      case CategoriaProducto.cafeteria:
        return 'Cafetería';
      case CategoriaProducto.deliciasDulces:
        return 'Delicias Dulces';
      case CategoriaProducto.salados:
        return 'Salados';
      case CategoriaProducto.combos:
        return 'Combos';
    }
  }
}

// ─── Tamaño de bebida ─────────────────────────────────────────────────────────

enum TamanoBebida { oz8, oz12 }

extension TamanoBebidaLabel on TamanoBebida {
  String get label {
    switch (this) {
      case TamanoBebida.oz8:
        return '8 oz';
      case TamanoBebida.oz12:
        return '12 oz';
    }
  }

  /// Insumos correspondientes al tamaño
  String get vasoInsumoId => this == TamanoBebida.oz12 ? kVaso12Id : kVasoStdId;
  String get tapaInsumoId => this == TamanoBebida.oz12 ? kTapa12Id : kTapaStdId;
}

// ─── Producto (ítem libre del menú) ───────────────────────────────────────────

class Producto {
  final String id;
  String nombre;
  int precio;
  CategoriaProducto categoria;
  TamanoBebida? tamanoBebida; // solo relevante para Cafetería
  Map<String, int> insumosConsumidos; // insumoId → qty
  Map<String, int> productosConsumidos; // productoId → qty
  bool activo;

  Producto({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.categoria,
    this.tamanoBebida,
    Map<String, int>? insumosConsumidos,
    Map<String, int>? productosConsumidos,
    this.activo = true,
  })  : insumosConsumidos = insumosConsumidos ?? {},
        productosConsumidos = productosConsumidos ?? {};

  String get displayNombre => tamanoBebida != null ? '$nombre · ${tamanoBebida!.label}' : nombre;

  bool get consumeItems => insumosConsumidos.isNotEmpty || productosConsumidos.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'precio': precio,
        'categoria': categoria.index,
        if (tamanoBebida != null) 'tamanoBebida': tamanoBebida!.index,
        if (insumosConsumidos.isNotEmpty) 'insumosConsumidos': insumosConsumidos,
        if (productosConsumidos.isNotEmpty) 'productosConsumidos': productosConsumidos,
        'activo': activo,
      };

  factory Producto.fromJson(Map<String, dynamic> j) {
    final insumos = <String, int>{};
    if (j['insumosConsumidos'] != null) {
      (j['insumosConsumidos'] as Map<String, dynamic>).forEach((k, v) {
        // Migración: clave puede ser índice int (legacy) o id string (nuevo)
        final id = int.tryParse(k) != null
            ? (int.parse(k) < kLegacyInsumoIds.length
                ? kLegacyInsumoIds[int.parse(k)]
                : k)
            : k;
        insumos[id] = v as int;
      });
    }
    final productos = <String, int>{};
    if (j['productosConsumidos'] != null) {
      (j['productosConsumidos'] as Map<String, dynamic>).forEach((k, v) => productos[k] = v as int);
    }
    return Producto(
      id: j['id'],
      nombre: j['nombre'],
      precio: j['precio'],
      categoria: CategoriaProducto.values[j['categoria'] ?? 0],
      tamanoBebida: j['tamanoBebida'] != null ? TamanoBebida.values[j['tamanoBebida']] : null,
      insumosConsumidos: insumos,
      productosConsumidos: productos,
      activo: j['activo'] as bool? ?? true,
    );
  }
}

// ─── Proveedor ────────────────────────────────────────────────────────────────

class Proveedor {
  final String id;
  String nombre;
  String telefono;
  String notas;

  Proveedor({required this.id, required this.nombre, this.telefono = '', this.notas = ''});

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'telefono': telefono,
        'notas': notas,
      };

  factory Proveedor.fromJson(Map<String, dynamic> j) => Proveedor(
        id: j['id'],
        nombre: j['nombre'],
        telefono: j['telefono'] ?? '',
        notas: j['notas'] ?? '',
      );
}

// ─── Pedido a proveedor ───────────────────────────────────────────────────────

enum TipoItemPedido { insumo, producto }

class ItemPedido {
  final TipoItemPedido tipo;
  final String referenciaId; // Insumo.index.toString() o Producto.id
  final String nombre;
  int cantidad;
  int precioUnitario;

  ItemPedido({
    required this.tipo,
    required this.referenciaId,
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
  });

  int get subtotal => cantidad * precioUnitario;

  Map<String, dynamic> toJson() => {
        'tipo': tipo.index,
        'referenciaId': referenciaId,
        'nombre': nombre,
        'cantidad': cantidad,
        'precioUnitario': precioUnitario,
      };

  factory ItemPedido.fromJson(Map<String, dynamic> j) => ItemPedido(
        tipo: TipoItemPedido.values[j['tipo']],
        referenciaId: j['referenciaId'],
        nombre: j['nombre'],
        cantidad: j['cantidad'],
        precioUnitario: j['precioUnitario'],
      );
}

enum EstadoPedido { pendiente, recibido }

class PedidoProveedor {
  final String id;
  final String proveedorId;
  String proveedorNombre;
  DateTime fecha;
  List<ItemPedido> items;
  EstadoPedido estado;
  String notas;
  DateTime? fechaRecepcion;

  PedidoProveedor({
    required this.id,
    required this.proveedorId,
    required this.proveedorNombre,
    required this.fecha,
    required this.items,
    this.estado = EstadoPedido.pendiente,
    this.notas = '',
    this.fechaRecepcion,
  });

  int get costoTotal => items.fold(0, (s, i) => s + i.subtotal);

  Map<String, dynamic> toJson() => {
        'id': id,
        'proveedorId': proveedorId,
        'proveedorNombre': proveedorNombre,
        'fecha': fecha.toIso8601String(),
        'items': items.map((i) => i.toJson()).toList(),
        'estado': estado.index,
        'notas': notas,
        if (fechaRecepcion != null) 'fechaRecepcion': fechaRecepcion!.toIso8601String(),
      };

  factory PedidoProveedor.fromJson(Map<String, dynamic> j) => PedidoProveedor(
        id: j['id'],
        proveedorId: j['proveedorId'],
        proveedorNombre: j['proveedorNombre'],
        fecha: DateTime.parse(j['fecha']),
        items: (j['items'] as List).map((i) => ItemPedido.fromJson(Map<String, dynamic>.from(i))).toList(),
        estado: EstadoPedido.values[j['estado'] ?? 0],
        notas: j['notas'] ?? '',
        fechaRecepcion: j['fechaRecepcion'] != null ? DateTime.parse(j['fechaRecepcion']) : null,
      );
}

// ─── Stock entry ──────────────────────────────────────────────────────────────

class StockEntry {
  final String insumoId;
  int inicial;
  int vendidos;
  int ajuste; // suma de StockAjuste.cantidad, no persiste en Firestore

  StockEntry({required this.insumoId, required this.inicial, this.vendidos = 0, this.ajuste = 0});

  int get actual => inicial + ajuste - vendidos;

  Map<String, dynamic> toJson() => {
        'insumoId': insumoId,
        'inicial': inicial,
        'vendidos': vendidos,
      };

  static StockEntry fromJson(Map<String, dynamic> j) {
    // Migración: formato antiguo tenía 'insumo' como índice int
    final id = j['insumoId'] as String? ??
        (j['insumo'] != null && (j['insumo'] as int) < kLegacyInsumoIds.length
            ? kLegacyInsumoIds[j['insumo'] as int]
            : 'desconocido_${j['insumo']}');
    return StockEntry(
      insumoId: id,
      inicial: j['inicial'],
      vendidos: j['vendidos'],
    );
  }
}

// ─── Ajuste de stock ──────────────────────────────────────────────────────────

class StockAjuste {
  final String id;
  final String insumoId;
  final int cantidad; // positivo = agrega, negativo = resta
  final String descripcion;
  final DateTime timestamp;

  StockAjuste({
    required this.id,
    required this.insumoId,
    required this.cantidad,
    required this.descripcion,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'insumoId': insumoId,
        'cantidad': cantidad,
        'descripcion': descripcion,
        'timestamp': timestamp.toIso8601String(),
      };

  factory StockAjuste.fromJson(Map<String, dynamic> j) => StockAjuste(
        id: j['id'],
        insumoId: j['insumoId'],
        cantidad: (j['cantidad'] as num).toInt(),
        descripcion: j['descripcion'] ?? '',
        timestamp: DateTime.parse(j['timestamp']),
      );
}
