import 'dart:convert';
import 'dart:typed_data';

/// Las fotos de los productos se guardan en Firestore como JPEG en Base64
/// (campo `imagen`), igual que en la app Kotlin.
class ImageUtils {
  ImageUtils._();

  static String encode(Uint8List bytes) => base64Encode(bytes);

  /// Decodifica el Base64 guardado. Android (`Base64.DEFAULT`) insertaba saltos
  /// de línea, así que se eliminan los espacios antes de decodificar.
  static Uint8List? decode(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return base64Decode(value.replaceAll(RegExp(r'\s'), ''));
    } catch (_) {
      return null;
    }
  }
}

/// Réplica de `String.hashCode()` de Java, para que los IDs de las
/// notificaciones sean estables entre ejecuciones.
int javaStringHash(String s) {
  var h = 0;
  for (final unit in s.codeUnits) {
    h = (31 * h + unit) & 0xFFFFFFFF;
  }
  // Convertir a entero de 32 bits con signo
  return h >= 0x80000000 ? h - 0x100000000 : h;
}
