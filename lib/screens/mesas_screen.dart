import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import 'ventas_screen.dart' show SelectorPanel;
import '../widgets/print_dialog.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MESAS SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class MesasScreen extends StatefulWidget {
  const MesasScreen({super.key});

  @override
  State<MesasScreen> createState() => _MesasScreenState();
}

class _MesasScreenState extends State<MesasScreen> {
  bool _modoEdicion = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      body: Column(
        children: [
          // ── Barra de modo ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: _modoEdicion ? AppTheme.caramel.withValues(alpha: 0.12) : null,
            child: Row(
              children: [
                const Text('Salón',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.brownDark)),
                const Spacer(),
                if (_modoEdicion)
                  TextButton.icon(
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Forma'),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.caramel),
                    onPressed: () => _mostrarDialogoSalon(context, state),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Agregar mesa'),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.caramel),
                    onPressed: () => _mostrarDialogoMesa(context, state),
                  ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: _modoEdicion ? AppTheme.caramel : AppTheme.cream,
                    foregroundColor: _modoEdicion ? Colors.white : AppTheme.brownDark,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => setState(() => _modoEdicion = !_modoEdicion),
                  child: Text(_modoEdicion ? 'Listo' : 'Editar salón',
                      style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
          if (_modoEdicion)
            Container(
              width: double.infinity,
              color: AppTheme.caramel.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: const Text(
                'Arrastrá las mesas para reposicionarlas. Tocá una mesa para editarla.',
                style: TextStyle(fontSize: 12, color: AppTheme.grey600),
              ),
            ),
          // ── Canvas del salón ──────────────────────────────────────────────
          Expanded(
            child: state.mesas.isEmpty && !_modoEdicion
                ? _EmptySalon(onAgregar: () {
                    setState(() => _modoEdicion = true);
                    _mostrarDialogoMesa(context, state);
                  })
                : _SalonCanvas(
                    mesas: state.mesas,
                    cuentas: state.cuentasAbiertas,
                    config: state.salonConfig,
                    modoEdicion: _modoEdicion,
                    onTapMesa: (mesa) => _modoEdicion
                        ? _mostrarDialogoMesa(context, state, mesa: mesa)
                        : _abrirMesa(context, state, mesa),
                    onMoverMesa: (id, x, y) => state.actualizarPosicionMesa(id, x, y),
                  ),
          ),
        ],
      ),
    );
  }

  void _abrirMesa(BuildContext context, AppState state, Mesa mesa) {
    final cuenta = state.cuentaDe(mesa.id);
    if (cuenta == null) {
      _mostrarDialogoAbrirCuenta(context, state, mesa);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CuentaMesaScreen(mesa: mesa)),
      );
    }
  }

  void _mostrarDialogoAbrirCuenta(BuildContext context, AppState state, Mesa mesa) {
    int personas = 1;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Abrir ${mesa.nombre}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('¿Cuántas personas?',
                  style: TextStyle(fontSize: 14, color: AppTheme.grey600)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    color: AppTheme.caramel,
                    onPressed: personas > 1 ? () => setS(() => personas--) : null,
                  ),
                  const SizedBox(width: 8),
                  Text('$personas',
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.brownDark)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    color: AppTheme.caramel,
                    onPressed: () => setS(() => personas++),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.caramel),
              onPressed: () async {
                await state.abrirCuenta(mesa.id, personas);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CuentaMesaScreen(mesa: mesa)),
                  );
                }
              },
              child: const Text('Abrir mesa'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoSalon(BuildContext context, AppState state) {
    final cfg = state.salonConfig;
    SalonShape shape = cfg.shape;
    double aspectRatio = cfg.aspectRatio;
    double cutoutX = cfg.cutoutX;
    double cutoutY = cfg.cutoutY;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Forma del salón'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Preview — respeta el aspect ratio configurado
                _SalonPreview(
                  shape: shape,
                  aspectRatio: aspectRatio,
                  cutoutX: cutoutX,
                  cutoutY: cutoutY,
                ),
                const SizedBox(height: 16),

                // Forma
                const Text('Forma', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.grey600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: SalonShape.values.map((s) => ChoiceChip(
                    label: Text(s.label),
                    selected: shape == s,
                    onSelected: (_) => setS(() => shape = s),
                    selectedColor: AppTheme.caramel,
                    labelStyle: TextStyle(
                      color: shape == s ? Colors.white : AppTheme.brownDark,
                      fontSize: 13,
                    ),
                  )).toList(),
                ),

                const SizedBox(height: 16),
                // Proporción del salón
                const Text('Proporción del espacio', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.grey600)),
                Row(
                  children: [
                    const Text('Cuadrado', style: TextStyle(fontSize: 12, color: AppTheme.grey600)),
                    Expanded(
                      child: Slider(
                        value: aspectRatio.clamp(0.6, 2.5),
                        min: 0.6,
                        max: 2.5,
                        divisions: 19,
                        activeColor: AppTheme.caramel,
                        onChanged: (v) => setS(() => aspectRatio = v),
                      ),
                    ),
                    const Text('Ancho', style: TextStyle(fontSize: 12, color: AppTheme.grey600)),
                  ],
                ),

                // Recorte (solo para L y U)
                if (shape != SalonShape.rectangulo) ...[
                  const SizedBox(height: 8),
                  Text(
                    shape == SalonShape.L ? 'Tamaño del recorte (ancho)' : 'Ancho del pasillo central',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.grey600),
                  ),
                  Slider(
                    value: cutoutX.clamp(0.2, 0.8),
                    min: 0.2,
                    max: 0.8,
                    divisions: 12,
                    activeColor: AppTheme.caramel,
                    onChanged: (v) => setS(() => cutoutX = v),
                  ),
                  const Text('Profundidad del recorte', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.grey600)),
                  Slider(
                    value: cutoutY.clamp(0.2, 0.8),
                    min: 0.2,
                    max: 0.8,
                    divisions: 12,
                    activeColor: AppTheme.caramel,
                    onChanged: (v) => setS(() => cutoutY = v),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.caramel),
              onPressed: () {
                state.guardarSalonConfig(SalonConfig(
                  shape: shape,
                  aspectRatio: aspectRatio,
                  cutoutX: cutoutX,
                  cutoutY: cutoutY,
                ));
                Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoMesa(BuildContext context, AppState state, {Mesa? mesa}) {
    final nombreCtrl = TextEditingController(text: mesa?.nombre ?? '');
    int capacidad = mesa?.capacidad ?? 4;
    MesaForma forma = mesa?.forma ?? MesaForma.circulo;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(mesa == null ? 'Nueva mesa' : 'Editar ${mesa.nombre}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Mesa 1, Barra...'),
                autofocus: true,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              const Text('Capacidad', style: TextStyle(fontSize: 13, color: AppTheme.grey600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    color: AppTheme.caramel,
                    onPressed: capacidad > 1 ? () => setS(() => capacidad--) : null,
                  ),
                  Text('$capacidad personas',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    color: AppTheme.caramel,
                    onPressed: () => setS(() => capacidad++),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Forma', style: TextStyle(fontSize: 13, color: AppTheme.grey600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: MesaForma.values.map((f) => ChoiceChip(
                  label: Text(f.label),
                  selected: forma == f,
                  onSelected: (_) => setS(() => forma = f),
                  selectedColor: AppTheme.caramel,
                  labelStyle: TextStyle(
                    color: forma == f ? Colors.white : AppTheme.brownDark,
                    fontSize: 13,
                  ),
                )).toList(),
              ),
            ],
          ),
          actions: [
            if (mesa != null)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppTheme.red),
                onPressed: () {
                  state.eliminarMesa(mesa.id);
                  Navigator.pop(ctx);
                },
                child: const Text('Eliminar'),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.caramel),
              onPressed: () {
                final nombre = nombreCtrl.text.trim();
                if (nombre.isEmpty) return;
                if (mesa == null) {
                  state.agregarMesa(Mesa(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    nombre: nombre,
                    capacidad: capacidad,
                    forma: forma,
                    x: 0.3 + (state.mesas.length * 0.1 % 0.4),
                    y: 0.3 + (state.mesas.length * 0.08 % 0.4),
                  ));
                } else {
                  state.editarMesa(Mesa(
                    id: mesa.id,
                    nombre: nombre,
                    capacidad: capacidad,
                    forma: forma,
                    x: mesa.x,
                    y: mesa.y,
                  ));
                }
                Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Canvas del salón ─────────────────────────────────────────────────────────

class _SalonCanvas extends StatefulWidget {
  final List<Mesa> mesas;
  final Map<String, CuentaMesa> cuentas;
  final SalonConfig config;
  final bool modoEdicion;
  final void Function(Mesa) onTapMesa;
  final void Function(String id, double x, double y) onMoverMesa;

  const _SalonCanvas({
    required this.mesas,
    required this.cuentas,
    required this.config,
    required this.modoEdicion,
    required this.onTapMesa,
    required this.onMoverMesa,
  });

  @override
  State<_SalonCanvas> createState() => _SalonCanvasState();
}

class _SalonCanvasState extends State<_SalonCanvas> {
  String? _dragId;       // id de la mesa que se está arrastrando
  Offset? _dragCenter;   // posición actual del centro (en coordenadas del canvas)
  double _cw = 0;
  double _ch = 0;

  static const _size = 72.0;
  static const _rectW = _size * 1.5;
  static const _rectH = _size * 0.75;

  double _iconW(Mesa m) => m.forma == MesaForma.rectangulo ? _rectW : _size;
  double _iconH(Mesa m) => m.forma == MesaForma.rectangulo ? _rectH : _size;

  // Devuelve la mesa cuyo bounding box contiene `pos` (coordenadas del canvas)
  Mesa? _mesaEn(Offset pos) {
    // Iteramos en orden inverso (la última pintada está encima)
    for (final m in widget.mesas.reversed) {
      final cx = m.x * _cw;
      final cy = m.y * _ch;
      final hw = _iconW(m) / 2;
      final hh = _iconH(m) / 2;
      if (pos.dx >= cx - hw && pos.dx <= cx + hw &&
          pos.dy >= cy - hh && pos.dy <= cy + hh) {
        return m;
      }
    }
    return null;
  }

  void _onPanStart(DragStartDetails d) {
    if (!widget.modoEdicion) return;
    final mesa = _mesaEn(d.localPosition);
    if (mesa == null) return;
    setState(() {
      _dragId = mesa.id;
      _dragCenter = Offset(mesa.x * _cw, mesa.y * _ch);
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_dragId == null) return;
    setState(() {
      _dragCenter = Offset(
        (_dragCenter!.dx + d.delta.dx).clamp(0.0, _cw),
        (_dragCenter!.dy + d.delta.dy).clamp(0.0, _ch),
      );
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (_dragId == null || _dragCenter == null) return;
    final id = _dragId!;
    final nx = (_dragCenter!.dx / _cw).clamp(0.05, 0.95);
    final ny = (_dragCenter!.dy / _ch).clamp(0.05, 0.95);
    setState(() { _dragId = null; _dragCenter = null; });
    widget.onMoverMesa(id, nx, ny);
  }

  void _onTapUp(TapUpDetails d) {
    if (widget.modoEdicion) return;
    final mesa = _mesaEn(d.localPosition);
    if (mesa != null) widget.onTapMesa(mesa);
  }

  void _onTapUpEdit(TapUpDetails d) {
    if (!widget.modoEdicion) return;
    // Tap corto en modo edición → abrir diálogo de mesa
    if (_dragId != null) return; // fue un drag, no un tap
    final mesa = _mesaEn(d.localPosition);
    if (mesa != null) widget.onTapMesa(mesa);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.biggest;
        if (available.width / available.height > widget.config.aspectRatio) {
          _ch = available.height;
          _cw = _ch * widget.config.aspectRatio;
        } else {
          _cw = available.width;
          _ch = _cw / widget.config.aspectRatio;
        }

        return Container(
          color: const Color(0xFFD6C9B8),
          alignment: Alignment.center,
          child: GestureDetector(
            onPanStart: widget.modoEdicion ? _onPanStart : null,
            onPanUpdate: widget.modoEdicion ? _onPanUpdate : null,
            onPanEnd: widget.modoEdicion ? _onPanEnd : null,
            onTapUp: widget.modoEdicion ? _onTapUpEdit : _onTapUp,
            child: SizedBox(
              width: _cw,
              height: _ch,
              child: Stack(
                children: [
                  CustomPaint(
                    size: Size(_cw, _ch),
                    painter: _SalonPainter(config: widget.config),
                  ),
                  ...widget.mesas.map((mesa) {
                    final cuenta = widget.cuentas[mesa.id];
                    final isDragging = _dragId == mesa.id;
                    final cx = isDragging ? _dragCenter!.dx : mesa.x * _cw;
                    final cy = isDragging ? _dragCenter!.dy : mesa.y * _ch;
                    return _MesaWidget(
                      key: ValueKey(mesa.id),
                      mesa: mesa,
                      cuenta: cuenta,
                      cx: cx,
                      cy: cy,
                      isDragging: isDragging,
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Preview del salón ────────────────────────────────────────────────────────

class _SalonPreview extends StatelessWidget {
  final SalonShape shape;
  final double aspectRatio;
  final double cutoutX;
  final double cutoutY;

  const _SalonPreview({
    required this.shape,
    required this.aspectRatio,
    required this.cutoutX,
    required this.cutoutY,
  });

  @override
  Widget build(BuildContext context) {
    const maxW = 220.0;
    const maxH = 140.0;
    double pw, ph;
    if (aspectRatio > maxW / maxH) {
      pw = maxW;
      ph = maxW / aspectRatio;
    } else {
      ph = maxH;
      pw = maxH * aspectRatio;
    }
    final cfg = SalonConfig(
        shape: shape, aspectRatio: aspectRatio, cutoutX: cutoutX, cutoutY: cutoutY);
    return Center(
      child: Container(
        width: maxW,
        height: maxH,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFD6C9B8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: CustomPaint(
          size: Size(pw, ph),
          painter: _SalonPainter(config: cfg),
        ),
      ),
    );
  }
}

Path _buildSalonPath(SalonConfig config, double w, double h) {
  final path = Path();
  switch (config.shape) {
    case SalonShape.rectangulo:
      path.addRect(Rect.fromLTWH(0, 0, w, h));
    case SalonShape.L:
      final cx = w * config.cutoutX;
      final cy = h * config.cutoutY;
      path
        ..moveTo(0, 0)
        ..lineTo(cx, 0)
        ..lineTo(cx, cy)
        ..lineTo(w, cy)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
    case SalonShape.U:
      final left = w * (0.5 - config.cutoutX / 2);
      final right = w * (0.5 + config.cutoutX / 2);
      final cy = h * config.cutoutY;
      path
        ..moveTo(0, 0)
        ..lineTo(left, 0)
        ..lineTo(left, cy)
        ..lineTo(right, cy)
        ..lineTo(right, 0)
        ..lineTo(w, 0)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
  }
  return path;
}

class _SalonPainter extends CustomPainter {
  final SalonConfig config;
  const _SalonPainter({required this.config});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = _buildSalonPath(config, w, h);

    // Relleno del salón
    canvas.drawPath(path, Paint()..color = const Color(0xFFF5EFE6));

    // Grid interno (solo dentro de la forma)
    canvas.save();
    canvas.clipPath(path);
    final gridPaint = Paint()
      ..color = const Color(0xFFD6C9B8).withValues(alpha: 0.6)
      ..strokeWidth = 0.5;
    const step = 40.0;
    for (double x = 0; x < w; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }
    for (double y = 0; y < h; y += step) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }
    canvas.restore();

    // Borde del salón
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFB8A898)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_SalonPainter old) =>
      old.config.shape != config.shape ||
      old.config.cutoutX != config.cutoutX ||
      old.config.cutoutY != config.cutoutY;
}

// _MesaWidget solo se encarga del render — los gestos los maneja _SalonCanvas
class _MesaWidget extends StatelessWidget {
  final Mesa mesa;
  final CuentaMesa? cuenta;
  final double cx; // centro x en el canvas
  final double cy; // centro y en el canvas
  final bool isDragging;

  const _MesaWidget({
    super.key,
    required this.mesa,
    required this.cuenta,
    required this.cx,
    required this.cy,
    this.isDragging = false,
  });

  static const _size = 72.0;
  static const _rectW = _size * 1.5;
  static const _rectH = _size * 0.75;

  Color get _color {
    if (cuenta == null) return const Color(0xFF6BCB77);
    if (cuenta!.estado == EstadoCuenta.esperandoCuenta) return const Color(0xFFE05252);
    return const Color(0xFFF4A261);
  }

  double get _iconW => mesa.forma == MesaForma.rectangulo ? _rectW : _size;
  double get _iconH => mesa.forma == MesaForma.rectangulo ? _rectH : _size;

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final left = cx - _iconW / 2;
    final top = cy - _iconH / 2;

    return Positioned(
      left: left,
      top: top,
      child: Opacity(
        opacity: isDragging ? 0.85 : 1.0,
        child: Container(
          width: _iconW,
          height: _iconH,
          decoration: BoxDecoration(
            color: color,
            shape: mesa.forma == MesaForma.circulo ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: mesa.forma == MesaForma.cuadrado
                ? BorderRadius.circular(12)
                : mesa.forma == MesaForma.rectangulo
                    ? BorderRadius.circular(6)
                    : null,
            boxShadow: isDragging
                ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 16, offset: const Offset(0, 6))]
                : [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(mesa.nombre,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 2),
              Text(
                cuenta != null
                    ? _formatDuracion(DateTime.now().difference(cuenta!.apertura))
                    : '${mesa.capacidad} 🪑',
                style: const TextStyle(fontSize: 10, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuracion(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes}min';
    return '${d.inHours}h ${d.inMinutes.remainder(60)}min';
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptySalon extends StatelessWidget {
  final VoidCallback onAgregar;
  const _EmptySalon({required this.onAgregar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.table_restaurant_outlined, size: 64, color: AppTheme.grey300),
          const SizedBox(height: 16),
          const Text('No hay mesas configuradas',
              style: TextStyle(fontSize: 16, color: AppTheme.grey600)),
          const SizedBox(height: 8),
          const Text('Activá "Editar salón" para agregar mesas',
              style: TextStyle(fontSize: 13, color: AppTheme.grey600)),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Agregar primera mesa'),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.caramel),
            onPressed: onAgregar,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CUENTA MESA SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class CuentaMesaScreen extends StatefulWidget {
  final Mesa mesa;
  const CuentaMesaScreen({super.key, required this.mesa});

  @override
  State<CuentaMesaScreen> createState() => _CuentaMesaScreenState();
}

class _CuentaMesaScreenState extends State<CuentaMesaScreen> {
  bool _mostrandoSelector = false;
  final _moneda = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cuenta = state.cuentaDe(widget.mesa.id);
    if (cuenta == null) return const SizedBox.shrink();

    final duracion = DateTime.now().difference(cuenta.apertura);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mesa.nombre),
        actions: [
          // Indicador de tiempo
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                _formatDuracion(duracion),
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Estado de la cuenta ──────────────────────────────────────────
          if (cuenta.estado == EstadoCuenta.esperandoCuenta)
            Container(
              width: double.infinity,
              color: const Color(0xFFE05252),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: const Row(
                children: [
                  Icon(Icons.notifications_active, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('La mesa pidió la cuenta',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
            ),

          // ── Info personas ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.grey300)),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_outline, size: 18, color: AppTheme.grey600),
                const SizedBox(width: 6),
                Text('${cuenta.cantidadPersonas} persona${cuenta.cantidadPersonas > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 13, color: AppTheme.grey600)),
                const Spacer(),
                Text('Abierta: ${DateFormat('HH:mm').format(cuenta.apertura)}',
                    style: const TextStyle(fontSize: 13, color: AppTheme.grey600)),
              ],
            ),
          ),

          // ── Lista de ítems ────────────────────────────────────────────────
          Expanded(
            child: cuenta.items.isEmpty
                ? const Center(
                    child: Text('No hay productos en la cuenta',
                        style: TextStyle(color: AppTheme.grey600)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: cuenta.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (ctx, i) {
                      final item = cuenta.items[i];
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
                              child: Text(
                                item.nombreConOpcion +
                                    (item.cafesAdicionales > 0
                                        ? ' +${item.cafesAdicionales} café${item.cafesAdicionales > 1 ? 's' : ''}'
                                        : '') +
                                    (item.cantidad > 1 ? ' ×${item.cantidad}' : ''),
                                style: const TextStyle(fontSize: 14, color: AppTheme.brownDark),
                              ),
                            ),
                            Text(
                              _moneda.format(item.precioUnitario * item.cantidad),
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.brownDark),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => state.quitarItemDeCuenta(widget.mesa.id, i),
                              child: const Icon(Icons.close, size: 18, color: AppTheme.grey600),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // ── Selector de productos (expandible) ────────────────────────────
          if (_mostrandoSelector)
            Container(
              height: 380,
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.grey300)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: AppTheme.cream,
                    child: Row(
                      children: [
                        const Text('Agregar productos',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.brownDark)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => setState(() => _mostrandoSelector = false),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: SelectorPanel(
                        state: state,
                        enCarrito: cuenta.items,
                        onAgregar: (item) async {
                          await state.agregarItemACuenta(widget.mesa.id, item);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Barra de acciones ─────────────────────────────────────────────
          _BarraAcciones(
            cuenta: cuenta,
            mesa: widget.mesa,
            total: cuenta.total,
            moneda: _moneda,
            mostrandoSelector: _mostrandoSelector,
            onAgregar: () => setState(() => _mostrandoSelector = !_mostrandoSelector),
            onPedirCuenta: () => _pedirCuentaEImprimir(context, state, cuenta),
            onCancelar: () => _confirmarCancelar(context, state),
            onCobrar: () => _mostrarDialogoCobrar(context, state, cuenta),
          ),
        ],
      ),
    );
  }

  String _formatDuracion(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    return '${d.inHours}h ${d.inMinutes.remainder(60)}min';
  }

  void _pedirCuentaEImprimir(BuildContext context, AppState state, CuentaMesa cuenta) {
    state.pedirCuenta(widget.mesa.id);
    final ventaTemp = Venta(
      id: 'temp_${widget.mesa.id}',
      items: List.from(cuenta.items),
      precioTotal: cuenta.total,
      pagos: [Pago(medioPago: MedioPago.efectivo, monto: cuenta.total)],
      timestamp: DateTime.now(),
      mesaNombre: widget.mesa.nombre,
    );
    showDialog(
      context: context,
      builder: (ctx) => PrintDialog(venta: ventaTemp, showSuccessBanner: false),
    );
  }

  void _confirmarCancelar(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar cuenta'),
        content: const Text('¿Cerrar la cuenta sin cobrar? Los productos no se descontarán del stock.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Volver')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.red),
            onPressed: () async {
              await state.cancelarCuenta(widget.mesa.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Cancelar cuenta'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoCobrar(BuildContext context, AppState state, CuentaMesa cuenta) {
    showDialog(
      context: context,
      builder: (ctx) => _DialogoCobrar(
        cuenta: cuenta,
        mesa: widget.mesa,
        onCobrar: (pagos, propina, propinaMP) async {
          await state.cobrarCuenta(
            mesaId: widget.mesa.id,
            pagos: pagos,
            propina: propina,
            propinaMedioPago: propinaMP,
          );
          if (ctx.mounted) Navigator.pop(ctx);
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }
}

// ─── Barra de acciones ────────────────────────────────────────────────────────

class _BarraAcciones extends StatelessWidget {
  final CuentaMesa cuenta;
  final Mesa mesa;
  final int total;
  final NumberFormat moneda;
  final bool mostrandoSelector;
  final VoidCallback onAgregar;
  final VoidCallback onPedirCuenta;
  final VoidCallback onCancelar;
  final VoidCallback onCobrar;

  const _BarraAcciones({
    required this.cuenta,
    required this.mesa,
    required this.total,
    required this.moneda,
    required this.mostrandoSelector,
    required this.onAgregar,
    required this.onPedirCuenta,
    required this.onCancelar,
    required this.onCobrar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.white,
        border: Border(top: BorderSide(color: AppTheme.grey300)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Total
          Row(
            children: [
              const Text('Total', style: TextStyle(fontSize: 15, color: AppTheme.grey600)),
              const Spacer(),
              Text(
                moneda.format(total),
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.brownDark),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Botones
          Row(
            children: [
              // Cancelar
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.red,
                  side: const BorderSide(color: AppTheme.red),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onCancelar,
                child: const Text('Cancelar', style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 8),
              // Agregar
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.caramel,
                  side: const BorderSide(color: AppTheme.caramel),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(mostrandoSelector ? Icons.keyboard_arrow_down : Icons.add, size: 16),
                label: const Text('Agregar', style: TextStyle(fontSize: 13)),
                onPressed: onAgregar,
              ),
              const SizedBox(width: 8),
              // Pedir cuenta (solo si no lo pidió)
              if (cuenta.estado == EstadoCuenta.abierta)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.brownDark,
                    side: const BorderSide(color: AppTheme.grey300),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: cuenta.items.isEmpty ? null : onPedirCuenta,
                  child: const Text('Pedir cuenta', style: TextStyle(fontSize: 13)),
                ),
              const Spacer(),
              // Cobrar
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.green,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: cuenta.items.isEmpty ? null : onCobrar,
                child: const Text('Cobrar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Diálogo cobrar ───────────────────────────────────────────────────────────

class _DialogoCobrar extends StatefulWidget {
  final CuentaMesa cuenta;
  final Mesa mesa;
  final Future<void> Function(List<Pago> pagos, int propina, MedioPago? propinaMedioPago) onCobrar;

  const _DialogoCobrar({required this.cuenta, required this.mesa, required this.onCobrar});

  @override
  State<_DialogoCobrar> createState() => _DialogoCobrarState();
}

class _DialogoCobrarState extends State<_DialogoCobrar> {
  // Lista de pagos: cada entrada es (monto editable, medio de pago)
  final List<_PagoEntry> _pagos = [];
  int _propina = 0;
  MedioPago _propinaMedio = MedioPago.efectivo;
  bool _conPropina = false;
  final _moneda = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);

  int get _total => widget.cuenta.total;
  int get _sumaPagos => _pagos.fold(0, (s, p) => s + p.monto);
  int get _restante => _total - _sumaPagos;

  @override
  void initState() {
    super.initState();
    // Por defecto: un pago por el total en efectivo
    _pagos.add(_PagoEntry(monto: _total, medioPago: MedioPago.efectivo));
  }

  void _agregarPago() {
    setState(() {
      _pagos.add(_PagoEntry(monto: _restante.clamp(0, _total), medioPago: MedioPago.transferencia));
    });
  }

  bool get _valido => _sumaPagos == _total && _pagos.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Cobrar · ${widget.mesa.nombre}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cream,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Text('Total a cobrar',
                      style: TextStyle(fontSize: 14, color: AppTheme.grey600)),
                  const Spacer(),
                  Text(_moneda.format(_total),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.brownDark)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Pagos
            const Text('Forma de pago',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.grey600)),
            const SizedBox(height: 8),
            ..._pagos.asMap().entries.map((e) => _PagoRow(
                  entry: e.value,
                  index: e.key,
                  canDelete: _pagos.length > 1,
                  totalRestante: _total,
                  onDelete: () => setState(() => _pagos.removeAt(e.key)),
                  onChanged: () => setState(() {}),
                )),

            // Botón agregar pago
            if (_sumaPagos < _total)
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Dividir pago', style: TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(foregroundColor: AppTheme.caramel),
                onPressed: _agregarPago,
              ),

            // Aviso diferencia
            if (_sumaPagos != _total && _pagos.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _restante > 0
                    ? 'Faltan ${_moneda.format(_restante)}'
                    : 'Excede en ${_moneda.format(-_restante)}',
                style: TextStyle(
                    fontSize: 12,
                    color: _restante > 0 ? AppTheme.red : AppTheme.caramel),
              ),
            ],

            const SizedBox(height: 16),
            // Propina
            Row(
              children: [
                Checkbox(
                  value: _conPropina,
                  onChanged: (v) => setState(() {
                    _conPropina = v ?? false;
                    if (!_conPropina) _propina = 0;
                  }),
                  activeColor: AppTheme.caramel,
                ),
                const Text('Propina', style: TextStyle(fontSize: 14)),
              ],
            ),
            if (_conPropina) ...[
              Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Monto propina', prefixText: '\$ '),
                      onChanged: (v) => setState(() => _propina = int.tryParse(v) ?? 0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<MedioPago>(
                    value: _propinaMedio,
                    items: MedioPago.values
                        .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                        .toList(),
                    onChanged: (m) => setState(() => _propinaMedio = m!),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _valido ? AppTheme.green : AppTheme.grey300,
          ),
          onPressed: _valido
              ? () => widget.onCobrar(
                    _pagos.map((p) => Pago(medioPago: p.medioPago, monto: p.monto)).toList(),
                    _propina,
                    _conPropina ? _propinaMedio : null,
                  )
              : null,
          child: const Text('Confirmar cobro'),
        ),
      ],
    );
  }
}

class _PagoEntry {
  int monto;
  MedioPago medioPago;
  _PagoEntry({required this.monto, required this.medioPago});
}

class _PagoRow extends StatefulWidget {
  final _PagoEntry entry;
  final int index;
  final bool canDelete;
  final int totalRestante;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const _PagoRow({
    required this.entry,
    required this.index,
    required this.canDelete,
    required this.totalRestante,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<_PagoRow> createState() => _PagoRowState();
}

class _PagoRowState extends State<_PagoRow> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.entry.monto.toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // Monto
          Expanded(
            child: TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(prefixText: '\$ ', isDense: true),
              onChanged: (v) {
                widget.entry.monto = int.tryParse(v) ?? 0;
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(width: 10),
          // Medio de pago
          DropdownButton<MedioPago>(
            value: widget.entry.medioPago,
            isDense: true,
            items: MedioPago.values
                .map((m) => DropdownMenuItem(
                    value: m,
                    child: Row(children: [
                      Text(m.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 4),
                      Text(m.label, style: const TextStyle(fontSize: 13)),
                    ])))
                .toList(),
            onChanged: (m) {
              setState(() => widget.entry.medioPago = m!);
              widget.onChanged();
            },
          ),
          if (widget.canDelete) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: AppTheme.grey600,
              onPressed: widget.onDelete,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Extensiones de modelo usadas localmente ──────────────────────────────────

extension on MesaForma {
  String get label {
    switch (this) {
      case MesaForma.circulo: return 'Círculo';
      case MesaForma.cuadrado: return 'Cuadrado';
      case MesaForma.rectangulo: return 'Rectángulo';
    }
  }
}
