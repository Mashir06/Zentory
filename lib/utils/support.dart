import 'package:url_launcher/url_launcher.dart';

/// WhatsApp de soporte técnico de NubikSoft (código de país de Panamá).
///
/// Solo para soporte: por la política de pagos de Google Play, la app no
/// enlaza a ninguna forma de pago (el enlace de pago lo envía NubikSoft por
/// WhatsApp desde el panel web).
const zentorySupportWhatsApp = '50767968449';

/// Abre el chat de soporte con [message]. Devuelve `false` si no se pudo.
Future<bool> openSupportWhatsApp(String message) async {
  final uri = Uri.parse(
    'https://wa.me/$zentorySupportWhatsApp?text=${Uri.encodeComponent(message)}',
  );
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
