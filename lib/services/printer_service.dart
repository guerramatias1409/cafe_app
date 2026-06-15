import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/models.dart';

class PrinterService {
  PrinterService._();
  static final PrinterService instance = PrinterService._();

  final BlueThermalPrinter _bt = BlueThermalPrinter.instance;

  // ── Permisos ───────────────────────────────────────────────────────────────

  /// Retorna `granted`, `denied` o `permanentlyDenied`
  Future<PermissionStatus> requestPermissions() async {
    final perms = [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ];
    final results = await perms.request();
    final statuses = results.values.toList();
    if (statuses.any((s) => s == PermissionStatus.permanentlyDenied)) {
      return PermissionStatus.permanentlyDenied;
    }
    if (statuses.every(
        (s) => s == PermissionStatus.granted || s == PermissionStatus.limited)) {
      return PermissionStatus.granted;
    }
    return PermissionStatus.denied;
  }

  Future<void> openSettings() => openAppSettings();

  // ── Dispositivos ───────────────────────────────────────────────────────────

  Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      return await _bt.getBondedDevices();
    } catch (_) {
      return [];
    }
  }

  Future<bool> connect(BluetoothDevice device) async {
    try {
      await _bt.connect(device);
      return await _bt.isConnected ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _bt.disconnect();
    } catch (_) {}
  }

  Future<bool> get isConnected async => await _bt.isConnected ?? false;

  // ── Impresión ──────────────────────────────────────────────────────────────

  /// Imprime nombre y precio en una sola línea de 32 chars.
  /// Si el nombre no entra, lo trunca con "..." dejando espacio para el precio.
  Future<void> _printItem(String nombre, String precio, {int size = 1}) async {
    const lineWidth = 32;
    // Espacio mínimo: "... $XXXX" → al menos 1 char de nombre + "... " + precio
    final maxNombre = lineWidth - precio.length - 1; // 1 espacio de separación
    final displayNombre = nombre.length <= maxNombre
        ? nombre.padRight(maxNombre)
        : '${nombre.substring(0, maxNombre - 4)}... ';
    await _bt.printCustom('$displayNombre$precio', size, 0);
  }

  /// Elimina tildes y caracteres especiales no soportados por la impresora
  String _normalizar(String s) => s
      .replaceAll('á', 'a').replaceAll('Á', 'A')
      .replaceAll('é', 'e').replaceAll('É', 'E')
      .replaceAll('í', 'i').replaceAll('Í', 'I')
      .replaceAll('ó', 'o').replaceAll('Ó', 'O')
      .replaceAll('ú', 'u').replaceAll('Ú', 'U')
      .replaceAll('ü', 'u').replaceAll('Ü', 'U')
      .replaceAll('ñ', 'n').replaceAll('Ñ', 'N');

  /// Formatea un precio como $1.234
  String _precio(int v) =>
      '\$${NumberFormat('#,##0', 'es_AR').format(v)}';

  Future<void> printTicket(Venta venta) async {
    final fechaFmt = DateFormat('dd/MM/yyyy');
    final horaFmt = DateFormat('HH:mm');

    // Encabezado
    await _bt.printCustom('PerBast Cafe', 2, 1);
    await _bt.printNewLine();
    await _bt.printCustom('${fechaFmt.format(venta.timestamp)}   ${horaFmt.format(venta.timestamp)}', 1, 1);
    await _bt.printCustom('--------------------------------', 1, 1);
    await _bt.printNewLine();

    // Ítems
    for (final item in venta.items) {
      final nombre = _normalizar(item.cantidad > 1
          ? '${item.comboNombre} x${item.cantidad}'
          : item.comboNombre);
      await _printItem(nombre, _precio(item.precioTotal));
    }

    await _bt.printNewLine();
    await _bt.printCustom('--------------------------------', 1, 1);

    // Total (sin propina)
    await _printItem('TOTAL', _precio(venta.precioTotal), size: 2);
    await _bt.printCustom('--------------------------------', 1, 1);
    await _bt.printNewLine();

    // Medio de pago
    await _printItem('Medio de pago', _normalizar(venta.medioPago.label));
    await _bt.printNewLine();

    // Pie
    await _bt.printCustom('Gracias por tu visita!', 1, 1);
    await _bt.printNewLine();
    await _bt.printNewLine();
    await _bt.printNewLine();
    await _bt.paperCut();
  }
}
