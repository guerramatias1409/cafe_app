import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import '../widgets/print_dialog.dart';

final _moneda = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  int _tab = 0; // 0 = ventas, 1 = reporte

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final ventas = state.ventas.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Switcher de tabs
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: AppTheme.white,
            border: Border(bottom: BorderSide(color: AppTheme.grey300)),
          ),
          child: Row(
            children: [
              _TabChip(label: 'Ventas', selected: _tab == 0,
                  onTap: () => setState(() => _tab = 0)),
              const SizedBox(width: 8),
              _TabChip(label: 'Por producto', selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1)),
              const Spacer(),
              if (_tab == 0 && ventas.isNotEmpty) ...[
                const Text('Total ',
                    style: TextStyle(fontSize: 14, color: AppTheme.grey600)),
                Text(
                  _moneda.format(state.totalRecaudado),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.brownDark),
                ),
              ],
            ],
          ),
        ),

        Expanded(
          child: _tab == 0
              ? (ventas.isEmpty
                  ? const _EmptyState()
                  : _VentasList(
                      ventas: ventas,
                      state: state,
                      onEliminar: (v) => _confirmarEliminar(context, state, v),
                    ))
              : _ReporteProductos(ventas: state.ventas),
        ),
      ],
    );
  }

  void _confirmarEliminar(
      BuildContext context, AppState state, Venta venta) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar venta'),
        content: Text(
          '¿Eliminás "${venta.resumenCorto}" (${_moneda.format(venta.precioTotal)})?\n'
          'Los insumos van a volver al stock.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              state.eliminarVenta(venta.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Venta eliminada'),
                  backgroundColor: AppTheme.red,
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              );
            },
            child: const Text('Eliminar',
                style: TextStyle(color: AppTheme.red)),
          ),
        ],
      ),
    );
  }
}

// ── Lista agrupada por día ────────────────────────────────────────────────────

class _VentasList extends StatefulWidget {
  final List<Venta> ventas;
  final AppState state;
  final ValueChanged<Venta> onEliminar;

  const _VentasList(
      {required this.ventas, required this.state, required this.onEliminar});

  @override
  State<_VentasList> createState() => _VentasListState();
}

class _VentasListState extends State<_VentasList> {
  late Set<String> _expandidos;

  String _dayKey(DateTime ts) =>
      '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')}';

  String _labelDia(DateTime ts, DateTime hoy) {
    final mismoAnio = ts.year == hoy.year;
    final esHoy = ts.year == hoy.year && ts.month == hoy.month && ts.day == hoy.day;
    if (esHoy) return 'Hoy';
    String label = mismoAnio
        ? DateFormat('EEEE dd/MM', 'es').format(ts)
        : DateFormat('dd/MM/yyyy').format(ts);
    return label[0].toUpperCase() + label.substring(1);
  }

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _expandidos = {_dayKey(hoy)};
  }

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();

    final sorted = [...widget.ventas]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Agrupar por día
    final grupos = <String, List<Venta>>{};
    for (final v in sorted) {
      grupos.putIfAbsent(_dayKey(v.timestamp), () => []).add(v);
    }

    // Construir lista: un ítem por día (header + ventas colapsables)
    final dias = grupos.entries.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dias.length,
      itemBuilder: (context, index) {
        final entry = dias[index];
        final key = entry.key;
        final diaVentas = entry.value;
        final expanded = _expandidos.contains(key);

        final label = _labelDia(diaVentas.first.timestamp, hoy);
        final totalDia = diaVentas.fold(0, (s, v) => s + v.precioTotal + v.propina);
        final porMedio = <MedioPago, int>{};
        for (final v in diaVentas) {
          porMedio[v.medioPago] = (porMedio[v.medioPago] ?? 0) + v.precioTotal;
          if (v.propina > 0 && v.propinaMedioPago != null) {
            porMedio[v.propinaMedioPago!] =
                (porMedio[v.propinaMedioPago!] ?? 0) + v.propina;
          }
        }

        return Container(
          margin: EdgeInsets.only(top: index > 0 ? 12 : 0, bottom: 0),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.caramel.withOpacity(0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DiaHeaderWidget(
                label: label,
                total: totalDia,
                porMedio: porMedio,
                cantVentas: diaVentas.length,
                expanded: expanded,
                onTap: () => setState(() {
                  if (expanded) {
                    _expandidos.remove(key);
                  } else {
                    _expandidos.add(key);
                  }
                }),
              ),
              if (expanded) ...[
                const Divider(height: 1, color: AppTheme.grey300),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: diaVentas.asMap().entries.map((e) => _VentaCard(
                          v: e.value,
                          state: widget.state,
                          onEliminar: () => widget.onEliminar(e.value),
                          isLast: e.key == diaVentas.length - 1,
                        )).toList(),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DiaHeaderWidget extends StatelessWidget {
  final String label;
  final int total;
  final Map<MedioPago, int> porMedio;
  final int cantVentas;
  final bool expanded;
  final VoidCallback onTap;

  const _DiaHeaderWidget({
    required this.label,
    required this.total,
    required this.porMedio,
    required this.cantVentas,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final mediosActivos = MedioPago.values
        .where((m) => (porMedio[m] ?? 0) > 0)
        .toList();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.cream,
          borderRadius: expanded
              ? const BorderRadius.vertical(top: Radius.circular(11))
              : BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.brownDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$cantVentas venta${cantVentas != 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.grey600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (mediosActivos.isNotEmpty) ...[
                        ...mediosActivos.map((m) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(m.emoji, style: const TextStyle(fontSize: 11)),
                              const SizedBox(width: 3),
                              Text(
                                _moneda.format(porMedio[m]),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.grey600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Text(
                          _moneda.format(total),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.caramel,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.keyboard_arrow_down,
                  size: 20, color: AppTheme.grey600),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tarjeta de venta ──────────────────────────────────────────────────────────

void _editarPropina(BuildContext context, AppState state, Venta v) {
  final ctrl = TextEditingController(
      text: v.propina > 0 ? v.propina.toString() : '');
  MedioPago medio = v.propinaMedioPago ?? v.medioPago;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModal) => AlertDialog(
        title: const Text('Editar propina'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        content: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Monto',
                prefixText: '\$ ',
                hintText: '0',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppTheme.caramel, width: 1.5)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Medio de pago de la propina',
                style: TextStyle(fontSize: 13, color: AppTheme.grey600)),
            const SizedBox(height: 8),
            Row(
              children: MedioPago.values.map((m) {
                final sel = m == medio;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: m != MedioPago.posnet ? 8 : 0),
                    child: GestureDetector(
                      onTap: () => setModal(() => medio = m),
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
                            Text(m.emoji, style: const TextStyle(fontSize: 20)),
                            const SizedBox(height: 4),
                            Text(m.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight:
                                      sel ? FontWeight.w600 : FontWeight.w400,
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
          ],
        ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final amount = int.tryParse(ctrl.text) ?? 0;
              state.editarPropina(v.id, amount, medio);
              Navigator.pop(ctx);
            },
            child: const Text('Guardar',
                style: TextStyle(color: AppTheme.caramel)),
          ),
        ],
      ),
    ),
  );
}

void _editarMedioPago(BuildContext context, AppState state, Venta v) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Medio de pago'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: MedioPago.values.map((m) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Text(m.emoji, style: const TextStyle(fontSize: 20)),
              title: Text(m.label),
              trailing: v.medioPago == m
                  ? const Icon(Icons.check_circle,
                      color: AppTheme.caramel, size: 20)
                  : null,
              onTap: () {
                if (v.medioPago != m) state.editarMedioPago(v.id, m);
                Navigator.pop(context);
              },
            )).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    ),
  );
}

class _VentaCard extends StatefulWidget {
  final Venta v;
  final VoidCallback onEliminar;
  final AppState state;
  final bool isLast;

  const _VentaCard({required this.v, required this.onEliminar, required this.state, this.isLast = false});

  @override
  State<_VentaCard> createState() => _VentaCardState();
}

class _VentaCardState extends State<_VentaCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.v;
    final hora = DateFormat('HH:mm').format(v.timestamp);
    final tieneMultiples = v.items.length > 1;

    return Container(
      margin: EdgeInsets.only(bottom: widget.isLast ? 0 : 8),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.grey300),
      ),
      child: Column(
        children: [
          // Fila principal — swipeable para eliminar
          Dismissible(
            key: ValueKey(v.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) async {
              widget.onEliminar();
              return false; // el diálogo decide si elimina
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: AppTheme.redLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_outline, color: AppTheme.red),
                  SizedBox(width: 6),
                  Text('Eliminar',
                      style: TextStyle(
                          color: AppTheme.red, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: tieneMultiples
                  ? () => setState(() => _expanded = !_expanded)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    // Resumen + hora
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.resumenCorto,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.brownDark),
                          ),
                          Text(
                            hora +
                                (tieneMultiples
                                    ? '  ·  ${v.items.length} ítems'
                                    : ''),
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.grey600,
                                fontFeatures: [FontFeature.tabularFigures()]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Total (incluye propina)
                    Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _moneda.format(v.precioTotal + v.propina),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.green),
                        ),
                        if (v.propina > 0)
                          Text(
                            _moneda.format(v.precioTotal),
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.grey600,
                                decoration: TextDecoration.lineThrough),
                          ),
                      ],
                    ),
                    ),
                    // Medio de pago (tappable para editar)
                    GestureDetector(
                      onTap: () => _editarMedioPago(context, widget.state, v),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.cream,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.caramel.withOpacity(0.4)),
                        ),
                        child: Text(v.medioPago.emoji,
                            style: const TextStyle(fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Propina (tappable para editar)
                    GestureDetector(
                      onTap: () => _editarPropina(context, widget.state, v),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: v.propina > 0
                              ? AppTheme.green.withOpacity(0.1)
                              : AppTheme.grey100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: v.propina > 0
                                ? AppTheme.green.withOpacity(0.5)
                                : AppTheme.grey300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.volunteer_activism,
                                size: 12,
                                color: v.propina > 0
                                    ? AppTheme.green
                                    : AppTheme.grey600),
                            if (v.propina > 0) ...[
                              const SizedBox(width: 3),
                              Text(
                                _moneda.format(v.propina),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.green,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Text(v.propinaMedioPago!.emoji,
                                  style: const TextStyle(fontSize: 10)),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Botón reimprimir
                    GestureDetector(
                      onTap: () => showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => PrintDialog(
                          venta: v,
                          showSuccessBanner: false,
                        ),
                      ),
                      child: const Icon(Icons.print_outlined,
                          size: 18, color: AppTheme.grey600),
                    ),
                    const SizedBox(width: 6),
                    // Botón eliminar
                    GestureDetector(
                      onTap: widget.onEliminar,
                      child: const Icon(Icons.delete_outline,
                          size: 18, color: AppTheme.grey600),
                    ),
                    // Chevron si tiene múltiples
                    if (tieneMultiples) ...[
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.keyboard_arrow_down,
                            size: 18, color: AppTheme.grey600),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Detalle de ítems expandible
          if (tieneMultiples && _expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                children:
                    v.items.map((item) => _ItemRow(item: item)).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final ItemCarrito item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          children: [
            const SizedBox(width: 4),
            const Text('·',
                style:
                    TextStyle(color: AppTheme.caramel, fontSize: 16)),
            const SizedBox(width: 8),
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
                  fontWeight: FontWeight.w600,
                  color: AppTheme.caramel),
            ),
          ],
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 48, color: AppTheme.grey300),
            SizedBox(height: 12),
            Text('Todavía no hay ventas registradas',
                style: TextStyle(fontSize: 14, color: AppTheme.grey600)),
          ],
        ),
      );
}

// ── Tab chip ──────────────────────────────────────────────────────────────────

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.brownDark : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.brownDark : AppTheme.grey300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.grey600,
          ),
        ),
      ),
    );
  }
}

// ── Reporte por producto ──────────────────────────────────────────────────────

class _ReporteProductos extends StatefulWidget {
  final List<Venta> ventas;
  const _ReporteProductos({required this.ventas});

  @override
  State<_ReporteProductos> createState() => _ReporteProductosState();
}

class _ReporteProductosState extends State<_ReporteProductos> {
  DateTime? _desde;
  DateTime? _hasta;

  static final _fmtFecha = DateFormat('dd/MM/yyyy');

  /// Convierte un timestamp a hora de Argentina (UTC-3, sin DST).
  static DateTime _arDate(DateTime dt) {
    final ar = dt.toUtc().subtract(const Duration(hours: 3));
    return DateTime(ar.year, ar.month, ar.day); // solo la fecha, sin hora
  }

  List<Venta> get _ventasFiltradas {
    return widget.ventas.where((v) {
      final fechaVenta = _arDate(v.timestamp);
      if (_desde != null) {
        final desde = DateTime(_desde!.year, _desde!.month, _desde!.day);
        if (fechaVenta.isBefore(desde)) return false;
      }
      if (_hasta != null) {
        final hasta = DateTime(_hasta!.year, _hasta!.month, _hasta!.day);
        if (fechaVenta.isAfter(hasta)) return false;
      }
      return true;
    }).toList();
  }

  Map<String, _ProductoStats> get _stats {
    final map = <String, _ProductoStats>{};

    for (final venta in _ventasFiltradas) {
      for (final item in venta.items) {
        final entry = map.putIfAbsent(
          item.comboId,
          () => _ProductoStats(nombre: item.comboNombre),
        );
        entry.cantidad += item.cantidad;
        entry.total += item.precioTotal;
      }
    }

    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.cantidad.compareTo(a.value.cantidad));
    return Map.fromEntries(sorted);
  }

  Future<void> _pickDesde() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _desde ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      locale: const Locale('es'),
    );
    if (picked != null) setState(() => _desde = picked);
  }

  Future<void> _pickHasta() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _hasta ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      locale: const Locale('es'),
    );
    if (picked != null) setState(() => _hasta = picked);
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final totalUnidades = stats.values.fold(0, (s, e) => s + e.cantidad);
    final totalRecaudado = stats.values.fold(0, (s, e) => s + e.total);

    return Column(
      children: [
        // Selector de rango
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppTheme.white,
          child: Row(
            children: [
              const Text('Desde', style: TextStyle(fontSize: 13, color: AppTheme.grey600)),
              const SizedBox(width: 8),
              _DateButton(
                label: _desde != null ? _fmtFecha.format(_desde!) : 'cualquier fecha',
                onTap: _pickDesde,
                active: _desde != null,
              ),
              const SizedBox(width: 8),
              const Text('hasta', style: TextStyle(fontSize: 13, color: AppTheme.grey600)),
              const SizedBox(width: 8),
              _DateButton(
                label: _hasta != null ? _fmtFecha.format(_hasta!) : 'hoy',
                onTap: _pickHasta,
                active: _hasta != null,
              ),
              if (_desde != null || _hasta != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() { _desde = null; _hasta = null; }),
                  child: const Icon(Icons.close, size: 18, color: AppTheme.grey600),
                ),
              ],
            ],
          ),
        ),

        // Resumen rápido
        if (stats.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: AppTheme.cream,
              border: Border(bottom: BorderSide(color: AppTheme.grey300)),
            ),
            child: Row(
              children: [
                Text('${_ventasFiltradas.length} venta${_ventasFiltradas.length != 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 13, color: AppTheme.grey600)),
                const Text(' · ', style: TextStyle(color: AppTheme.grey600)),
                Text('$totalUnidades unidades',
                    style: const TextStyle(fontSize: 13, color: AppTheme.grey600)),
                const Spacer(),
                Text(
                  _moneda.format(totalRecaudado),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.brownDark),
                ),
              ],
            ),
          ),

        // Lista de productos
        Expanded(
          child: stats.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bar_chart_outlined, size: 48, color: AppTheme.grey300),
                      SizedBox(height: 12),
                      Text('Sin ventas en el período seleccionado',
                          style: TextStyle(fontSize: 14, color: AppTheme.grey600)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: stats.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final entry = stats.entries.elementAt(i);
                    final s = entry.value;
                    final maxCantidad = stats.values.first.cantidad;
                    return _ProductoReporteCard(
                      nombre: s.nombre,
                      cantidad: s.cantidad,
                      total: s.total,
                      fraccion: maxCantidad > 0 ? s.cantidad / maxCantidad : 0,
                      rank: i + 1,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ProductoStats {
  final String nombre;
  int cantidad = 0;
  int total = 0;
  _ProductoStats({required this.nombre});
}

class _DateButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool active;
  const _DateButton({required this.label, required this.onTap, required this.active});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppTheme.brownDark.withAlpha(15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppTheme.brownDark : AppTheme.grey300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 12,
                color: active ? AppTheme.brownDark : AppTheme.grey600),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: active ? AppTheme.brownDark : AppTheme.grey600,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

class _ProductoReporteCard extends StatelessWidget {
  final String nombre;
  final int cantidad;
  final int total;
  final double fraccion;
  final int rank;

  const _ProductoReporteCard({
    required this.nombre,
    required this.cantidad,
    required this.total,
    required this.fraccion,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rank == 1
                      ? AppTheme.caramel
                      : rank == 2
                          ? AppTheme.grey300
                          : AppTheme.cream,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: rank <= 2 ? AppTheme.brownDark : AppTheme.grey600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(nombre,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.brownDark)),
              ),
              Text(
                '$cantidad u.',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.brownDark),
              ),
              const SizedBox(width: 12),
              Text(
                _moneda.format(total),
                style: const TextStyle(fontSize: 13, color: AppTheme.grey600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraccion,
              minHeight: 5,
              backgroundColor: AppTheme.grey300,
              valueColor: AlwaysStoppedAnimation<Color>(
                  rank == 1 ? AppTheme.caramel : AppTheme.brownMed),
            ),
          ),
        ],
      ),
    );
  }
}
