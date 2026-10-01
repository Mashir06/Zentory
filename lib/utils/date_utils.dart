import 'package:intl/intl.dart';

import '../l10n/strings.dart';

/// Utilidades de fechas.
///
/// Las fechas de vencimiento se guardan en Firestore como texto con el formato
/// `d/M/yyyy` (por ejemplo `5/7/2026`), igual que en la app Kotlin, para
/// mantener compatibilidad con los datos existentes.
class DateUtilsZ {
  DateUtilsZ._();

  static final DateFormat _dayFormat = DateFormat('d/M/yyyy');

  /// Convierte `d/M/yyyy` (o `dd/MM/yyyy`) en una fecha. Devuelve `null` si no
  /// es válida.
  static DateTime? parse(String? value) {
    if (value == null) return null;
    final parts = value.trim().split('/');
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    return DateTime(y, m, d);
  }

  /// Formatea una fecha como `d/M/yyyy`.
  static String format(DateTime date) => _dayFormat.format(date);

  static DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Días enteros desde hoy hasta [date] (negativo si ya pasó).
  static int daysFromToday(DateTime date) {
    final t = today();
    // Se usa UTC para evitar desfases por horario de verano.
    return DateTime.utc(date.year, date.month, date.day)
        .difference(DateTime.utc(t.year, t.month, t.day))
        .inDays;
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// "Mayo 2026" (o "October 2026", "2026年10月" según el idioma).
  static String monthYear(DateTime date) => capitalize(
      currentLanguage == AppLanguage.es
          ? DateFormat('MMMM yyyy', 'es').format(date)
          : DateFormat.yMMMM(currentLanguage.code).format(date));

  /// "28 de mayo" (o "October 28", "10月28日").
  static String dayOfMonth(DateTime date) =>
      currentLanguage == AppLanguage.es
          ? DateFormat("d 'de' MMMM", 'es').format(date)
          : DateFormat.MMMMd(currentLanguage.code).format(date);
}
