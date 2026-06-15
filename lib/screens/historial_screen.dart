import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import '../widgets/print_dialog.dart';

final _moneda = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);

class HistorialScreen extends StatelessWidget {
  const HistorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final ventas = state.ventas.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            color: AppTheme.white,
            border: Border(bottom: BorderSide(color: AppTheme.grey300)),
          ),
          child: Row(
            children: [
              Text('${ventas.length} venta${ventas.length != 1 ? "s" : ""}',
                  style: const TextStyle(fontSize: 14, color: AppTheme.grey600)),
              const Spacer(),
              if (ventas.isNotEmpty) ...[
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
          child: ventas.isEmpty
              ? const _EmptyState()
              : _VentasList(ventas: ventas, state: state,
                  onEliminar: (v) => _confirmarEliminar(context, state, v)),
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

class _VentasList extends StatelessWidget {
  final List<Venta> ventas;
  final AppState state;
  final ValueChanged<Venta> onEliminar;

  const _VentasList(
      {required this.ventas, required this.state, required this.onEliminar});

  String _labelDia(DateTime ts, DateTime hoy) {
    final mismoAnio = ts.year == hoy.year;
    final esHoy = ts.year == hoy.year && ts.month == hoy.month && ts.day == hoy.day;
    if (esHoy) return 'Hoy';
    if (mismoAnio) return DateFormat('dd/MM').format(ts);
    return DateFormat('dd/MM/yyyy').format(ts);
  }

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();

    // Ordenar de más reciente a más antigua
    final sorted = [...ventas]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Agrupar por día (yyyy-MM-dd)
    final grupos = <String, List<Venta>>{};
    for (final v in sorted) {
      final key =
          '${v.timestamp.year}-${v.timestamp.month}-${v.timestamp.day}';
      grupos.putIfAbsent(key, () => []).add(v);
    }

    // Construir lista plana: header + ventas del día
    final items = <Object>[];
    for (final entry in grupos.entries) {
      final diaVentas = entry.value;
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
      items.add(_DiaHeader(label: label, total: totalDia, porMedio: porMedio));
      items.addAll(diaVentas);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is _DiaHeader) {
          return _DiaHeaderWidget(header: item);
        }
        final v = item as Venta;
        return _VentaCard(v: v, state: state, onEliminar: () => onEliminar(v));
      },
    );
  }
}

class _DiaHeader {
  final String label;
  final int total;
  final Map<MedioPago, int> porMedio;
  const _DiaHeader({required this.label, required this.total, required this.porMedio});
}

class _DiaHeaderWidget extends StatelessWidget {
  final _DiaHeader header;
  const _DiaHeaderWidget({required this.header});

  @override
  Widget build(BuildContext context) {
    final mediosActivos = MedioPago.values
        .where((m) => (header.porMedio[m] ?? 0) > 0)
        .toList();

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila: fecha | línea | total
          Row(
            children: [
              Text(
                header.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.caramel,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(child: Divider(color: AppTheme.grey300, height: 1)),
              const SizedBox(width: 8),
              Text(
                _moneda.format(header.total),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.brownDark,
                ),
              ),
            ],
          ),
          // Fila: desglose por medio de pago
          if (mediosActivos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: mediosActivos.map((m) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(m.emoji, style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 3),
                      Text(
                        _moneda.format(header.porMedio[m]),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.grey600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
        ],
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

  const _VentaCard({required this.v, required this.onEliminar, required this.state});

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
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
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
                        : ''),
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.brownDark),
              ),
            ),
            Text(
              _moneda.format(item.precioUnitario),
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
