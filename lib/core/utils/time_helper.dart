import 'package:intl/intl.dart';

class TimeHelper {
  /// Parses a time string (e.g., "11:50 AM", "22:30") into a DateTime object
  /// normalized to the provided [date].
  ///
  /// Robustly handles various formats and ensures AM/PM is correctly interpreted.
  static DateTime? parseSessionTime(String timeStr, DateTime date) {
    if (timeStr.isEmpty) return null;

    // Handle ranges like "11:50 AM to 12:30 PM" by taking the start time
    String normalizedTime = timeStr.trim().toUpperCase();
    if (normalizedTime.contains(' TO ')) {
      normalizedTime = normalizedTime.split(' TO ').first.trim();
    } else if (normalizedTime.contains(' - ')) {
      normalizedTime = normalizedTime.split(' - ').first.trim();
    }

    // Specific locale to ensure AM/PM is handled correctly regardless of device settings
    final formats = [
      DateFormat('hh:mm a', 'en_US'),
      DateFormat('h:mm a', 'en_US'),
      DateFormat('hh:mma', 'en_US'), // Handles 11:30AM (no space)
      DateFormat('h:mma', 'en_US'),
      DateFormat('HH:mm'),
      DateFormat('H:mm'),
    ];

    for (var fmt in formats) {
      try {
        final parsed = fmt.parse(normalizedTime);
        return DateTime(
          date.year,
          date.month,
          date.day,
          parsed.hour,
          parsed.minute,
        );
      } catch (_) {}
    }

    // Fallback search for AM/PM for non-standard separators or formats
    try {
      bool isPM = normalizedTime.contains('PM');
      bool isAM = normalizedTime.contains('AM');

      final digits = normalizedTime
          .replaceAll(RegExp(r'[^0-9:]'), '')
          .split(':');
      if (digits.length == 2) {
        int hour = int.parse(digits[0]);
        int minute = int.parse(digits[1]);

        if (isPM && hour < 12) hour += 12;
        if (isAM && hour == 12) hour = 0;

        return DateTime(date.year, date.month, date.day, hour, minute);
      }
    } catch (_) {}

    return null;
  }

  /// Checks if the current time falls within the given start and end times.
  /// Handles overnight sessions (e.g., 10 PM to 2 AM).
  static bool isTimeInWindow(DateTime now, DateTime start, DateTime end) {
    if (end.isBefore(start)) {
      // Overnight session
      final endNextDay = end.add(const Duration(days: 1));
      return (now.isAfter(start) || now.isAtSameMomentAs(start)) &&
          now.isBefore(endNextDay);
    }
    return (now.isAfter(start) || now.isAtSameMomentAs(start)) &&
        now.isBefore(end);
  }

  /// Checks if a session has ended relative to [now].
  static bool hasSessionEnded(DateTime now, DateTime endTime) {
    return now.isAfter(endTime);
  }

  /// Formats a DateTime to a standard display time string.
  static String formatTime(DateTime dt) {
    return DateFormat('hh:mm a').format(dt);
  }

  /// Calculates the remaining time from [now] to [slotStartTimeStr].
  /// Returns "Ready" if the time has passed, or a string like "15m", "1h 5m".
  static String calculateRemainingTime(String slotStartTimeStr) {
    if (slotStartTimeStr.isEmpty) return "15 min"; // Fallback
    
    final now = DateTime.now();
    final start = parseSessionTime(slotStartTimeStr, now);
    
    if (start == null) return "15 min";
    
    final diff = start.difference(now);
    
    if (diff.isNegative) return "Ready";
    
    final minutes = diff.inMinutes;
    if (minutes < 60) {
      return "${minutes}m";
    } else {
      final hours = minutes ~/ 60;
      final remainingMins = minutes % 60;
      if (remainingMins == 0) return "${hours}h";
      return "${hours}h ${remainingMins}m";
    }
  }
}
