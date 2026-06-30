import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/models.dart';
import '../services/printer_service.dart';
import '../theme.dart';

enum PrintState {
  idle,
  loadingDevices,
  selectingDevice,
  connecting,
  printing,
  done,
  error,
  permissionDenied,
}

class PrintDialog extends StatefulWidget {
  final Venta venta;

  /// Si [showSuccessBanner] es true, muestra el banner "¡Venta registrada!" (ventas).
  /// Si es false, va directo al flujo de impresión (historial).
  final bool showSuccessBanner;

  const PrintDialog({
    super.key,
    required this.venta,
    this.showSuccessBanner = true,
  });

  @override
  State<PrintDialog> createState() => _PrintDialogState();
}

class _PrintDialogState extends State<PrintDialog> {
  final _printer = PrinterService.instance;
  PrintState _state = PrintState.idle;
  List<BluetoothDevice> _devices = [];
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    if (!widget.showSuccessBanner) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onImprimir());
    }
  }

  Future<void> _onImprimir() async {
    final permStatus = await _printer.requestPermissions();
    if (permStatus == PermissionStatus.permanentlyDenied) {
      setState(() => _state = PrintState.permissionDenied);
      return;
    }
    if (permStatus == PermissionStatus.denied) {
      setState(() {
        _state = PrintState.error;
        _errorMsg = 'Se necesitan permisos de Bluetooth para imprimir.';
      });
      return;
    }
    if (await _printer.isConnected) {
      await _doPrint();
      return;
    }
    setState(() => _state = PrintState.loadingDevices);
    final devices = await _printer.getPairedDevices();
    if (devices.isEmpty) {
      setState(() {
        _state = PrintState.error;
        _errorMsg =
            'No hay impresoras vinculadas. Vinculá la impresora desde Ajustes > Bluetooth.';
      });
      return;
    }
    setState(() {
      _devices = devices;
      _state = PrintState.selectingDevice;
    });
  }

  Future<void> _connectAndPrint(BluetoothDevice device) async {
    setState(() => _state = PrintState.connecting);
    final connected = await _printer.connect(device);
    if (!connected) {
      setState(() {
        _state = PrintState.error;
        _errorMsg =
            'No se pudo conectar con "${device.name}". Verificá que esté encendida y cerca.';
      });
      return;
    }
    await _doPrint();
  }

  Future<void> _doPrint() async {
    setState(() => _state = PrintState.printing);
    try {
      await _printer.printTicket(widget.venta);
      setState(() => _state = PrintState.done);
    } catch (e) {
      setState(() {
        _state = PrintState.error;
        _errorMsg = 'Error al imprimir. Intentá de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: _buildContent(),
      actions: _buildActions(),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case PrintState.idle:
        return widget.showSuccessBanner ? _successContent() : _loadingContent('Iniciando...');
      case PrintState.loadingDevices:
        return _loadingContent('Buscando impresoras...');
      case PrintState.selectingDevice:
        return _deviceListContent();
      case PrintState.connecting:
        return _loadingContent('Conectando...');
      case PrintState.printing:
        return _loadingContent('Imprimiendo ticket...');
      case PrintState.done:
        return _doneContent();
      case PrintState.error:
        return _errorContent();
      case PrintState.permissionDenied:
        return _permissionDeniedContent();
    }
  }

  List<Widget>? _buildActions() {
    switch (_state) {
      case PrintState.idle:
        return widget.showSuccessBanner
            ? [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Continuar'),
                ),
                ElevatedButton.icon(
                  onPressed: _onImprimir,
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: const Text('Imprimir ticket'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.caramel,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ]
            : null;
      case PrintState.done:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ];
      case PrintState.error:
        return [
          TextButton(
            onPressed: () => setState(() => _state =
                widget.showSuccessBanner ? PrintState.idle : PrintState.loadingDevices),
            child: const Text('Reintentar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ];
      case PrintState.selectingDevice:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ];
      case PrintState.permissionDenied:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await _printer.openSettings();
              setState(() => _state = PrintState.idle);
            },
            icon: const Icon(Icons.settings_outlined, size: 16),
            label: const Text('Abrir Ajustes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.caramel,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ];
      default:
        return null;
    }
  }

  Widget _successContent() {
    final fmt =
        NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppTheme.green.withAlpha(30),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_outline,
              color: AppTheme.green, size: 32),
        ),
        const SizedBox(height: 16),
        const Text(
          '¡Nueva venta registrada!',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.brownDark),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          fmt.format(widget.venta.precioTotal + widget.venta.propina),
          style: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.green),
        ),
        const SizedBox(height: 4),
        Text(
          widget.venta.medioPago.label,
          style: const TextStyle(fontSize: 13, color: AppTheme.grey600),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _loadingContent(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppTheme.caramel),
            const SizedBox(height: 16),
            Text(msg,
                style:
                    const TextStyle(fontSize: 14, color: AppTheme.grey600)),
          ],
        ),
      );

  Widget _deviceListContent() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Seleccioná la impresora',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.brownDark)),
          const SizedBox(height: 12),
          ..._devices.map((d) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.print_outlined, color: AppTheme.caramel),
                title: Text(d.name ?? 'Sin nombre',
                    style: const TextStyle(fontSize: 14)),
                subtitle: Text(d.address ?? '',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.grey600)),
                onTap: () => _connectAndPrint(d),
              )),
        ],
      );

  Widget _doneContent() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.print_outlined, color: AppTheme.green, size: 40),
            SizedBox(height: 12),
            Text('¡Ticket impreso!',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.brownDark)),
          ],
        ),
      );

  Widget _errorContent() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.red, size: 36),
            const SizedBox(height: 12),
            Text(
              _errorMsg ?? 'Error desconocido.',
              style:
                  const TextStyle(fontSize: 13, color: AppTheme.grey600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _permissionDeniedContent() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bluetooth_disabled,
                color: AppTheme.caramel, size: 40),
            SizedBox(height: 12),
            Text(
              'Permisos de Bluetooth bloqueados',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.brownDark),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'La app no tiene permiso para usar Bluetooth. Habilitalo desde Ajustes > Aplicaciones > Café al Paso > Permisos.',
              style: TextStyle(fontSize: 13, color: AppTheme.grey600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}
