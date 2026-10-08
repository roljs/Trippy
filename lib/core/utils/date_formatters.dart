import 'package:intl/intl.dart';

class DateFormatters {
  static final DateFormat dayHeader = DateFormat('EEE, MMM d'); // e.g. Mon, Oct 12
  static final DateFormat shortDate = DateFormat('MMM d'); // e.g. Oct 12
  static final DateFormat fullDate = DateFormat('MMMM d, yyyy'); // e.g. October 12, 2026
  static final DateFormat monthYear = DateFormat('MMMM yyyy'); // e.g. October 2026
  static final DateFormat time12 = DateFormat('h:mm a'); // e.g. 3:30 PM
  static final DateFormat time24 = DateFormat('HH:mm'); // e.g. 15:30
  static final DateFormat dayOfWeek = DateFormat('EEEE'); // e.g. Monday
  static final DateFormat weekdayShort = DateFormat('EEE'); // e.g. Mon

  /// Formats date range: "Oct 12 - Oct 22, 2026"
  static String formatTripDateRange(DateTime start, DateTime end) {
    if (start.year == end.year) {
      return '${shortDate.format(start)} – ${shortDate.format(end)}, ${start.year}';
    }
    return '${shortDate.format(start)}, ${start.year} – ${shortDate.format(end)}, ${end.year}';
  }

  /// Formats standard ISO or HH:mm time string into friendly 12-hour format
  static String formatTimeString(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      final dt = DateTime(2026, 1, 1, hour, minute);
      return time12.format(dt);
    }
    return timeStr;
  }

  /// Formats date and time: "Oct 12, 3:30 PM"
  static String formatDateTime(DateTime dt) {
    return '${shortDate.format(dt)}, ${time12.format(dt)}';
  }
}
