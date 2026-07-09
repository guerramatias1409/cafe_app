import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';

final _moneda = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);

class ResumenScreen extends StatelessWidget {
  const ResumenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Total recaudado highlight
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.brownDark,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recaudación total',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.white60,
                        fontWeight: FontWeight.w400)),
                const SizedBox(height: 6),
                Text(
                  _moneda.format(state.totalRecaudado),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${state.ventas.length} venta${state.ventas.length != 1 ? "s" : ""} registrada${state.ventas.length != 1 ? "s" : ""}',
                  style: const TextStyle(
                      fontSize: 13, color: Colors.white60),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Por medio de pago
          const SectionHeader('Por medio de pago'),
          ...MedioPago.values.map((m) {
            final monto = state.recaudadoPorMedio(m);
            final count = state.ventas.where((v) => v.medioPago == m).length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: StatCard(
                label: '${m.emoji}  ${m.label}',
                value: _moneda.format(monto),
                valueColor: monto > 0 ? AppTheme.brownDark : AppTheme.grey300,
                trailing: count > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.cream,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.caramel),
                        ),
                        child: Text('$count',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.caramel,
                            )),
                      )
                    : null,
              ),
            );
          }),

          const SizedBox(height: 24),

          // ── Ventas por combo
          const SectionHeader('Ventas por combo'),
          ...state.combos.map((combo) {
            final count = state.ventasPorCombo(combo.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _ComboStat(combo: combo, count: count),
            );
          }),

        ],
      ),
    );
  }


}

class _ComboStat extends StatelessWidget {
  final Combo combo;
  final int count;

  const _ComboStat({required this.combo, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: count > 0 ? AppTheme.white : AppTheme.grey100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.grey300),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              combo.nombre,
              style: TextStyle(
                fontSize: 13,
                color: count > 0 ? AppTheme.brownDark : AppTheme.grey600,
                fontWeight:
                    count > 0 ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: count > 0 ? AppTheme.caramel : AppTheme.grey300,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(
              _moneda.format(count * combo.precioFijo),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: count > 0 ? AppTheme.green : AppTheme.grey300,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
