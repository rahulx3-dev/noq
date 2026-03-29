import 'time_helper.dart';

/// The single source of truth for session and slot time/release state.
///
/// Every module (Admin, Student, Staff) MUST use this resolver instead of
/// duplicating inline time-parsing and session classification logic.
///
/// Core rule:
///   A session is only truly LIVE when:
///     released == true  AND  startTime <= now < endTime
///
/// "released" alone does NOT mean "currently live".
class SessionStatusResolver {
  // ─────────────────────────────────────────────────────────────────────────
  // Public entry point — compute a [SessionState] for one session
  // ─────────────────────────────────────────────────────────────────────────

  /// Compute the full operational state of one session.
  ///
  /// [selectedDate]  — The date the user/screen is currently viewing.
  /// [now]           — Current local DateTime (pass DateTime.now() or the
  ///                   timer-ticked value from the screen).
  /// [startTimeStr]  — Session start time string, e.g. "11:00 AM" or "11:00".
  /// [endTimeStr]    — Session end time string.
  /// [isReleased]    — Whether admin has released this session's menu.
  static SessionState computeSessionState({
    required DateTime selectedDate,
    required DateTime now,
    required String startTimeStr,
    required String endTimeStr,
    required bool isReleased,
  }) {
    final dateContext = _dateContext(selectedDate, now);

    // ── Past date selected ──────────────────────────────────────────────────
    if (dateContext == _DateContext.past) {
      return SessionState._(
        timeState: SessionTimeState.ended,
        isReleased: isReleased,
        operationalState: isReleased
            ? SessionOperationalState.releasedButEnded
            : SessionOperationalState.notReleasedEnded,
      );
    }

    // ── Future date selected ────────────────────────────────────────────────
    if (dateContext == _DateContext.future) {
      return SessionState._(
        timeState: SessionTimeState.upcoming,
        isReleased: isReleased,
        operationalState: isReleased
            ? SessionOperationalState.releasedUpcoming
            : SessionOperationalState.notReleasedUpcoming,
      );
    }

    // ── Today — compute from actual time ───────────────────────────────────
    final startDt = TimeHelper.parseSessionTime(startTimeStr, selectedDate);
    final endDt = TimeHelper.parseSessionTime(endTimeStr, selectedDate);

    if (startDt == null || endDt == null) {
      // Cannot parse — for safety, if it's today and we can't parse, treat as ended
      // to avoid recommending it for release/upcoming incorrectly.
      // On future dates, it's still upcoming.
      return SessionState._(
        timeState: dateContext == _DateContext.future
            ? SessionTimeState.upcoming
            : SessionTimeState.ended,
        isReleased: isReleased,
        operationalState: isReleased
            ? (dateContext == _DateContext.future
                  ? SessionOperationalState.releasedUpcoming
                  : SessionOperationalState.releasedButEnded)
            : (dateContext == _DateContext.future
                  ? SessionOperationalState.notReleasedUpcoming
                  : SessionOperationalState.notReleasedEnded),
      );
    }

    final SessionTimeState timeState;
    if (TimeHelper.isTimeInWindow(now, startDt, endDt)) {
      timeState = SessionTimeState.current;
    } else if (now.isBefore(startDt)) {
      timeState = SessionTimeState.upcoming;
    } else {
      timeState = SessionTimeState.ended;
    }

    final SessionOperationalState operationalState;
    switch (timeState) {
      case SessionTimeState.current:
        operationalState = isReleased
            ? SessionOperationalState.releasedAndCurrent
            : SessionOperationalState.notReleasedCurrent;
        break;
      case SessionTimeState.upcoming:
        operationalState = isReleased
            ? SessionOperationalState.releasedUpcoming
            : SessionOperationalState.notReleasedUpcoming;
        break;
      case SessionTimeState.ended:
        operationalState = isReleased
            ? SessionOperationalState.releasedButEnded
            : SessionOperationalState.notReleasedEnded;
        break;
    }

    return SessionState._(
      timeState: timeState,
      isReleased: isReleased,
      operationalState: operationalState,
      startDt: startDt,
      endDt: endDt,
    );
  }

  /// Helper to check if all provided sessions for a selected date are past.
  static bool areAllSessionsEnded({
    required DateTime selectedDate,
    required DateTime now,
    required List<dynamic> sessions, // Can be SessionModel or Map
  }) {
    if (sessions.isEmpty) return true;

    for (var s in sessions) {
      final startTime = s is Map ? (s['startTime'] ?? '') : s.startTime;
      final endTime = s is Map ? (s['endTime'] ?? '') : s.endTime;
      final isReleased = s is Map
          ? (s['status'] == 'released')
          : false; // Approx for generic check

      final state = computeSessionState(
        selectedDate: selectedDate,
        now: now,
        startTimeStr: startTime,
        endTimeStr: endTime,
        isReleased: isReleased,
      );
      if (!state.isPast) return false;
    }
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Slot-level state (simpler — no release concept)
  // ─────────────────────────────────────────────────────────────────────────

  /// Classify a slot relative to [now] on [targetDate].
  ///
  /// For past days all slots are [SlotTimeState.past].
  /// For future days all slots are [SlotTimeState.upcoming].
  static SlotTimeState computeSlotState({
    required DateTime targetDate,
    required DateTime now,
    required String startTimeStr,
    required String endTimeStr,
  }) {
    final dateContext = _dateContext(targetDate, now);
    if (dateContext == _DateContext.past) return SlotTimeState.past;
    if (dateContext == _DateContext.future) return SlotTimeState.upcoming;

    final startDt = TimeHelper.parseSessionTime(startTimeStr, targetDate);
    final endDt = TimeHelper.parseSessionTime(endTimeStr, targetDate);

    if (startDt == null || endDt == null) return SlotTimeState.upcoming;

    if (TimeHelper.isTimeInWindow(now, startDt, endDt)) {
      return SlotTimeState.current;
    } else if (now.isBefore(startDt)) {
      return SlotTimeState.upcoming;
    } else {
      return SlotTimeState.past;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────────────────────────────────

  static _DateContext _dateContext(DateTime selectedDate, DateTime now) {
    final todayOnly = DateTime(now.year, now.month, now.day);
    final selOnly = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    if (selOnly.isAtSameMomentAs(todayOnly)) return _DateContext.today;
    if (selOnly.isBefore(todayOnly)) return _DateContext.past;
    return _DateContext.future;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

enum _DateContext { past, today, future }

/// The pure time-based classification of a session.
enum SessionTimeState {
  upcoming, // Session has not started yet
  current, // Session is actively running right now
  ended, // Session's end time has passed
}

/// The combined release + time state a session can be in.
enum SessionOperationalState {
  // Released sessions
  releasedAndCurrent, // 🟢 Truly live — show in Live Menu, Student, Staff
  releasedUpcoming, // 🔵 Released but not started yet
  releasedButEnded, // 🔴 Released but ended — NOT live, label clearly
  // Unreleased sessions
  notReleasedCurrent, // ⚠️ Should be live but menu not released
  notReleasedUpcoming, // ⬜ Future, not yet released
  notReleasedEnded, // ⬛ Past, was never released
}

/// The per-slot time classification.
enum SlotTimeState {
  past, // Slot end time has passed
  current, // Slot is active right now
  upcoming, // Slot has not started yet
}

// ─────────────────────────────────────────────────────────────────────────────
// SessionState value object
// ─────────────────────────────────────────────────────────────────────────────

/// Immutable result returned by [SessionStatusResolver.computeSessionState].
class SessionState {
  final SessionTimeState timeState;
  final SessionOperationalState operationalState;
  final bool isReleased;
  final DateTime? startDt;
  final DateTime? endDt;

  const SessionState._({
    required this.timeState,
    required this.operationalState,
    required this.isReleased,
    this.startDt,
    this.endDt,
  });

  // ── Convenience booleans ────────────────────────────────────────────────

  /// True only when the session is released AND currently within its window.
  bool get isLive =>
      operationalState == SessionOperationalState.releasedAndCurrent;

  /// True when the session is the active window (regardless of release).
  bool get isCurrent => timeState == SessionTimeState.current;

  /// True when the session's end time has passed.
  bool get isPast => timeState == SessionTimeState.ended;

  /// True when the session has not started yet.
  bool get isUpcoming => timeState == SessionTimeState.upcoming;

  /// The session can be selected for release: not past and not already released.
  bool get isSelectableForRelease => !isPast && !isReleased;

  /// Should appear as the active live menu context.
  bool get isVisibleAsLiveMenu => isLive;

  /// Menu is released but the window has ended — show with "ENDED" badge.
  bool get isEndedButReleased =>
      operationalState == SessionOperationalState.releasedButEnded;

  /// A currently-running session whose menu hasn't been released.
  bool get isCurrentButUnreleased =>
      operationalState == SessionOperationalState.notReleasedCurrent;

  /// Should the student see this session's menu?
  /// Shows only if released AND not ended.
  bool get isActiveForStudent =>
      isReleased && timeState != SessionTimeState.ended;

  /// Should the staff auto-focus this session?
  bool get shouldStaffFocus =>
      isLive || operationalState == SessionOperationalState.notReleasedCurrent;

  /// Carry-over check: session ended with a released menu.
  bool get shouldShowCarryOverPrompt => isEndedButReleased;

  @override
  String toString() =>
      'SessionState(time=$timeState, op=$operationalState, '
      'released=$isReleased)';
}
