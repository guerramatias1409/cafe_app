import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';


class StockScreen extends StatelessWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Stock del día'),
          const SizedBox(height: 4),
          const Text(
            'Ingresá el stock inicial antes de arrancar.',
            style: TextStyle(fontSize: 13, color: AppTheme.grey600),
          ),
          const SizedBox(height: 16),

          // ── Insumos fijos ──────────────────────────────────────────────────
          const SectionHeader('Insumos'),
          const SizedBox(height: 8),
          ...Insumo.values.map((insumo) {
            final entry = state.stock[insumo]!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StockRow(entry: entry, state: state),
            );
          }),

          // ── Productos ──────────────────────────────────────────────────────
          if (state.productos.any((p) => p.categoria != CategoriaProducto.cafeteria && !p.consumeItems)) ...[
            const SizedBox(height: 16),
            const SectionHeader('Productos'),
            const SizedBox(height: 8),
            ...state.productos.where((p) => p.categoria != CategoriaProducto.cafeteria && !p.consumeItems).map((p) {
              final inicial = state.stockInicialProductos[p.id] ?? 0;
              final vendidos = state.stockVendidosProducto(p.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ProductoStockRow(
                  producto: p,
                  inicial: inicial,
                  vendidos: vendidos,
                  state: state,
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _StockRow extends StatefulWidget {
  final StockEntry entry;
  final AppState state;

  const _StockRow({required this.entry, required this.state});

  @override
  State<_StockRow> createState() => _StockRowState();
}

class _StockRowState extends State<_StockRow> {
  late TextEditingController _ctrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.entry.inicial.toString());
  }

  @override
  void didUpdateWidget(_StockRow old) {
    super.didUpdateWidget(old);
    if (!_editing && old.entry.inicial != widget.entry.inicial) {
      _ctrl.text = widget.entry.inicial.toString();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final val = int.tryParse(_ctrl.text) ?? 0;
    widget.state.setStockInicial(widget.entry.insumo, val);
    setState(() => _editing = false);
    FocusScope.of(context).unfocus();
  }

  Color _stockColor(int actual, int inicial) {
    if (inicial == 0) return AppTheme.grey600;
    final pct = actual / inicial;
    if (pct <= 0) return AppTheme.red;
    if (pct <= 0.25) return Colors.orange;
    return AppTheme.green;
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final stockColor = _stockColor(entry.actual, entry.inicial);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: entry.actual <= 0 && entry.inicial > 0 ? AppTheme.red.withOpacity(0.4) : AppTheme.grey300,
        ),
      ),
      child: Row(
        children: [
          // Insumo name
          Expanded(
            flex: 3,
            child: Text(
              entry.insumo.label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.brownDark),
            ),
          ),

          // Stock inicial editable
          Expanded(
            flex: 2,
            child: Focus(
              onFocusChange: (hasFocus) {
                if (hasFocus)
                  setState(() => _editing = true);
                else
                  _save();
              },
              child: TextField(
                controller: _ctrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.blue,
                ),
                decoration: InputDecoration(
                  labelText: 'Inicial',
                  labelStyle: const TextStyle(fontSize: 11),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.grey300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.grey300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.caramel, width: 1.5),
                  ),
                ),
                onSubmitted: (_) => _save(),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Vendidos
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Text('${entry.vendidos}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.grey600)),
                const Text('vendidos', style: TextStyle(fontSize: 10, color: AppTheme.grey600)),
              ],
            ),
          ),

          const SizedBox(width: 4),

          // Stock actual
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Text(
                  '${entry.actual}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: stockColor,
                  ),
                ),
                const Text('quedan', style: TextStyle(fontSize: 10, color: AppTheme.grey600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stock row para productos del menú ─────────────────────────────────────────

class _ProductoStockRow extends StatefulWidget {
  final Producto producto;
  final int inicial;
  final int vendidos;
  final AppState state;

  const _ProductoStockRow({
    required this.producto,
    required this.inicial,
    required this.vendidos,
    required this.state,
  });

  @override
  State<_ProductoStockRow> createState() => _ProductoStockRowState();
}

class _ProductoStockRowState extends State<_ProductoStockRow> {
  late TextEditingController _ctrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.inicial.toString());
  }

  @override
  void didUpdateWidget(_ProductoStockRow old) {
    super.didUpdateWidget(old);
    if (!_editing && old.inicial != widget.inicial) {
      _ctrl.text = widget.inicial.toString();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final val = int.tryParse(_ctrl.text) ?? 0;
    widget.state.setStockInicialProducto(widget.producto.id, val);
    setState(() => _editing = false);
    FocusScope.of(context).unfocus();
  }

  Color _stockColor(int actual, int inicial) {
    if (inicial == 0) return AppTheme.grey600;
    final pct = actual / inicial;
    if (pct <= 0) return AppTheme.red;
    if (pct <= 0.25) return Colors.orange;
    return AppTheme.green;
  }

  @override
  Widget build(BuildContext context) {
    final actual = widget.inicial - widget.vendidos;
    final stockColor = _stockColor(actual, widget.inicial);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: actual <= 0 && widget.inicial > 0 ? AppTheme.red.withOpacity(0.4) : AppTheme.grey300,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              widget.producto.displayNombre,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.brownDark),
            ),
          ),
          Expanded(
            flex: 2,
            child: Focus(
              onFocusChange: (hasFocus) {
                if (hasFocus)
                  setState(() => _editing = true);
                else
                  _save();
              },
              child: TextField(
                controller: _ctrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.blue,
                ),
                decoration: InputDecoration(
                  labelText: 'Inicial',
                  labelStyle: const TextStyle(fontSize: 11),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.grey300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.grey300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.caramel, width: 1.5),
                  ),
                ),
                onSubmitted: (_) => _save(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Text('${widget.vendidos}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.grey600)),
                const Text('vendidos', style: TextStyle(fontSize: 10, color: AppTheme.grey600)),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Text(
                  '$actual',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: stockColor,
                  ),
                ),
                const Text('quedan', style: TextStyle(fontSize: 10, color: AppTheme.grey600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
