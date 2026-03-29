import 'package:intl/intl.dart';

void main() {
  final date = DateTime(2026, 3, 10);
  final times = ['11:50 am', '11:50 AM', '1:30 PM', '01:30 pm'];

  for (var timeStr in times) {
    DateTime? parsedResult;
    final formats = [
      DateFormat('hh:mm a', 'en_US'),
      DateFormat('h:mm a', 'en_US'),
      DateFormat('hh:mma', 'en_US'),
      DateFormat('h:mma', 'en_US'),
      DateFormat('HH:mm'),
      DateFormat('H:mm'),
    ];

    for (var fmt in formats) {
      try {
        final parsed = fmt.parse(timeStr.trim());
        parsedResult = DateTime(
          date.year,
          date.month,
          date.day,
          parsed.hour,
          parsed.minute,
        );
        // ignore: avoid_print
        print(
          '[$timeStr] Parsed by ${fmt.pattern}: $parsedResult (Hour: ${parsedResult.hour})',
        );
        break;
      } catch (_) {}
    }

    if (parsedResult == null) {
      // ignore: avoid_print
      print('[$timeStr] Failed to format');
    }
  }
}
