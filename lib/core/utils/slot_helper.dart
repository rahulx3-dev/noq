import 'package:intl/intl.dart';
import 'time_helper.dart';

class SlotHelper {
  /// Generates a list of slots between [startTimeStr] and [endTimeStr]
  /// with a given [intervalMinutes].
  ///
  /// Only generates slots whose start time is in the future relative to [now]
  /// if [targetDate] is today.
  static List<Map<String, dynamic>> generateSlots({
    required String startTimeStr,
    required String endTimeStr,
    required int intervalMinutes,
    required int capacity,
    required DateTime targetDate,
    List<Map<String, dynamic>> customSlots = const [],
    bool shouldStartFromNow = false,
  }) {
    final List<Map<String, dynamic>> slots = [];

    final now = DateTime.now();
    bool isToday =
        targetDate.year == now.year &&
        targetDate.month == now.month &&
        targetDate.day == now.day;

    try {
      DateTime? current = TimeHelper.parseSessionTime(startTimeStr, targetDate);
      DateTime? finalEnd = TimeHelper.parseSessionTime(endTimeStr, targetDate);

      if (current == null || finalEnd == null) return slots;

      // If end time is before start time (e.g. overnight), wrap to next day
      if (finalEnd.isBefore(current)) {
        finalEnd = finalEnd.add(const Duration(days: 1));
      }

      // Add custom slots first
      for (var cs in customSlots) {
        DateTime? finalCsStart = TimeHelper.parseSessionTime(
          cs['startTime'],
          targetDate,
        );
        DateTime? finalCsEnd = TimeHelper.parseSessionTime(
          cs['endTime'],
          targetDate,
        );

        if (finalCsStart == null || finalCsEnd == null) continue;

        // Wrap custom slot end time to next day if overnight relative to session start
        if (finalCsEnd.isBefore(finalCsStart)) {
          finalCsEnd = finalCsEnd.add(const Duration(days: 1));
        }

        // FILTER: Only add if it starts within this session's window
        if (finalCsStart.isBefore(current) ||
            finalCsStart.isAfter(finalEnd) ||
            finalCsStart.isAtSameMomentAs(finalEnd)) {
          continue;
        }

        bool isPast = isToday && (finalCsStart.isBefore(now));

        slots.add({
          ...cs,
          'remainingCapacity': cs['capacity'],
          'id': DateFormat('HHmm').format(finalCsStart),
          'isSelected': false,
          'isPast': isPast,
        });
      }

      if (intervalMinutes <= 0) return slots;

      DateTime iterCurrent = current;
      
      // LATE START FIX: For Admin Preview, if session started in the past, start from NOW
      if (shouldStartFromNow && isToday && current.isBefore(now) && finalEnd.isAfter(now)) {
        iterCurrent = now;
      }

      DateTime iterFinalEnd = finalEnd;

      while (iterCurrent.isBefore(iterFinalEnd)) {
        DateTime slotEnd = iterCurrent.add(Duration(minutes: intervalMinutes));

        // Ensure partial slot handling
        if (slotEnd.isAfter(iterFinalEnd)) {
          slotEnd = iterFinalEnd;
        }

        // PAST SLOT RULE: Skip adding this slot if slotStartTime < currentTime today
        // For shouldStartFromNow, we already adjusted iterCurrent so it's not past now.
        final bool isPast = isToday && iterCurrent.isBefore(now.subtract(const Duration(seconds: 1)));

        if (!isPast) {
          slots.add({
            'id': DateFormat('HHmm').format(iterCurrent),
            'startTime': TimeHelper.formatTime(iterCurrent),
            'endTime': TimeHelper.formatTime(slotEnd),
            'capacity': capacity,
            'remainingCapacity': capacity,
            'isSelected': false, // Default to unselected
            'isPast': false, // Add helper flag for UI
          });
        }

        iterCurrent = slotEnd;
      }
    } catch (e) {
      // Return empty if parsing fails
      // ignore: avoid_print
      print('SlotHelper Error: $e');
    }

    return slots;
  }
}
