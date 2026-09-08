import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';

class ConfigScreen extends StatelessWidget {
  const ConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Categorías ─────────────────────────────────────────────────────
          const SectionHeader('Categorías'),
          const SizedBox(height: 4),
          const Text(
            'Las categorías aparecen en Ventas. Podés reordenarlas arrastrando.',
            style: TextStyle(fontSize: 12, color: AppTheme.grey600),
          ),
          const SizedBox(height: 8),
          _CategoriasManager(state: state),
          const SizedBox(height: 32),

          // ── Insumos ────────────────────────────────────────────────────────
          const SectionHeader('Insumos'),
          const SizedBox(height: 8),
          _InsumosList(state: state),
          const SizedBox(height: 32),

          // ── Productos del menú ──────────────────────────────────────────────
          const SectionHeader('Productos del menú'),
          _ProductosList(state: state),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _showProductoDialog(context, state),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nuevo producto'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.brownMed,
              side: const BorderSide(color: AppTheme.brownMed),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),

          const SizedBox(height: 32),

          // ── Combos ──────────────────────────────────────────────────────────
          const SectionHeader('Combos'),
          _CombosList(state: state),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _showComboDialog(context, state),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nuevo combo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.brownMed,
              side: const BorderSide(color: AppTheme.brownMed),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),

          const SizedBox(height: 40),

          // ── Extras del pedido ───────────────────────────────────────────────
          const SectionHeader('Extras del pedido'),
          const SizedBox(height: 4),
          const Text(
            'Aparecen en el resumen de cada venta para que el barista indique cantidades.',
            style: TextStyle(fontSize: 12, color: AppTheme.grey600),
          ),
          const SizedBox(height: 8),
          _ExtrasPedidoList(state: state),
          const SizedBox(height: 40),

          // ── Historial de precios ────────────────────────────────────────────
          const SectionHeader('Historial de precios'),
          const SizedBox(height: 4),
          const Text(
            'Registro de todos los cambios de precio de productos y combos.',
            style: TextStyle(fontSize: 12, color: AppTheme.grey600),
          ),
          const SizedBox(height: 8),
          _HistorialPreciosList(state: state),
          const SizedBox(height: 40),

          // ── Backup de datos ─────────────────────────────────────────────────
          const SectionHeader('Datos'),
          const SizedBox(height: 8),
          _BackupTile(state: state),
        ],
      ),
    );
  }

  void _showProductoDialog(BuildContext context, AppState state,
      [Producto? producto]) {
    showDialog(
      context: context,
      builder: (_) => _ProductoDialog(state: state, producto: producto),
    );
  }

  void _showComboDialog(BuildContext context, AppState state, [Combo? combo]) {
    showDialog(
      context: context,
      builder: (_) => _ComboDialog(state: state, combo: combo),
    );
  }
}

// ── Lista de productos agrupada por categoría ─────────────────────────────────

class _ProductosList extends StatelessWidget {
  final AppState state;
  const _ProductosList({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.productos.isEmpty) {
      return Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.grey100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.grey300),
        ),
        child: const Text(
          'No hay productos. Agregá uno para que aparezca en Ventas.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppTheme.grey600),
        ),
      );
    }

    // Agrupar por categoriaId, respetando el orden de state.categorias
    final grupos = <String, List<Producto>>{};
    for (final p in state.productos) {
      grupos.putIfAbsent(p.categoriaId, () => []).add(p);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: state.categorias
          .where((c) => grupos.containsKey(c.id))
          .map((c) => _buildGrupo(context, c, grupos[c.id]!))
          .toList(),
    );
  }

  Widget _buildGrupo(BuildContext context, CategoriaModel cat,
      List<Producto> items) {
    final fmt = NumberFormat.currency(
        locale: 'es_AR', symbol: '\$', decimalDigits: 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(
            cat.nombre,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.caramel,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.grey300),
          ),
          child: Column(
            children: items.asMap().entries.map((e) {
              final i = e.key;
              final p = e.value;
              final isLast = i == items.length - 1;
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: p.activo ? null : AppTheme.grey100,
                  border: isLast
                      ? null
                      : const Border(
                          bottom:
                              BorderSide(color: AppTheme.grey300)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(p.nombre,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.brownDark)),
                              ),
                              if (p.tamanoBebida != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cream,
                                    borderRadius:
                                        BorderRadius.circular(4),
                                    border: Border.all(
                                        color: AppTheme.caramel),
                                  ),
                                  child: Text(p.tamanoBebida!.label,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: AppTheme.caramel,
                                          fontWeight:
                                              FontWeight.w600)),
                                ),
                              ],
                            ],
                          ),
                          Row(
                            children: [
                              Text(fmt.format(p.precio),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.grey600)),
                              _MargenChip(producto: p, state: state),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Transform.scale(
                        scale: 0.7,
                        child: Switch(
                          value: p.activo,
                          onChanged: (_) => state.toggleProductoActivo(p.id),
                          activeColor: AppTheme.brownMed,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          _showProductoDialog(context, p),
                      child: const Icon(Icons.edit_outlined,
                          size: 18, color: AppTheme.grey600),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () =>
                          _confirmarEliminar(context, p),
                      child: const Icon(Icons.delete_outline,
                          size: 18, color: AppTheme.red),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _showProductoDialog(BuildContext context, Producto p) {
    final state = Provider.of<AppState>(context, listen: false);
    showDialog(
      context: context,
      builder: (_) => _ProductoDialog(state: state, producto: p),
    );
  }

  void _confirmarEliminar(BuildContext context, Producto p) {
    final state = Provider.of<AppState>(context, listen: false);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminás "${p.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              state.eliminarProducto(p.id);
              Navigator.pop(context);
            },
            child: const Text('Eliminar',
                style: TextStyle(color: AppTheme.red)),
          ),
        ],
      ),
    );
  }
}

// ── Diálogo crear / editar producto ──────────────────────────────────────────

class _ProductoDialog extends StatefulWidget {
  final AppState state;
  final Producto? producto;

  const _ProductoDialog({required this.state, this.producto});

  @override
  State<_ProductoDialog> createState() => _ProductoDialogState();
}

class _ProductoDialogState extends State<_ProductoDialog> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _precioCtrl;
  late String _categoriaId;
  TamanoBebida? _tamano;
  late List<MapEntry<String, int>> _insumos; // insumoId → qty
  late List<MapEntry<String, int>> _productosC;
  late List<String> _opciones;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.producto?.nombre ?? '');
    _precioCtrl = TextEditingController(
        text: widget.producto?.precio.toString() ?? '');
    final defaultCat = widget.state.categorias.isNotEmpty
        ? widget.state.categorias.first.id
        : 'cafeteria';
    _categoriaId = widget.producto?.categoriaId ?? defaultCat;
    _tamano = widget.producto?.tamanoBebida ??
        (_categoriaId == 'cafeteria' ? TamanoBebida.oz8 : null);
    _insumos = (widget.producto?.insumosConsumidos ?? {})
        .entries.map((e) => MapEntry(e.key, e.value)).toList();
    _productosC = (widget.producto?.productosConsumidos ?? {})
        .entries.map((e) => MapEntry(e.key, e.value)).toList();
    _opciones = List<String>.from(widget.producto?.opciones ?? []);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  bool get _esCafeteria => _categoriaId == 'cafeteria';

  bool get _valido =>
      _nombreCtrl.text.trim().isNotEmpty &&
      int.tryParse(_precioCtrl.text) != null &&
      (!_esCafeteria || _tamano != null);

  void _guardar() {
    final nombre = _nombreCtrl.text.trim();
    final precio = int.tryParse(_precioCtrl.text) ?? 0;
    if (!_valido) return;
    final insumos = Map.fromEntries(_insumos);
    final productosC = Map.fromEntries(_productosC);
    if (widget.producto == null) {
      widget.state.agregarProducto(nombre, precio, _categoriaId,
          tamanoBebida: _tamano,
          insumosConsumidos: insumos,
          productosConsumidos: productosC,
          opciones: _opciones);
    } else {
      widget.state.editarProducto(widget.producto!.id,
          nombre: nombre,
          precio: precio,
          categoriaId: _categoriaId,
          tamanoBebida: _tamano,
          updateTamano: true,
          insumosConsumidos: insumos,
          productosConsumidos: productosC,
          updateConsumos: true,
          opciones: _opciones);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final esNuevo = widget.producto == null;
    final productosDisponibles = widget.state.productos
        .where((p) =>
            p.id != widget.producto?.id &&
            p.categoriaId != 'cafeteria' &&
            !p.consumeItems)
        .toList();

    return AlertDialog(
      title: Text(esNuevo ? 'Nuevo producto' : 'Editar producto'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nombreCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre'),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _precioCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                  labelText: 'Precio', prefixText: '\$ '),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _guardar(),
            ),
            const SizedBox(height: 16),
            // Selector de categoría dinámico
            DropdownButtonFormField<String>(
              value: _categoriaId,
              decoration: InputDecoration(
                labelText: 'Categoría',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppTheme.grey300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppTheme.grey300)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: AppTheme.brownMed, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                filled: true,
                fillColor: AppTheme.white,
              ),
              items: widget.state.categorias
                  .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.nombre,
                            style: const TextStyle(fontSize: 14)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() {
                _categoriaId = v!;
                if (_categoriaId == 'cafeteria') {
                  _tamano ??= TamanoBebida.oz8;
                } else {
                  _tamano = null;
                }
              }),
            ),
            // Selector de tamaño — solo para Cafetería
            if (_esCafeteria) ...[
              const SizedBox(height: 16),
              const Text('Tamaño',
                  style: TextStyle(
                      fontSize: 13, color: AppTheme.grey600)),
              const SizedBox(height: 8),
              Row(
                children: TamanoBebida.values.map((t) {
                  final sel = _tamano == t;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: t == TamanoBebida.oz8 ? 8 : 0),
                      child: GestureDetector(
                        onTap: () => setState(() => _tamano = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppTheme.cream
                                : AppTheme.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: sel
                                  ? AppTheme.caramel
                                  : AppTheme.grey300,
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            t.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: sel
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: sel
                                  ? AppTheme.brownMed
                                  : AppTheme.grey600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Insumos adicionales — disponible para todas las categorías
            const SizedBox(height: 20),
            Text(
              _esCafeteria ? 'Insumos adicionales' : 'Insumos',
              style: const TextStyle(fontSize: 13, color: AppTheme.grey600),
            ),
            if (_esCafeteria)
              const Padding(
                padding: EdgeInsets.only(top: 2, bottom: 4),
                child: Text(
                  'Además del vaso y tapa que se descuentan automáticamente.',
                  style: TextStyle(fontSize: 11, color: AppTheme.grey600),
                ),
              ),
            const SizedBox(height: 8),
            Builder(builder: (ctx) {
              final state = Provider.of<AppState>(ctx, listen: false);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._insumos.asMap().entries.map((e) {
                    final idx = e.key;
                    return _InsumoRow(
                      insumoId: e.value.key,
                      qty: e.value.value,
                      allInsumos: state.insumos,
                      onInsumoChanged: (v) => setState(
                          () => _insumos[idx] = MapEntry(v, _insumos[idx].value)),
                      onQtyChanged: (v) => setState(
                          () => _insumos[idx] = MapEntry(_insumos[idx].key, v)),
                      onRemove: () => setState(() => _insumos.removeAt(idx)),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () {
                      if (state.insumos.isEmpty) return;
                      setState(() => _insumos.add(MapEntry(state.insumos.first.id, 1)));
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Agregar insumo'),
                  ),
                ],
              );
            }),
            // Productos consumidos — solo para no Cafetería
            if (!_esCafeteria && productosDisponibles.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Productos',
                  style: TextStyle(fontSize: 13, color: AppTheme.grey600)),
              const SizedBox(height: 8),
              ..._productosC.asMap().entries.map((e) {
                final idx = e.key;
                return _ProductoComboRow(
                  prodId: e.value.key,
                  qty: e.value.value,
                  productos: productosDisponibles,
                  onProdChanged: (v) => setState(
                      () => _productosC[idx] = MapEntry(v, _productosC[idx].value)),
                  onQtyChanged: (v) => setState(
                      () => _productosC[idx] = MapEntry(_productosC[idx].key, v)),
                  onRemove: () => setState(() => _productosC.removeAt(idx)),
                );
              }),
              TextButton.icon(
                onPressed: () => setState(() => _productosC.add(
                    MapEntry(productosDisponibles.first.id, 1))),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Agregar producto'),
              ),
            ],
          // Opciones (sabores / variantes)
          const SizedBox(height: 16),
          const Text('Opciones (sabores / variantes)',
              style: TextStyle(fontSize: 13, color: AppTheme.grey600)),
          const SizedBox(height: 4),
          const Text('Si el producto tiene opciones, se pedirá seleccionar una al agregar al pedido.',
              style: TextStyle(fontSize: 11, color: AppTheme.grey600)),
          const SizedBox(height: 8),
          ..._opciones.asMap().entries.map((e) {
            final idx = e.key;
            final ctrl = TextEditingController(text: e.value);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Ej: Caramelo',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                      onChanged: (v) => _opciones[idx] = v,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppTheme.red),
                    onPressed: () => setState(() => _opciones.removeAt(idx)),
                  ),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: () => setState(() => _opciones.add('')),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Agregar opción'),
          ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _valido ? _guardar : null,
          child: Text(
            esNuevo ? 'Agregar' : 'Guardar',
            style: TextStyle(
                color:
                    _valido ? AppTheme.brownMed : AppTheme.grey300),
          ),
        ),
      ],
    );
  }
}

// ── Lista de combos editable ──────────────────────────────────────────────────

class _CombosList extends StatelessWidget {
  final AppState state;
  const _CombosList({required this.state});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);
    if (state.combos.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.grey100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.grey300),
        ),
        child: const Text('No hay combos.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.grey600)),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey300),
      ),
      child: Column(
        children: state.combos.asMap().entries.map((e) {
          final i = e.key;
          final combo = e.value;
          final isLast = i == state.combos.length - 1;
          final resumen = _resumenInsumos(combo, state);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : const Border(bottom: BorderSide(color: AppTheme.grey300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(combo.nombre,
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.brownDark)),
                      if (resumen.isNotEmpty)
                        Text(resumen,
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.grey600)),
                    ],
                  ),
                ),
                Text(fmt.format(combo.precioFijo),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.grey600)),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _showComboDialog(context, combo),
                  child: const Icon(Icons.edit_outlined,
                      size: 18, color: AppTheme.grey600),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _confirmarEliminar(context, combo),
                  child: const Icon(Icons.delete_outline,
                      size: 18, color: AppTheme.red),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _resumenInsumos(Combo combo, AppState state) {
    final partes = <String>[];
    combo.insumos.forEach((id, qty) {
      final nombre = state.insumos.firstWhere((i) => i.id == id,
          orElse: () => InsumoModel(id: id, nombre: id)).nombre;
      partes.add('${qty}× $nombre');
    });
    combo.productosConsumidos.forEach((_, qty) => partes.add('$qty× prod.'));
    return partes.join(', ');
  }

  void _showComboDialog(BuildContext context, Combo combo) {
    final state = Provider.of<AppState>(context, listen: false);
    showDialog(
        context: context,
        builder: (_) => _ComboDialog(state: state, combo: combo));
  }

  void _confirmarEliminar(BuildContext context, Combo combo) {
    final state = Provider.of<AppState>(context, listen: false);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar combo'),
        content: Text('¿Eliminás "${combo.nombre}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              state.eliminarCombo(combo.id);
              Navigator.pop(context);
            },
            child: const Text('Eliminar',
                style: TextStyle(color: AppTheme.red)),
          ),
        ],
      ),
    );
  }
}

// ── Diálogo crear / editar combo ──────────────────────────────────────────────

class _ComboDialog extends StatefulWidget {
  final AppState state;
  final Combo? combo;
  const _ComboDialog({required this.state, this.combo});

  @override
  State<_ComboDialog> createState() => _ComboDialogState();
}

class _ComboDialogState extends State<_ComboDialog> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _precioCtrl;

  // Lista editable de insumos: (insumoId, qty)
  late List<MapEntry<String, int>> _insumos;
  // Lista editable de productos consumidos: (productoId, qty)
  late List<MapEntry<String, int>> _productosC;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.combo?.nombre ?? '');
    _precioCtrl = TextEditingController(
        text: widget.combo?.precioFijo.toString() ?? '');
    _insumos = (widget.combo?.insumos ?? {})
        .entries
        .map((e) => MapEntry(e.key, e.value))
        .toList();
    _productosC = (widget.combo?.productosConsumidos ?? {})
        .entries
        .map((e) => MapEntry(e.key, e.value))
        .toList();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  bool get _valido =>
      _nombreCtrl.text.trim().isNotEmpty &&
      int.tryParse(_precioCtrl.text) != null;

  void _guardar() {
    if (!_valido) return;
    final nombre = _nombreCtrl.text.trim();
    final precio = int.parse(_precioCtrl.text);
    final insumos = Map.fromEntries(_insumos);
    final productosC = Map.fromEntries(_productosC);

    if (widget.combo == null) {
      widget.state.agregarCombo(
          nombre: nombre,
          precio: precio,
          insumos: insumos,
          productosConsumidos: productosC);
    } else {
      widget.state.editarCombo(widget.combo!.id,
          nombre: nombre,
          precio: precio,
          insumos: insumos,
          productosConsumidos: productosC);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final esNuevo = widget.combo == null;
    final productosDisponibles = widget.state.productos
        .where((p) => !p.consumeItems && p.categoriaId != 'cafeteria')
        .toList();

    return AlertDialog(
      title: Text(esNuevo ? 'Nuevo combo' : 'Editar combo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nombreCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _precioCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                  labelText: 'Precio', prefixText: '\$ '),
              onChanged: (_) => setState(() {}),
            ),

            // ── Insumos ────────────────────────────────────────────────
            const SizedBox(height: 20),
            const Text('Insumos',
                style: TextStyle(fontSize: 13, color: AppTheme.grey600)),
            const SizedBox(height: 8),
            Builder(builder: (ctx) {
              final state = Provider.of<AppState>(ctx, listen: false);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._insumos.asMap().entries.map((e) {
                    final idx = e.key;
                    return _InsumoRow(
                      insumoId: e.value.key,
                      qty: e.value.value,
                      allInsumos: state.insumos,
                      onInsumoChanged: (v) => setState(
                          () => _insumos[idx] = MapEntry(v, _insumos[idx].value)),
                      onQtyChanged: (v) => setState(
                          () => _insumos[idx] = MapEntry(_insumos[idx].key, v)),
                      onRemove: () => setState(() => _insumos.removeAt(idx)),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () {
                      if (state.insumos.isEmpty) return;
                      setState(() => _insumos.add(MapEntry(state.insumos.first.id, 1)));
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Agregar insumo'),
                  ),
                ],
              );
            }),

            // ── Productos consumidos ───────────────────────────────────
            if (productosDisponibles.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Productos',
                  style: TextStyle(fontSize: 13, color: AppTheme.grey600)),
              const SizedBox(height: 8),
              ..._productosC.asMap().entries.map((e) {
                final idx = e.key;
                final prodId = e.value.key;
                final qty = e.value.value;
                return _ProductoComboRow(
                  prodId: prodId,
                  qty: qty,
                  productos: productosDisponibles,
                  onProdChanged: (v) => setState(
                      () => _productosC[idx] = MapEntry(v, _productosC[idx].value)),
                  onQtyChanged: (v) => setState(
                      () => _productosC[idx] = MapEntry(_productosC[idx].key, v)),
                  onRemove: () => setState(() => _productosC.removeAt(idx)),
                );
              }),
              TextButton.icon(
                onPressed: () => setState(() => _productosC.add(
                    MapEntry(productosDisponibles.first.id, 1))),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Agregar producto'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        TextButton(
          onPressed: _valido ? _guardar : null,
          child: Text(
            esNuevo ? 'Agregar' : 'Guardar',
            style: TextStyle(
                color: _valido ? AppTheme.brownMed : AppTheme.grey300),
          ),
        ),
      ],
    );
  }
}

// ── Fila de insumo dentro del diálogo de combo/producto ──────────────────────

class _InsumoRow extends StatefulWidget {
  final String insumoId;
  final int qty;
  final List<InsumoModel> allInsumos;
  final ValueChanged<String> onInsumoChanged;
  final ValueChanged<int> onQtyChanged;
  final VoidCallback onRemove;

  const _InsumoRow({
    required this.insumoId,
    required this.qty,
    required this.allInsumos,
    required this.onInsumoChanged,
    required this.onQtyChanged,
    required this.onRemove,
  });

  @override
  State<_InsumoRow> createState() => _InsumoRowState();
}

class _InsumoRowState extends State<_InsumoRow> {
  late TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: widget.qty.toString());
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentId = widget.allInsumos.any((i) => i.id == widget.insumoId)
        ? widget.insumoId
        : (widget.allInsumos.isNotEmpty ? widget.allInsumos.first.id : null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: currentId,
              isDense: true,
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.grey300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.grey300)),
              ),
              items: widget.allInsumos
                  .map((i) => DropdownMenuItem(
                      value: i.id,
                      child: Text(i.nombre, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) { if (v != null) widget.onInsumoChanged(v); },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 50,
            child: TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.grey300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.grey300)),
              ),
              onChanged: (v) => widget.onQtyChanged(int.tryParse(v) ?? 1),
            ),
          ),
          IconButton(
            onPressed: widget.onRemove,
            icon: const Icon(Icons.close, size: 18, color: AppTheme.grey600),
          ),
        ],
      ),
    );
  }
}

// ── Fila de producto dentro del diálogo de combo ──────────────────────────────

class _ProductoComboRow extends StatefulWidget {
  final String prodId;
  final int qty;
  final List<Producto> productos;
  final ValueChanged<String> onProdChanged;
  final ValueChanged<int> onQtyChanged;
  final VoidCallback onRemove;

  const _ProductoComboRow({
    required this.prodId,
    required this.qty,
    required this.productos,
    required this.onProdChanged,
    required this.onQtyChanged,
    required this.onRemove,
  });

  @override
  State<_ProductoComboRow> createState() => _ProductoComboRowState();
}

// ── Backup de datos ───────────────────────────────────────────────────────────

class _BackupTile extends StatelessWidget {
  final AppState state;
  const _BackupTile({required this.state});

  Map<String, dynamic> _buildBackup() => {
        'exportedAt': DateTime.now().toIso8601String(),
        'version': '1.0',
        'combos': state.combos.map((c) => c.toJson()).toList(),
        'productos': state.productos.map((p) => p.toJson()).toList(),
        'stock': state.stock.values.map((e) => e.toJson()).toList(),
        'stockInicialProductos': state.stockInicialProductos,
        'ventas': state.ventas.map((v) => v.toJson()).toList(),
      };

  Future<void> _exportar(BuildContext context) async {
    final json = const JsonEncoder.withIndent('  ').convert(_buildBackup());
    await Clipboard.setData(ClipboardData(text: json));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Backup copiado al portapapeles '
          '(${state.ventas.length} ventas, ${state.productos.length} productos)',
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _importar(BuildContext context) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Importar backup'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pegá el JSON del backup. Esto reemplazará combos, productos y ventas actuales.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: '{ "version": "1.0", ... }',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.brownDark),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final data = jsonDecode(ctrl.text) as Map<String, dynamic>;
      state.importarBackup(data);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup importado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al importar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionCard(
          icon: Icons.upload_outlined,
          label: 'Exportar backup',
          subtitle: 'Copia todos los datos al portapapeles como JSON',
          onTap: () => _exportar(context),
        ),
        const SizedBox(height: 8),
        _ActionCard(
          icon: Icons.download_outlined,
          label: 'Importar backup',
          subtitle: 'Restaurar desde un JSON copiado anteriormente',
          onTap: () => _importar(context),
          color: Colors.orange.shade700,
        ),
      ],
    );
  }
}

// ── Gestor de categorías ──────────────────────────────────────────────────────

class _CategoriasManager extends StatelessWidget {
  final AppState state;
  const _CategoriasManager({required this.state});

  void _showDialog(BuildContext context, [CategoriaModel? existing]) {
    final ctrl = TextEditingController(text: existing?.nombre ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Nueva categoría' : 'Renombrar categoría'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final nombre = ctrl.text.trim();
              if (nombre.isEmpty) return;
              if (existing == null) {
                state.agregarCategoria(nombre);
              } else {
                state.editarCategoria(existing.id, nombre);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminar(BuildContext context, CategoriaModel cat) {
    final tieneProductos = state.productos.any((p) => p.categoriaId == cat.id);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: tieneProductos
            ? Text(
                '¿Eliminar "${cat.nombre}"? Los productos de esta categoría quedarán sin categoría asignada.')
            : Text('¿Eliminar "${cat.nombre}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              state.eliminarCategoria(cat.id);
              Navigator.pop(ctx);
            },
            child: const Text('Eliminar', style: TextStyle(color: AppTheme.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (state.categorias.isNotEmpty)
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: state.reordenarCategorias,
            children: state.categorias.map((cat) {
              return Container(
                key: ValueKey(cat.id),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.grey300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.drag_handle, size: 20, color: AppTheme.grey600),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(cat.nombre,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                    ),
                    Text(
                      '${state.productos.where((p) => p.categoriaId == cat.id).length} prod.',
                      style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _showDialog(context, cat),
                      child: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.grey600),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _confirmarEliminar(context, cat),
                      child: const Icon(Icons.delete_outline, size: 18, color: AppTheme.red),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => _showDialog(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nueva categoría'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.brownMed,
            side: const BorderSide(color: AppTheme.brownMed),
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}

// ── Historial de cambios de precio ────────────────────────────────────────────

class _HistorialPreciosList extends StatelessWidget {
  final AppState state;
  const _HistorialPreciosList({required this.state});

  @override
  Widget build(BuildContext context) {
    final cambios = state.cambiosPrecio;
    if (cambios.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.grey100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.grey300),
        ),
        child: const Text(
          'Sin cambios registrados aún. Editá el precio de un producto o combo para que aparezca aquí.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppTheme.grey600),
        ),
      );
    }

    final fmt = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey300),
      ),
      child: Column(
        children: cambios.asMap().entries.map((e) {
          final i = e.key;
          final c = e.value;
          final isLast = i == cambios.length - 1;
          final subio = c.precioNuevo >= c.precioAnterior;
          final pct = c.porcentajeCambio;
          final pctStr = '${subio ? '+' : ''}${pct.toStringAsFixed(1)}%';

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : const Border(bottom: BorderSide(color: AppTheme.grey300)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              c.nombre,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.brownDark),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.grey100,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.grey300),
                            ),
                            child: Text(
                              c.tipo == TipoCambioPrecio.combo ? 'Combo' : 'Producto',
                              style: const TextStyle(fontSize: 10, color: AppTheme.grey600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            fmt.format(c.precioAnterior),
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.grey600,
                                decoration: TextDecoration.lineThrough),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(Icons.arrow_forward, size: 12, color: AppTheme.grey600),
                          ),
                          Text(
                            fmt.format(c.precioNuevo),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: subio ? AppTheme.brownDark : AppTheme.green),
                          ),
                        ],
                      ),
                      Text(
                        dateFmt.format(c.timestamp),
                        style: const TextStyle(fontSize: 11, color: AppTheme.grey600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: subio ? AppTheme.redLight : AppTheme.greenLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    pctStr,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: subio ? AppTheme.red : AppTheme.green,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final Color? color;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.brownMed;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.withAlpha(80)),
      ),
      child: ListTile(
        leading: Icon(icon, color: c),
        title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: c)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: Icon(Icons.chevron_right, color: c),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ProductoComboRowState extends State<_ProductoComboRow> {
  late TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: widget.qty.toString());
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Si el producto ya no existe, usar el primero de la lista
    final currentId = widget.productos.any((p) => p.id == widget.prodId)
        ? widget.prodId
        : widget.productos.first.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: currentId,
              isDense: true,
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.grey300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.grey300)),
              ),
              items: widget.productos
                  .map((p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(p.nombre,
                          style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) => widget.onProdChanged(v!),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 50,
            child: TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.grey300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.grey300)),
              ),
              onChanged: (v) =>
                  widget.onQtyChanged(int.tryParse(v) ?? 1),
            ),
          ),
          IconButton(
            onPressed: widget.onRemove,
            icon: const Icon(Icons.close, size: 18, color: AppTheme.grey600),
          ),
        ],
      ),
    );
  }
}

// ── Lista de insumos editable ─────────────────────────────────────────────────

class _InsumosList extends StatelessWidget {
  const _InsumosList({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (state.insumos.isEmpty) {
      return const Text('No hay insumos configurados.',
          style: TextStyle(color: AppTheme.grey600, fontSize: 13));
    }
    return Column(
      children: [
        ...state.insumos.map((insumo) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _InsumoListTile(insumo: insumo, state: state),
            )),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => _showInsumoDialog(context, state),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nuevo insumo'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.brownMed,
            side: const BorderSide(color: AppTheme.brownMed),
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  void _showInsumoDialog(BuildContext context, AppState state, [InsumoModel? existing]) {
    final ctrl = TextEditingController(text: existing?.nombre ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Nuevo insumo' : 'Editar insumo'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Nombre del insumo'),
          textCapitalization: TextCapitalization.sentences,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final nombre = ctrl.text.trim();
              if (nombre.isEmpty) return;
              if (existing == null) {
                state.agregarInsumo(nombre);
              } else {
                state.editarInsumo(existing.id, nombre);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _InsumoListTile extends StatelessWidget {
  const _InsumoListTile({required this.insumo, required this.state});
  final InsumoModel insumo;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final stockEntry = state.stock[insumo.id];
    final actual = stockEntry?.actual ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.grey300),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(insumo.nombre,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Text('Stock: $actual',
              style: const TextStyle(fontSize: 12, color: AppTheme.grey600)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _InsumosList(state: state)
                ._showInsumoDialog(context, state, insumo),
            child: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.grey600),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _confirmarEliminar(context),
            child: const Icon(Icons.delete_outline, size: 18, color: AppTheme.red),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminar(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar insumo'),
        content: Text(
            '¿Eliminar "${insumo.nombre}"? Se perderá su stock y no podrá usarse en combos/productos existentes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              state.eliminarInsumo(insumo.id);
              Navigator.pop(ctx);
            },
            child: const Text('Eliminar', style: TextStyle(color: AppTheme.red)),
          ),
        ],
      ),
    );
  }
}

// ── Extras del pedido ────────────────────────────────────────────────────────

class _ExtrasPedidoList extends StatelessWidget {
  const _ExtrasPedidoList({required this.state});
  final AppState state;

  void _showAgregarDialog(BuildContext context) {
    // Insumos que aún no están en extras
    final disponibles = state.insumos
        .where((i) => !state.extrasPedido.contains(i.id))
        .toList();
    if (disponibles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todos los insumos ya están agregados como extras.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    String selectedId = disponibles.first.id;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: const Text('Agregar extra'),
          content: DropdownButtonFormField<String>(
            value: selectedId,
            decoration: InputDecoration(
              labelText: 'Insumo',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            items: disponibles
                .map((i) => DropdownMenuItem(value: i.id, child: Text(i.nombre)))
                .toList(),
            onChanged: (v) => setModal(() => selectedId = v!),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                state.agregarExtraPedido(selectedId);
                Navigator.pop(ctx);
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  String _nombreInsumo(String id) =>
      state.insumos.firstWhere((i) => i.id == id,
          orElse: () => InsumoModel(id: id, nombre: id)).nombre;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (state.extrasPedido.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('No hay extras configurados.',
                style: TextStyle(color: AppTheme.grey600, fontSize: 13)),
          ),
        ...state.extrasPedido.asMap().entries.map((e) {
          final idx = e.key;
          final nombre = _nombreInsumo(e.value);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.grey300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(nombre,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
                GestureDetector(
                  onTap: () => state.eliminarExtraPedido(idx),
                  child: const Icon(Icons.delete_outline,
                      size: 18, color: AppTheme.red),
                ),
              ],
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: () => _showAgregarDialog(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Agregar extra'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.brownMed,
            side: const BorderSide(color: AppTheme.brownMed),
            minimumSize: const Size.fromHeight(46),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}

// ── Chip de margen estimado ───────────────────────────────────────────────────

class _MargenChip extends StatelessWidget {
  const _MargenChip({required this.producto, required this.state});
  final Producto producto;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final costo = state.costoEstimadoProducto(producto);
    if (costo == null) return const SizedBox.shrink();
    final margen = producto.precio - costo;
    final pct = costo > 0 ? (margen / costo * 100).round() : 0;
    final positive = margen >= 0;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: positive ? AppTheme.greenLight : AppTheme.redLight,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${positive ? '+' : ''}$pct%',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: positive ? AppTheme.green : AppTheme.red,
          ),
        ),
      ),
    );
  }
}
