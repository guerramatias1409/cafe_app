import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/print_dialog.dart';

final _moneda = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);

// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA PRINCIPAL
// ═══════════════════════════════════════════════════════════════════════════════

class VentasScreen extends StatefulWidget {
  const VentasScreen({super.key});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  final List<ItemCarrito> _carrito = [];
  MedioPago _medioPago = MedioPago.efectivo;
  int _propina = 0;
  MedioPago _propinaMedioPago = MedioPago.efectivo;

  int get _totalCarrito => _carrito.fold(0, (s, it) => s + it.precioTotal);

  void _agregarItem(ItemCarrito item) => setState(() => _carrito.add(item));

  void _quitarItem(int index) => setState(() => _carrito.removeAt(index));

  void _limpiarCarrito() => setState(() {
        _carrito.clear();
        _medioPago = MedioPago.efectivo;
        _propina = 0;
        _propinaMedioPago = MedioPago.efectivo;
      });

  void _confirmarVenta(AppState state, Map<String, int> extras) {
    if (_carrito.isEmpty) return;
    state.registrarVenta(
      items: List.from(_carrito),
      medioPago: _medioPago,
      propina: _propina,
      propinaMedioPago: _propinaMedioPago,
    );
    if (extras.isNotEmpty) state.descontarExtrasStock(extras);
    final ventaRegistrada = state.ventas.last;
    _limpiarCarrito();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PrintDialog(venta: ventaRegistrada),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    if (isLandscape) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: _SelectorPanel(onAgregar: _agregarItem, state: state),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 2,
            child: _CarritoPanel(
              carrito: _carrito,
              medioPago: _medioPago,
              total: _totalCarrito,
              propina: _propina,
              propinaMedioPago: _propinaMedioPago,
              onQuitarItem: _quitarItem,
              onMedioPago: (m) => setState(() => _medioPago = m),
              onPropina: (v) => setState(() => _propina = v),
              onPropinaMedioPago: (m) => setState(() => _propinaMedioPago = m),
              onConfirmar: (extras) => _confirmarVenta(state, extras),
              onCancelar: _limpiarCarrito,
              state: state,
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SelectorPanel(onAgregar: _agregarItem, state: state),
          if (_carrito.isNotEmpty) ...[
            const SizedBox(height: 24),
            _CarritoPanel(
              carrito: _carrito,
              medioPago: _medioPago,
              total: _totalCarrito,
              propina: _propina,
              propinaMedioPago: _propinaMedioPago,
              onQuitarItem: _quitarItem,
              onMedioPago: (m) => setState(() => _medioPago = m),
              onPropina: (v) => setState(() => _propina = v),
              onPropinaMedioPago: (m) => setState(() => _propinaMedioPago = m),
              onConfirmar: (extras) => _confirmarVenta(state, extras),
              onCancelar: _limpiarCarrito,
              state: state,
            ),
          ],
          const SizedBox(height: 32),
          if (state.ventas.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SectionHeader('Últimas ventas'),
                GestureDetector(
                  onTap: () => _showUndoDialog(context, state),
                  child: const Text('Deshacer última',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.caramel,
                        decoration: TextDecoration.underline,
                      )),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...state.ventas.reversed.take(5).map((v) => _VentaRow(v: v)),
          ],
        ],
      ),
    );
  }

  void _showUndoDialog(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deshacer última venta'),
        content: Text(
            '¿Revertir la última venta (${state.ventas.last.resumenCorto})?\nEl stock se va a restaurar.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              state.eliminarUltimaVenta();
              Navigator.pop(context);
            },
            child:
                const Text('Deshacer', style: TextStyle(color: AppTheme.red)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PANEL SELECTOR — VISTA POR CATEGORÍAS
// ═══════════════════════════════════════════════════════════════════════════════

class _SelectorPanel extends StatefulWidget {
  final ValueChanged<ItemCarrito> onAgregar;
  final AppState state;

  const _SelectorPanel({required this.onAgregar, required this.state});

  @override
  State<_SelectorPanel> createState() => _SelectorPanelState();
}

class _SelectorPanelState extends State<_SelectorPanel> {
  // id (combo o producto) → cantidad seleccionada
  final Map<String, int> _cantidades = {};

  // secciones expandidas
  final Map<String, bool> _expandido = {
    'Combos': false,
    'Cafetería': false,
    'Delicias Dulces': false,
    'Salados': false,
  };

  int get _total {
    int t = 0;
    for (final c in widget.state.combos) {
      t += c.precioFijo * (_cantidades[c.id] ?? 0);
    }
    for (final p in widget.state.productos) {
      t += p.precio * (_cantidades[p.id] ?? 0);
    }
    return t;
  }

  bool get _hayItems => _cantidades.values.any((v) => v > 0);

  void _agregar() {
    for (final c in widget.state.combos) {
      final qty = _cantidades[c.id] ?? 0;
      if (qty > 0) {
        widget.onAgregar(ItemCarrito(
          comboId: c.id,
          comboNombre: c.nombre,
          cafesAdicionales: 0,
          precioUnitario: c.precioFijo,
          cantidad: qty,
        ));
      }
    }
    for (final p in widget.state.productos) {
      final qty = _cantidades[p.id] ?? 0;
      if (qty > 0) {
        widget.onAgregar(ItemCarrito(
          comboId: p.id,
          comboNombre: p.displayNombre, // incluye tamaño si es Cafetería
          cafesAdicionales: 0,
          precioUnitario: p.precio,
          cantidad: qty,
        ));
      }
    }
    setState(() => _cantidades.clear());
  }

  // ── Fila individual (combo o producto) ──────────────────────────────────────

  Widget _buildRow(String id, String nombre, int precio) {
    final qty = _cantidades[id] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: qty > 0 ? AppTheme.cream : AppTheme.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: qty > 0 ? AppTheme.caramel : AppTheme.grey300,
            width: qty > 0 ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          qty > 0 ? FontWeight.w600 : FontWeight.w400,
                      color: AppTheme.brownDark,
                    ),
                  ),
                  Text(
                    _moneda.format(precio),
                    style: TextStyle(
                      fontSize: 12,
                      color: qty > 0
                          ? AppTheme.caramel
                          : AppTheme.grey600,
                    ),
                  ),
                ],
              ),
            ),
            NumberStepper(
              value: qty,
              max: 20,
              onChanged: (v) =>
                  setState(() => _cantidades[id] = v),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bloque de categoría ──────────────────────────────────────────────────────

  Widget _grid(List<Widget> items) {
    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: items[i]),
            const SizedBox(width: 8),
            if (i + 1 < items.length)
              Expanded(child: items[i + 1])
            else
              const Expanded(child: SizedBox()),
          ],
        ),
      ));
    }
    return Column(children: rows);
  }

  Widget _seccion(String label, List<Widget> rows, bool isLandscape) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final expandido = _expandido[label] ?? true;
    final hPad = isLandscape ? 20.0 : 0.0;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header tappable
          GestureDetector(
            onTap: () => setState(() => _expandido[label] = !expandido),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: hPad),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: expandido ? AppTheme.cream : AppTheme.white,
                borderRadius: expandido
                    ? const BorderRadius.vertical(top: Radius.circular(12))
                    : BorderRadius.circular(12),
                border: Border.all(
                  color: expandido
                      ? AppTheme.caramel.withOpacity(0.5)
                      : AppTheme.grey300,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: expandido ? AppTheme.brownDark : AppTheme.grey600,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expandido ? 0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down,
                        size: 20,
                        color: expandido ? AppTheme.caramel : AppTheme.grey600),
                  ),
                ],
              ),
            ),
          ),
          // Contenido expandido
          if (expandido)
            Container(
              margin: EdgeInsets.symmetric(horizontal: hPad),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12)),
                border: Border(
                  left: BorderSide(
                      color: AppTheme.caramel.withOpacity(0.5)),
                  right: BorderSide(
                      color: AppTheme.caramel.withOpacity(0.5)),
                  bottom: BorderSide(
                      color: AppTheme.caramel.withOpacity(0.5)),
                ),
              ),
              child: _grid(rows),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final state = widget.state;

    // ── Filas por categoría ──────────────────────────────────────────────────
    final combosRows = state.combos
        .map((c) => _buildRow(c.id, c.nombre, c.precioFijo))
        .toList();

    final cafeteriaRows = state.productos
        .where((p) => p.activo && p.categoria == CategoriaProducto.cafeteria)
        .map((p) => _buildRow(p.id, p.displayNombre, p.precio))
        .toList();

    final dulcesRows = state.productos
        .where((p) => p.activo && p.categoria == CategoriaProducto.deliciasDulces)
        .map((p) => _buildRow(p.id, p.nombre, p.precio))
        .toList();

    final saladosRows = state.productos
        .where((p) => p.activo && p.categoria == CategoriaProducto.salados)
        .map((p) => _buildRow(p.id, p.nombre, p.precio))
        .toList();

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isLandscape) const SizedBox(height: 20),

        // Título del panel
        if (isLandscape)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SectionHeader('Agregar al pedido'),
          )
        else
          const SectionHeader('Agregar al pedido'),

        // ── Categorías ────────────────────────────────────────────────────
        _seccion('Combos', combosRows, isLandscape),
        _seccion('Cafetería', cafeteriaRows, isLandscape),
        _seccion('Delicias Dulces', dulcesRows, isLandscape),
        _seccion('Salados', saladosRows, isLandscape),

        const SizedBox(height: 20),

        // ── Botón agregar ─────────────────────────────────────────────────
        Padding(
          padding: isLandscape
              ? const EdgeInsets.symmetric(horizontal: 20)
              : EdgeInsets.zero,
          child: AnimatedOpacity(
            opacity: _hayItems ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 150),
            child: ElevatedButton.icon(
              onPressed: _hayItems ? _agregar : null,
              icon: const Icon(Icons.add, size: 18),
              label: Text(_hayItems
                  ? 'Agregar al pedido  –  ${_moneda.format(_total)}'
                  : 'Seleccioná un ítem'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.caramel,
                disabledBackgroundColor: AppTheme.grey300,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),

        if (!isLandscape) const SizedBox(height: 4),
      ],
    );

    if (isLandscape) {
      return SingleChildScrollView(child: content);
    }
    return content;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PANEL CARRITO
// ═══════════════════════════════════════════════════════════════════════════════

class _CarritoPanel extends StatefulWidget {
  final List<ItemCarrito> carrito;
  final MedioPago medioPago;
  final int total;
  final int propina;
  final MedioPago propinaMedioPago;
  final ValueChanged<int> onQuitarItem;
  final ValueChanged<MedioPago> onMedioPago;
  final ValueChanged<int> onPropina;
  final ValueChanged<MedioPago> onPropinaMedioPago;
  final ValueChanged<Map<String, int>> onConfirmar;
  final VoidCallback onCancelar;
  final AppState state;

  const _CarritoPanel({
    required this.carrito,
    required this.medioPago,
    required this.total,
    required this.propina,
    required this.propinaMedioPago,
    required this.onQuitarItem,
    required this.onMedioPago,
    required this.onPropina,
    required this.onPropinaMedioPago,
    required this.onConfirmar,
    required this.onCancelar,
    required this.state,
  });

  @override
  State<_CarritoPanel> createState() => _CarritoPanelState();
}

class _CarritoPanelState extends State<_CarritoPanel> {
  late List<int> _cantExtras;

  @override
  void initState() {
    super.initState();
    _cantExtras = List.filled(widget.state.extrasPedido.length, 0);
  }

  @override
  void didUpdateWidget(_CarritoPanel old) {
    super.didUpdateWidget(old);
    // Si cambia la lista de extras, ajustar el tamaño
    final n = widget.state.extrasPedido.length;
    if (_cantExtras.length != n) {
      _cantExtras = List.filled(n, 0);
    }
    // Resetear cantidades al vaciar el carrito
    if (old.carrito.isNotEmpty && widget.carrito.isEmpty) {
      _cantExtras = List.filled(n, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isLandscape) const SizedBox(height: 20),

        // Header carrito
        Padding(
          padding: isLandscape
              ? const EdgeInsets.symmetric(horizontal: 20)
              : EdgeInsets.zero,
          child: Row(
            children: [
              const SectionHeader('Pedido'),
              const SizedBox(width: 8),
              if (widget.carrito.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.caramel,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${widget.carrito.length}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
            ],
          ),
        ),

        // Ítems del carrito
        Padding(
          padding: isLandscape
              ? const EdgeInsets.symmetric(horizontal: 20)
              : EdgeInsets.zero,
          child: widget.carrito.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.grey100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.grey300),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.shopping_bag_outlined,
                          color: AppTheme.grey300, size: 32),
                      SizedBox(height: 6),
                      Text('El pedido está vacío',
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.grey600)),
                    ],
                  ),
                )
              : Column(
                  children: widget.carrito
                      .asMap()
                      .entries
                      .map((e) => _ItemCarritoRow(
                            item: e.value,
                            onQuitar: () => widget.onQuitarItem(e.key),
                          ))
                      .toList(),
                ),
        ),

        if (widget.carrito.isNotEmpty) ...[
          const SizedBox(height: 20),

          // Extras del pedido
          if (widget.state.extrasPedido.isNotEmpty)
            Padding(
              padding: isLandscape
                  ? const EdgeInsets.symmetric(horizontal: 20)
                  : EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader('Extras'),
                  const SizedBox(height: 8),
                  ...widget.state.extrasPedido.asMap().entries.map((e) {
                    final idx = e.key;
                    final insumoId = e.value;
                    final nombre = widget.state.insumos
                        .firstWhere((i) => i.id == insumoId,
                            orElse: () => InsumoModel(id: insumoId, nombre: insumoId))
                        .nombre;
                    final cant = _cantExtras.length > idx ? _cantExtras[idx] : 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(nombre,
                                style: const TextStyle(
                                    fontSize: 14, color: AppTheme.brownDark)),
                          ),
                          _CounterButton(
                            count: cant,
                            onDecrement: cant > 0
                                ? () => setState(() => _cantExtras[idx]--)
                                : null,
                            onIncrement: () => setState(() => _cantExtras[idx]++),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                ],
              ),
            ),

          // Medio de pago
          Padding(
            padding: isLandscape
                ? const EdgeInsets.symmetric(horizontal: 20)
                : EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader('Medio de pago'),
                _MedioPagoSelector(
                    selected: widget.medioPago, onSelected: widget.onMedioPago),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Propina (opcional)
          Padding(
            padding: isLandscape
                ? const EdgeInsets.symmetric(horizontal: 20)
                : EdgeInsets.zero,
            child: _PropinaSection(
              propina: widget.propina,
              medioPago: widget.propinaMedioPago,
              onPropina: widget.onPropina,
              onMedioPago: widget.onPropinaMedioPago,
            ),
          ),

          const SizedBox(height: 20),

          // Total + botones
          Padding(
            padding: isLandscape
                ? const EdgeInsets.symmetric(horizontal: 20)
                : EdgeInsets.zero,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cream,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.caramel),
              ),
              child: Column(
                children: [
                  if (widget.propina > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal',
                            style: TextStyle(fontSize: 13, color: AppTheme.grey600)),
                        Text(_moneda.format(widget.total),
                            style: const TextStyle(fontSize: 13, color: AppTheme.grey600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Propina  ${widget.propinaMedioPago.emoji}',
                            style: const TextStyle(fontSize: 13, color: AppTheme.grey600)),
                        Text(_moneda.format(widget.propina),
                            style: const TextStyle(fontSize: 13, color: AppTheme.grey600)),
                      ],
                    ),
                    const Divider(height: 16),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total a cobrar',
                          style: TextStyle(
                              fontSize: 14, color: AppTheme.brownMed)),
                      Text(
                        _moneda.format(widget.total + widget.propina),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.brownDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: widget.onCancelar,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.grey600,
                            side: const BorderSide(
                                color: AppTheme.grey300),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(10)),
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            final extras = <String, int>{};
                            final ids = widget.state.extrasPedido;
                            for (var i = 0; i < ids.length; i++) {
                              final cant = _cantExtras.length > i ? _cantExtras[i] : 0;
                              if (cant > 0) extras[ids[i]] = cant;
                            }
                            widget.onConfirmar(extras);
                          },
                          child: const Text('Confirmar venta'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],

        if (!isLandscape) const SizedBox(height: 24),
      ],
    );

    if (isLandscape) {
      return SingleChildScrollView(child: content);
    }
    return content;
  }
}

// ── Sección propina ───────────────────────────────────────────────────────────

class _PropinaSection extends StatefulWidget {
  final int propina;
  final MedioPago medioPago;
  final ValueChanged<int> onPropina;
  final ValueChanged<MedioPago> onMedioPago;

  const _PropinaSection({
    required this.propina,
    required this.medioPago,
    required this.onPropina,
    required this.onMedioPago,
  });

  @override
  State<_PropinaSection> createState() => _PropinaSectionState();
}

class _PropinaSectionState extends State<_PropinaSection> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.propina > 0 ? widget.propina.toString() : '');
  }

  @override
  void didUpdateWidget(_PropinaSection old) {
    super.didUpdateWidget(old);
    if (widget.propina == 0 && old.propina != 0) _ctrl.clear();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Propina (opcional)'),
        const SizedBox(height: 8),
        Row(
          children: [
            // Campo de monto
            SizedBox(
              width: 120,
              child: TextField(
                controller: _ctrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: '\$0',
                  prefixText: '\$ ',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.grey300)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.grey300)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppTheme.caramel, width: 1.5)),
                ),
                onChanged: (v) =>
                    widget.onPropina(int.tryParse(v) ?? 0),
              ),
            ),
            const SizedBox(width: 12),
            // Selector de medio de pago compacto
            Expanded(
              child: Row(
                children: MedioPago.values.map((m) {
                  final sel = m == widget.medioPago;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: m != MedioPago.posnet ? 6 : 0),
                      child: GestureDetector(
                        onTap: () => widget.onMedioPago(m),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: sel ? AppTheme.cream : AppTheme.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: sel ? AppTheme.caramel : AppTheme.grey300,
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(m.emoji,
                                  style: const TextStyle(fontSize: 16)),
                              const SizedBox(height: 2),
                              Text(m.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: sel
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: sel
                                        ? AppTheme.brownMed
                                        : AppTheme.grey600,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Ítem en el carrito ────────────────────────────────────────────────────────

class _ItemCarritoRow extends StatelessWidget {
  final ItemCarrito item;
  final VoidCallback onQuitar;

  const _ItemCarritoRow({required this.item, required this.onQuitar});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.grey300),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.comboNombre +
                  (item.cafesAdicionales > 0
                      ? ' +${item.cafesAdicionales} café${item.cafesAdicionales > 1 ? 's' : ''}'
                      : '') +
                  (item.cantidad > 1 ? ' ×${item.cantidad}' : ''),
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.brownDark),
            ),
          ),
          Text(
            _moneda.format(item.precioTotal),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.caramel,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onQuitar,
            child: const Icon(Icons.close,
                size: 18, color: AppTheme.grey600),
          ),
        ],
      ),
    );
  }
}

// ── Medio de pago selector ────────────────────────────────────────────────────

class _MedioPagoSelector extends StatelessWidget {
  final MedioPago selected;
  final ValueChanged<MedioPago> onSelected;

  const _MedioPagoSelector(
      {required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) => Row(
        children: MedioPago.values.map((m) {
          final isSelected = m == selected;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  right: m != MedioPago.posnet ? 8 : 0),
              child: GestureDetector(
                onTap: () => onSelected(m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.cream : AppTheme.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.caramel
                          : AppTheme.grey300,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(m.emoji,
                          style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 4),
                      Text(m.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? AppTheme.brownMed
                                : AppTheme.grey600,
                          )),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
}

// PrintDialog está en lib/widgets/print_dialog.dart

// ── Venta row (historial reciente) ────────────────────────────────────────────

class _VentaRow extends StatelessWidget {
  final Venta v;
  const _VentaRow({required this.v});

  @override
  Widget build(BuildContext context) {
    final hora = DateFormat('HH:mm').format(v.timestamp);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.grey300),
      ),
      child: Row(
        children: [
          Text(hora,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.grey600,
                  fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(width: 12),
          Expanded(
            child: Text(v.resumenCorto,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.brownDark)),
          ),
          Text(v.medioPago.emoji,
              style: const TextStyle(fontSize: 14)),
          if (v.propina > 0) ...[
            const SizedBox(width: 4),
            Text('🤝', style: const TextStyle(fontSize: 12)),
          ],
          const SizedBox(width: 8),
          Text(
            _moneda.format(v.precioTotal + v.propina),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.green,
            ),
          ),
        ],
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final int count;
  final VoidCallback? onDecrement;
  final VoidCallback onIncrement;

  const _CounterButton({
    required this.count,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onDecrement,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: onDecrement != null ? AppTheme.cream : AppTheme.grey100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: onDecrement != null ? AppTheme.caramel : AppTheme.grey300,
              ),
            ),
            child: Icon(Icons.remove,
                size: 16,
                color: onDecrement != null ? AppTheme.brownDark : AppTheme.grey300),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$count',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.brownDark),
          ),
        ),
        GestureDetector(
          onTap: onIncrement,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.cream,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.caramel),
            ),
            child: const Icon(Icons.add, size: 16, color: AppTheme.brownDark),
          ),
        ),
      ],
    );
  }
}
