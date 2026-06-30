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

          // ── Insumos dinámicos ─────────────────────────────────────────────
          const SectionHeader('Insumos'),
          const SizedBox(height: 8),
          ...state.insumos.map((insumo) {
            final entry = state.stock[insumo.id] ??
                StockEntry(insumoId: insumo.id, inicial: 0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StockRow(insumo: insumo, entry: entry, state: state),
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

// ── Widget reutilizable para campo mini ───────────────────────────────────────

class _MiniField extends StatelessWidget {
  const _MiniField({
    required this.controller,
    required this.label,
    required this.color,
    required this.onFocusLost,
  });
  final TextEditingController controller;
  final String label;
  final Color color;
  final VoidCallback onFocusLost;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) { if (!hasFocus) onFocusLost(); },
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 11),
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
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
        onSubmitted: (_) { onFocusLost(); FocusScope.of(context).unfocus(); },
      ),
    );
  }
}

class _StockRow extends StatefulWidget {
  final InsumoModel insumo;
  final StockEntry entry;
  final AppState state;

  const _StockRow({required this.insumo, required this.entry, required this.state});

  @override
  State<_StockRow> createState() => _StockRowState();
}

class _StockRowState extends State<_StockRow> {
  late TextEditingController _ctrl;
  late TextEditingController _minCtrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.entry.inicial.toString());
    _minCtrl = TextEditingController(
      text: (widget.state.stockMinimoInsumos[widget.insumo.id] ?? 0).toString(),
    );
  }

  @override
  void didUpdateWidget(_StockRow old) {
    super.didUpdateWidget(old);
    if (old.entry.inicial != widget.entry.inicial) {
      _ctrl.text = widget.entry.inicial.toString();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  void _saveInicial() {
    final val = int.tryParse(_ctrl.text) ?? 0;
    widget.state.setStockInicial(widget.insumo.id, val);
    FocusScope.of(context).unfocus();
  }

  void _saveMin() {
    final val = int.tryParse(_minCtrl.text) ?? 0;
    widget.state.setStockMinimoInsumo(widget.insumo.id, val);
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
    final bajominimo = widget.state.stockBajoMinimo(widget.insumo.id);
    final stockColor = entry.actual <= 0 && entry.inicial > 0
        ? AppTheme.red
        : bajominimo
            ? Colors.orange
            : _stockColor(entry.actual, entry.inicial);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bajominimo ? const Color(0xFFFFF8E1) : AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: bajominimo
              ? Colors.orange.withOpacity(0.6)
              : (entry.actual <= 0 && entry.inicial > 0
                  ? AppTheme.red.withOpacity(0.4)
                  : AppTheme.grey300),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                if (bajominimo) ...[
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    widget.insumo.nombre,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.brownDark),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: _MiniField(
              controller: _ctrl,
              label: 'Inicial',
              color: AppTheme.blue,
              onFocusLost: _saveInicial,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: _MiniField(
              controller: _minCtrl,
              label: 'Mínimo',
              color: Colors.orange.shade700,
              onFocusLost: _saveMin,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Text('${entry.vendidos}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.grey600)),
                const Text('vend.', style: TextStyle(fontSize: 10, color: AppTheme.grey600)),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Text(
                  '${entry.actual}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: stockColor),
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
  late TextEditingController _minCtrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.inicial.toString());
    _minCtrl = TextEditingController(
      text: (widget.state.stockMinimoProductos[widget.producto.id] ?? 0).toString(),
    );
  }

  @override
  void didUpdateWidget(_ProductoStockRow old) {
    super.didUpdateWidget(old);
    if (old.inicial != widget.inicial) {
      _ctrl.text = widget.inicial.toString();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  void _saveInicial() {
    final val = int.tryParse(_ctrl.text) ?? 0;
    widget.state.setStockInicialProducto(widget.producto.id, val);
    FocusScope.of(context).unfocus();
  }

  void _saveMin() {
    final val = int.tryParse(_minCtrl.text) ?? 0;
    widget.state.setStockMinimoProducto(widget.producto.id, val);
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
    final bajominimo = widget.state.stockProductoBajoMinimo(widget.producto.id);
    final stockColor = actual <= 0 && widget.inicial > 0
        ? AppTheme.red
        : bajominimo
            ? Colors.orange
            : _stockColor(actual, widget.inicial);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bajominimo ? const Color(0xFFFFF8E1) : AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: bajominimo
              ? Colors.orange.withOpacity(0.6)
              : (actual <= 0 && widget.inicial > 0
                  ? AppTheme.red.withOpacity(0.4)
                  : AppTheme.grey300),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                if (bajominimo) ...[
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    widget.producto.displayNombre,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.brownDark),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: _MiniField(
              controller: _ctrl,
              label: 'Inicial',
              color: AppTheme.blue,
              onFocusLost: _saveInicial,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: _MiniField(
              controller: _minCtrl,
              label: 'Mínimo',
              color: Colors.orange.shade700,
              onFocusLost: _saveMin,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Text('${widget.vendidos}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.grey600)),
                const Text('vend.', style: TextStyle(fontSize: 10, color: AppTheme.grey600)),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Text('$actual', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: stockColor)),
                const Text('quedan', style: TextStyle(fontSize: 10, color: AppTheme.grey600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
