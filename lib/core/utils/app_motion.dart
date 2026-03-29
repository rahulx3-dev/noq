import 'package:flutter/material.dart';
import 'app_motion_tokens.dart';

/// Helper utilities for common motion patterns in NOQ.
class AppMotion {
  /// A subtle scale + fade animation useful for buttons or small elements.
  static Widget scaleFade({
    required Widget child,
    double beginScale = 0.95,
    Duration? duration,
    Curve? curve,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration ?? AppMotionTokens.standard,
      curve: curve ?? AppMotionTokens.standardCurve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: beginScale + (value * (1.0 - beginScale)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  /// Staggered index delay helper
  static Duration stagger(int index, {Duration? base, Duration? step}) {
    final b = base ?? const Duration(milliseconds: 50);
    final s = step ?? const Duration(milliseconds: 30);
    return b + (s * index);
  }
}
