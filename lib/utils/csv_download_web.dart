import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<void> descargarCsv(String contenido, String nombreArchivo) async {
  final bytes = utf8.encode(contenido);
  final jsArray = bytes.toJS;
  final blob = web.Blob(
    [jsArray].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..setAttribute('download', nombreArchivo)
    ..click();
  web.URL.revokeObjectURL(url);
  anchor.remove();
}
