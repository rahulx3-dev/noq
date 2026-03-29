import 'package:flutter/animation.dart';

/// Standard motion tokens for the NOQ application to ensure consistency.
class AppMotionTokens {
  // Durations
  static const Duration ultraFast = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 240);
  static const Duration emphasis = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 420);

  // Curves
  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;
  static const Curve emphasisCurve = Curves.easeOutBack;
  static const Curve settleCurve = Curves.easeOutQuart;
}
