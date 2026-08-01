import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> descargarCsv(String contenido, String nombreArchivo) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$nombreArchivo');
  await file.writeAsString(contenido);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'text/csv')],
    subject: 'Reporte de ventas – Café al Paso',
  );
}
