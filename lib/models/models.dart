import 'dart:convert';

// ─── Insumos ──────────────────────────────────────────────────────────────────

// vaso12/tapa12 van AL FINAL para no romper los índices ya persistidos (0–7)
enum Insumo {
  vaso,
  tapa,
  triangulos,
  vaso12,
  tapa12,
  croissant,
}

extension InsumoLabel on Insumo {
  String get label {
    switch (this) {
      case Insumo.vaso:
        return 'Vaso 8oz';
      case Insumo.tapa:
        return 'Tapa 8oz';
      case Insumo.triangulos:
        return 'Triángulos de Miga';
      case Insumo.vaso12:
        return 'Vaso 12oz';
      case Insumo.tapa12:
        return 'Tapa 12oz';
      case Insumo.croissant:
        return 'Croissant';
    }
  }
}

// ─── Combo ────────────────────────────────────────────────────────────────────

class Combo {
  final String id;
  String nombre;
  int precioFijo;
  Map<Insumo, int> insumos;
  Map<String, int> productosConsumidos; // productoId → qty

  Combo({
    required this.id,
    required this.nombre,
    required this.precioFijo,
    Map<Insumo, int>? insumos,
    Map<String, int>? productosConsumidos,
  })  : insumos = insumos ?? {},
        productosConsumidos = productosConsumidos ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'precioFijo': precioFijo,
        'insumos': insumos.map((k, v) => MapEntry(k.index.toString(), v)),
        'productosConsumidos': productosConsumidos,
      };

  factory Combo.fromJson(Map<String, dynamic> j) {
    final insumos = <Insumo, int>{};
    if (j['insumos'] != null) {
      (j['insumos'] as Map<String, dynamic>).forEach((k, v) {
        final idx = int.parse(k);
        if (idx < Insumo.values.length) insumos[Insumo.values[idx]] = v as int;
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
  Insumo get vasoInsumo => this == TamanoBebida.oz12 ? Insumo.vaso12 : Insumo.vaso;
  Insumo get tapaInsumo => this == TamanoBebida.oz12 ? Insumo.tapa12 : Insumo.tapa;
}

// ─── Producto (ítem libre del menú) ───────────────────────────────────────────

class Producto {
  final String id;
  String nombre;
  int precio;
  CategoriaProducto categoria;
  TamanoBebida? tamanoBebida; // solo relevante para Cafetería
  Map<Insumo, int> insumosConsumidos; // insumos que se descuentan al vender
  Map<String, int> productosConsumidos; // productoId → qty al vender

  Producto({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.categoria,
    this.tamanoBebida,
    Map<Insumo, int>? insumosConsumidos,
    Map<String, int>? productosConsumidos,
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
        if (insumosConsumidos.isNotEmpty) 'insumosConsumidos': insumosConsumidos.map((k, v) => MapEntry(k.index.toString(), v)),
        if (productosConsumidos.isNotEmpty) 'productosConsumidos': productosConsumidos,
      };

  factory Producto.fromJson(Map<String, dynamic> j) {
    final insumos = <Insumo, int>{};
    if (j['insumosConsumidos'] != null) {
      (j['insumosConsumidos'] as Map<String, dynamic>).forEach((k, v) {
        final idx = int.parse(k);
        if (idx < Insumo.values.length) insumos[Insumo.values[idx]] = v as int;
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
    );
  }
}

// ─── Stock entry ──────────────────────────────────────────────────────────────

class StockEntry {
  final Insumo insumo;
  int inicial;
  int vendidos;

  StockEntry({required this.insumo, required this.inicial, this.vendidos = 0});

  int get actual => inicial - vendidos;

  Map<String, dynamic> toJson() => {
        'insumo': insumo.index,
        'inicial': inicial,
        'vendidos': vendidos,
      };

  factory StockEntry.fromJson(Map<String, dynamic> j) => StockEntry(
        insumo: Insumo.values[j['insumo']],
        inicial: j['inicial'],
        vendidos: j['vendidos'],
      );
}
