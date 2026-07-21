import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme.dart';

// ── Formateo ──────────────────────────────────────────────────────────────────

String _precio(int v) => '\$${NumberFormat('#,##0', 'es_AR').format(v)}';

// Formatea un teléfono mientras se tipea.
// Dígitos solamente; muestra: 11 → 11, 1123 → (11) 23, 1123456789 → (11) 2345-6789
// Con prefijo + o 0: lo respeta y aplica la máscara al resto.
class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text;
    // Separar prefijo (+54, +1, etc.) del cuerpo numérico
    String prefix = '';
    String digits = '';
    if (raw.startsWith('+')) {
      // tomar todo hasta primer espacio como prefijo si tiene más de 1 char
      final spaceIdx = raw.indexOf(' ', 1);
      if (spaceIdx != -1) {
        prefix = '${raw.substring(0, spaceIdx)} ';
        digits = raw.substring(spaceIdx + 1).replaceAll(RegExp(r'\D'), '');
      } else {
        // aún escribiendo el prefijo
        final digitsPart = raw.substring(1).replaceAll(RegExp(r'\D'), '');
        final formatted = '+$digitsPart';
        return newValue.copyWith(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    } else {
      digits = raw.replaceAll(RegExp(r'\D'), '');
    }

    String formatted;
    if (digits.length <= 2) {
      formatted = digits;
    } else if (digits.length <= 6) {
      formatted = '(${digits.substring(0, 2)}) ${digits.substring(2)}';
    } else if (digits.length <= 10) {
      final area = digits.substring(0, 2);
      final mid = digits.substring(2, 6);
      final end = digits.substring(6);
      formatted = '($area) $mid${end.isNotEmpty ? '-$end' : ''}';
    } else {
      // más de 10 dígitos: últimos 4 van después del guión, el resto en área
      final area = digits.substring(0, digits.length - 8);
      final mid = digits.substring(digits.length - 8, digits.length - 4);
      final end = digits.substring(digits.length - 4);
      formatted = '($area) $mid-$end';
    }

    final result = '$prefix$formatted';
    return newValue.copyWith(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ComprasScreen
// ─────────────────────────────────────────────────────────────────────────────

class ComprasScreen extends StatefulWidget {
  const ComprasScreen({super.key});

  @override
  State<ComprasScreen> createState() => _ComprasScreenState();
}

class _ComprasScreenState extends State<ComprasScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TabBar(selected: _tab, onTap: (i) => setState(() => _tab = i)),
        Expanded(
          child: _tab == 0 ? const _PedidosTab() : const _ProveedoresTab(),
        ),
      ],
    );
  }
}

// ── Tab bar ───────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  const _TabBar({required this.selected, required this.onTap});
  final int selected;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.white,
      child: Row(
        children: [
          _Tab(label: 'Pedidos', active: selected == 0, onTap: () => onTap(0)),
          _Tab(label: 'Proveedores', active: selected == 1, onTap: () => onTap(1)),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? AppTheme.brownMed : AppTheme.grey300,
                width: active ? 2.5 : 1,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color: active ? AppTheme.brownMed : AppTheme.grey600,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Proveedores tab
// ─────────────────────────────────────────────────────────────────────────────

class _ProveedoresTab extends StatelessWidget {
  const _ProveedoresTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Stack(
      children: [
        state.proveedores.isEmpty
            ? const Center(child: Text('No hay proveedores'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: state.proveedores.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) =>
                    _ProveedorCard(proveedor: state.proveedores[i]),
              ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'fab_prov',
            onPressed: () => _showProveedorDialog(context),
            backgroundColor: AppTheme.brownMed,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  void _showProveedorDialog(BuildContext context, [Proveedor? existing]) {
    final state = context.read<AppState>();
    final nombreCtrl = TextEditingController(text: existing?.nombre);
    final telCtrl = TextEditingController(text: existing?.telefono);
    final notasCtrl = TextEditingController(text: existing?.notas);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Nuevo proveedor' : 'Editar proveedor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre *'),
                textCapitalization: TextCapitalization.words,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telCtrl,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  prefixIcon: Icon(Icons.phone_outlined, size: 18),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [_PhoneFormatter()],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notasCtrl,
                decoration: const InputDecoration(labelText: 'Notas'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final nombre = nombreCtrl.text.trim();
              if (nombre.isEmpty) return;
              if (existing == null) {
                state.agregarProveedor(
                  nombre: nombre,
                  telefono: telCtrl.text.trim(),
                  notas: notasCtrl.text.trim(),
                );
              } else {
                state.editarProveedor(existing.id,
                    nombre: nombre,
                    telefono: telCtrl.text.trim(),
                    notas: notasCtrl.text.trim());
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

class _ProveedorCard extends StatelessWidget {
  const _ProveedorCard({required this.proveedor});
  final Proveedor proveedor;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final gasto = state.gastoConProveedor(proveedor.id);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(proveedor.nombre,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  if (proveedor.telefono.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.phone_outlined,
                              size: 13, color: AppTheme.grey600),
                          const SizedBox(width: 4),
                          Text(proveedor.telefono,
                              style: const TextStyle(
                                  color: AppTheme.grey600, fontSize: 13)),
                        ],
                      ),
                    ),
                  if (proveedor.notas.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(proveedor.notas,
                          style: const TextStyle(color: AppTheme.grey600, fontSize: 13)),
                    ),
                  if (gasto > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('Total comprado: ${_precio(gasto)}',
                          style: const TextStyle(
                              color: AppTheme.brownMed,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'editar') {
                  _showProveedorDialog(context, proveedor);
                } else if (v == 'eliminar') {
                  _confirmEliminar(context, proveedor);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'editar', child: Text('Editar')),
                const PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showProveedorDialog(BuildContext context, Proveedor existing) {
    final state = context.read<AppState>();
    final nombreCtrl = TextEditingController(text: existing.nombre);
    final telCtrl = TextEditingController(text: existing.telefono);
    final notasCtrl = TextEditingController(text: existing.notas);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar proveedor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre *'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telCtrl,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  prefixIcon: Icon(Icons.phone_outlined, size: 18),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [_PhoneFormatter()],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notasCtrl,
                decoration: const InputDecoration(labelText: 'Notas'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final nombre = nombreCtrl.text.trim();
              if (nombre.isEmpty) return;
              state.editarProveedor(existing.id,
                  nombre: nombre,
                  telefono: telCtrl.text.trim(),
                  notas: notasCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _confirmEliminar(BuildContext context, Proveedor p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar proveedor'),
        content: Text('¿Eliminar "${p.nombre}"? Los pedidos asociados quedarán sin proveedor.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              context.read<AppState>().eliminarProveedor(p.id);
              Navigator.pop(ctx);
            },
            child: const Text('Eliminar', style: TextStyle(color: AppTheme.red)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pedidos tab
// ─────────────────────────────────────────────────────────────────────────────

class _PedidosTab extends StatelessWidget {
  const _PedidosTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final deuda = state.totalDeudaPendiente;
    return Stack(
      children: [
        state.pedidos.isEmpty
            ? const Center(child: Text('No hay pedidos'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 76, 16, 80),
                itemCount: state.pedidos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) => _PedidoCard(pedido: state.pedidos[i]),
              ),
        // Banner deuda pendiente
        Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: deuda > 0 ? const Color(0xFFFFF3E0) : AppTheme.greenLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: deuda > 0 ? Colors.orange.shade300 : AppTheme.green.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Icon(
                    deuda > 0 ? Icons.account_balance_wallet_outlined : Icons.check_circle_outline,
                    color: deuda > 0 ? const Color(0xFFE65100) : AppTheme.green,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Pendiente de pago a proveedores:',
                    style: TextStyle(fontSize: 13, color: deuda > 0 ? const Color(0xFFE65100) : AppTheme.green),
                  ),
                  const Spacer(),
                  Text(
                    _precio(deuda),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: deuda > 0 ? const Color(0xFFE65100) : AppTheme.green),
                  ),
                ],
              ),
            ),
          ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'fab_ped',
            onPressed: () {
              if (state.proveedores.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Primero agregá un proveedor')),
                );
                return;
              }
              _showNuevoPedidoDialog(context, state);
            },
            backgroundColor: AppTheme.brownMed,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  void _showNuevoPedidoDialog(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (ctx) => _NuevoPedidoDialog(state: state),
    );
  }
}

// ── Pedido card ───────────────────────────────────────────────────────────────

class _PedidoCard extends StatefulWidget {
  const _PedidoCard({required this.pedido});
  final PedidoProveedor pedido;

  @override
  State<_PedidoCard> createState() => _PedidoCardState();
}

class _PedidoCardState extends State<_PedidoCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final pedido = widget.pedido;
    final fmt = DateFormat('dd/MM/yyyy', 'es');

    return Card(
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(pedido.proveedorNombre,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(width: 8),
                            _EstadoBadge(estado: pedido.estado),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: pedido.pagado ? AppTheme.greenLight : const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                pedido.pagado ? 'Pagado' : 'No pagado',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: pedido.pagado ? AppTheme.green : const Color(0xFFE65100),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(fmt.format(pedido.fecha),
                            style:
                                const TextStyle(color: AppTheme.grey600, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          '${pedido.items.length} ítem${pedido.items.length == 1 ? '' : 's'}  •  ${_precio(pedido.costoTotal)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppTheme.grey600),
                ],
              ),
            ),
          ),
          if (_expanded) _buildDetalle(context, pedido, pedido.estado == EstadoPedido.recibido),
        ],
      ),
    );
  }

  Widget _buildDetalle(
      BuildContext context, PedidoProveedor pedido, bool recibido) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm', 'es');
    final state = context.read<AppState>();
    final totalmenteRecibido = pedido.estado == EstadoPedido.recibido;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ítems con opción de recepción individual
              ...pedido.items.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final itemRecibido = pedido.itemsRecibidos.contains(i);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.nombre}  ×${item.cantidad}',
                              style: TextStyle(
                                fontSize: 14,
                                color: itemRecibido ? AppTheme.grey600 : AppTheme.brownDark,
                                decoration: itemRecibido ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            Text(
                              '${_precio(item.precioUnitario)} u.  =  ${_precio(item.subtotal)}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
                            ),
                          ],
                        ),
                      ),
                      if (!totalmenteRecibido)
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () async {
                            if (itemRecibido) {
                              await state.revertirItemPedido(pedido.id, i);
                            } else {
                              await state.recibirItemPedido(pedido.id, i);
                            }
                            if (context.mounted) setState(() {});
                          },
                          child: Text(
                            itemRecibido ? 'Revertir' : 'Recibir',
                            style: TextStyle(
                              fontSize: 12,
                              color: itemRecibido ? AppTheme.red : AppTheme.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (totalmenteRecibido)
                        const Icon(Icons.check_circle, size: 18, color: AppTheme.green),
                    ],
                  ),
                );
              }),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total pedido', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text(_precio(pedido.costoTotal), style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              if (pedido.notas.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Notas: ${pedido.notas}',
                    style: const TextStyle(color: AppTheme.grey600, fontSize: 13)),
              ],
              if (pedido.fechaRecepcion != null) ...[
                const SizedBox(height: 4),
                Text('Recibido: ${fmt.format(pedido.fechaRecepcion!)}',
                    style: const TextStyle(color: AppTheme.grey600, fontSize: 12)),
              ],
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: pedido.id));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ID copiado al portapapeles'), duration: Duration(seconds: 2)),
                  );
                },
                child: Row(
                  children: [
                    Text('ID: ${pedido.id}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.grey600, fontFamily: 'monospace')),
                    const SizedBox(width: 6),
                    const Icon(Icons.copy, size: 13, color: AppTheme.grey600),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (!totalmenteRecibido)
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Recibir todo'),
                        onPressed: () async {
                          await context.read<AppState>().marcarPedidoRecibido(pedido.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Stock actualizado')),
                            );
                          }
                        },
                      ),
                    ),
                  if (pedido.estado != EstadoPedido.pendiente)
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.undo, size: 18, color: AppTheme.brownMed),
                        label: const Text('Revertir todo',
                            style: TextStyle(color: AppTheme.brownMed)),
                        onPressed: () => _confirmRevertir(context, pedido),
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (pedido.estado == EstadoPedido.pendiente)
                    IconButton(
                      tooltip: 'Eliminar pedido',
                      icon: const Icon(Icons.delete_outline, color: AppTheme.red),
                      onPressed: () => _confirmEliminar(context, pedido),
                    ),
                ],
              ),
              // Botón pago (solo si hay algo recibido)
              if (pedido.estado != EstadoPedido.pendiente) ...[
                const SizedBox(height: 8),
                if (pedido.pagado && pedido.fechaPago != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Pagado el ${DateFormat('dd/MM/yyyy').format(pedido.fechaPago!)}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.green, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                SizedBox(
                  width: double.infinity,
                  child: pedido.pagado
                      ? OutlinedButton.icon(
                          icon: const Icon(Icons.money_off, size: 18, color: AppTheme.grey600),
                          label: const Text('Marcar como no pagado',
                              style: TextStyle(color: AppTheme.grey600)),
                          onPressed: () => context.read<AppState>().desmarcarPedidoPagado(pedido.id),
                        )
                      : ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.green),
                          icon: const Icon(Icons.attach_money, size: 18),
                          label: const Text('Marcar como pagado'),
                          onPressed: () => _marcarPagado(context, pedido),
                        ),
                ),
              ],
              Row(children: [
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _marcarPagado(BuildContext context, PedidoProveedor pedido) {
    DateTime fechaSeleccionada = DateTime.now();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: const Text('Fecha de pago'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: fechaSeleccionada,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    locale: const Locale('es'),
                  );
                  if (picked != null) setModal(() => fechaSeleccionada = picked);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.caramel),
                    borderRadius: BorderRadius.circular(10),
                    color: AppTheme.cream,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18, color: AppTheme.brownMed),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat('dd/MM/yyyy').format(fechaSeleccionada),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.brownDark),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.green),
              onPressed: () {
                context.read<AppState>().marcarPedidoPagado(pedido.id, fechaSeleccionada);
                Navigator.pop(ctx);
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRevertir(BuildContext context, PedidoProveedor pedido) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revertir recepción'),
        content: const Text(
            'Se descontará el stock ingresado al recibir este pedido. ¿Continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AppState>().revertirPedido(pedido.id);
            },
            child: const Text('Revertir',
                style: TextStyle(color: AppTheme.red)),
          ),
        ],
      ),
    );
  }

  void _confirmEliminar(BuildContext context, PedidoProveedor pedido) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar pedido'),
        content: const Text('¿Eliminar este pedido? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              context.read<AppState>().eliminarPedido(pedido.id);
              Navigator.pop(ctx);
            },
            child:
                const Text('Eliminar', style: TextStyle(color: AppTheme.red)),
          ),
        ],
      ),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  const _EstadoBadge({required this.estado});
  final EstadoPedido estado;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (estado) {
      EstadoPedido.recibido => ('Recibido', AppTheme.greenLight, AppTheme.green),
      EstadoPedido.parcial  => (
          'Parcial',
          const Color(0xFFFFF3E0),
          const Color(0xFFE65100),
        ),
      EstadoPedido.pendiente => (
          'Pendiente',
          AppTheme.orange,
          const Color(0xFFE65100),
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Diálogo nuevo pedido
// ─────────────────────────────────────────────────────────────────────────────

class _NuevoPedidoDialog extends StatefulWidget {
  const _NuevoPedidoDialog({required this.state});
  final AppState state;

  @override
  State<_NuevoPedidoDialog> createState() => _NuevoPedidoDialogState();
}

class _NuevoPedidoDialogState extends State<_NuevoPedidoDialog> {
  Proveedor? _proveedor;
  DateTime _fecha = DateTime.now();
  final _notasCtrl = TextEditingController();
  final List<_ItemRow> _items = [];

  int get _total => _items.fold(0, (s, r) => s + r.subtotal);

  void _addItem() {
    setState(() => _items.add(_ItemRow(state: widget.state)));
  }

  void _removeItem(int i) => setState(() => _items.removeAt(i));

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy', 'es');

    return AlertDialog(
      title: const Text('Nuevo pedido'),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Proveedor
              DropdownButtonFormField<Proveedor>(
                decoration: const InputDecoration(labelText: 'Proveedor *'),
                value: _proveedor,
                items: widget.state.proveedores
                    .map((p) =>
                        DropdownMenuItem(value: p, child: Text(p.nombre)))
                    .toList(),
                onChanged: (v) => setState(() => _proveedor = v),
              ),
              const SizedBox(height: 12),
              // Fecha
              InkWell(
                onTap: _pickFecha,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Fecha'),
                  child: Row(
                    children: [
                      Text(fmt.format(_fecha)),
                      const Spacer(),
                      const Icon(Icons.calendar_today, size: 18,
                          color: AppTheme.grey600),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Items
              const Text('Ítems', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ..._items.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ItemRowWidget(
                      row: e.value,
                      onRemove: () => _removeItem(e.key),
                      onChanged: () => setState(() {}),
                    ),
                  )),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Agregar ítem'),
                onPressed: _addItem,
              ),
              if (_items.isNotEmpty) ...[
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    Text(_precio(_total),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              // Notas
              TextField(
                controller: _notasCtrl,
                decoration: const InputDecoration(labelText: 'Notas'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _guardar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  Future<void> _pickFecha() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('es'),
    );
    if (d != null) setState(() => _fecha = d);
  }

  void _guardar() {
    if (_proveedor == null) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Agregá al menos un ítem')));
      return;
    }
    final itemsValidos = _items.where((r) => r.isValid).toList();
    if (itemsValidos.length != _items.length) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Completá todos los ítems')));
      return;
    }

    widget.state.agregarPedido(
      proveedorId: _proveedor!.id,
      proveedorNombre: _proveedor!.nombre,
      fecha: _fecha,
      items: itemsValidos.map((r) => r.toItemPedido()).toList(),
      notas: _notasCtrl.text.trim(),
    );
    Navigator.pop(context);
  }
}

// ── Fila de ítem (estado mutable del dialog) ──────────────────────────────────

class _ItemRow {
  TipoItemPedido tipo = TipoItemPedido.insumo;
  String? referenciaId;
  String nombre = '';
  int cantidad = 1;
  int precioUnitario = 0;
  final AppState state;

  _ItemRow({required this.state});

  bool get isValid => referenciaId != null && cantidad > 0 && precioUnitario > 0;

  int get subtotal => cantidad * precioUnitario;

  ItemPedido toItemPedido() => ItemPedido(
        tipo: tipo,
        referenciaId: referenciaId!,
        nombre: nombre,
        cantidad: cantidad,
        precioUnitario: precioUnitario,
      );
}

class _ItemRowWidget extends StatefulWidget {
  const _ItemRowWidget(
      {required this.row, required this.onRemove, required this.onChanged});
  final _ItemRow row;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  State<_ItemRowWidget> createState() => _ItemRowWidgetState();
}

class _ItemRowWidgetState extends State<_ItemRowWidget> {
  late TextEditingController _cantCtrl;
  late TextEditingController _precioCtrl;

  @override
  void initState() {
    super.initState();
    _cantCtrl = TextEditingController(
        text: widget.row.cantidad > 0 ? '${widget.row.cantidad}' : '');
    _precioCtrl = TextEditingController(
        text: widget.row.precioUnitario > 0
            ? '${widget.row.precioUnitario}'
            : '');
  }

  @override
  void dispose() {
    _cantCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  List<DropdownMenuItem<String>> _buildItems() {
    final row = widget.row;
    if (row.tipo == TipoItemPedido.insumo) {
      return row.state.insumos
          .map((i) => DropdownMenuItem(value: i.id, child: Text(i.nombre)))
          .toList();
    } else {
      return row.state.productos
          .map((p) => DropdownMenuItem(value: p.id, child: Text(p.nombre)))
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.grey300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<TipoItemPedido>(
                  segments: const [
                    ButtonSegment(
                        value: TipoItemPedido.insumo, label: Text('Insumo')),
                    ButtonSegment(
                        value: TipoItemPedido.producto, label: Text('Producto')),
                  ],
                  selected: {row.tipo},
                  onSelectionChanged: (s) => setState(() {
                    row.tipo = s.first;
                    row.referenciaId = null;
                    row.nombre = '';
                    widget.onChanged();
                  }),
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: AppTheme.brownMed,
                    selectedForegroundColor: Colors.white,
                  ),
                ),
              ),
              IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.red),
                  onPressed: widget.onRemove),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
                labelText: 'Seleccionar', isDense: true),
            value: row.referenciaId,
            isExpanded: true,
            items: _buildItems(),
            onChanged: (v) {
              setState(() {
                row.referenciaId = v;
                if (row.tipo == TipoItemPedido.insumo) {
                  row.nombre = row.state.insumos.firstWhere((i) => i.id == v).nombre;
                } else {
                  row.nombre = row.state.productos
                          .firstWhere((p) => p.id == v)
                          .nombre;
                }
                widget.onChanged();
              });
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cantCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Cantidad', isDense: true),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    row.cantidad = int.tryParse(v) ?? 0;
                    widget.onChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _precioCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Precio unitario', isDense: true),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    row.precioUnitario = int.tryParse(v) ?? 0;
                    widget.onChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _precio(row.subtotal),
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
