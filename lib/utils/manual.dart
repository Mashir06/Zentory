import 'dart:io';

import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../l10n/strings.dart';

/// Copia el manual de usuario (assets/docs/manual.docx) a la caché y lo abre
/// con la app que el usuario tenga para documentos de Word.
///
/// Devuelve un mensaje de error, o `null` si se abrió correctamente.
Future<String?> openWordManual() async {
  try {
    final data = await rootBundle.load('assets/docs/manual.docx');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/manual.docx');
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    final result = await OpenFilex.open(
      file.path,
      type:
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    if (result.type == ResultType.done) return null;
    if (result.type == ResultType.noAppToOpen) {
      return tr('No tienes una app para abrir documentos de Word.');
    }
    return tr('No se pudo abrir el manual: {0}', [result.message]);
  } catch (_) {
    return tr('No se pudo encontrar el archivo del manual en los recursos de la app.');
  }
}
