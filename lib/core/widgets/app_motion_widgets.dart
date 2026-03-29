import 'package:flutter/material.dart';
import '../utils/app_motion_tokens.dart';
import 'package:google_fonts/google_fonts.dart';

/// A collection of reusable motion wrappers for the NOQ application.

/// A shared widget for smooth "size + fade" transitions of expanding sections.
class AppExpandablePanel extends StatelessWidget {
  final bool isExpanded;
  final Widget child;
  final Duration? duration;
  final Curve? curve;

  const AppExpandablePanel({
    super.key,
    required this.isExpanded,
    required this.child,
    this.duration,
    this.curve,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: duration ?? AppMotionTokens.standard,
      curve: curve ?? AppMotionTokens.standardCurve,
      padding: EdgeInsets.zero,
      child: AnimatedSize(
        duration: duration ?? AppMotionTokens.standard,
        curve: curve ?? AppMotionTokens.standardCurve,
        alignment: Alignment.topCenter,
        child: AnimatedOpacity(
          duration: duration ?? AppMotionTokens.fast,
          opacity: isExpanded ? 1.0 : 0.0,
          child: isExpanded
              ? child
              : const SizedBox(width: double.infinity, height: 0),
        ),
      ),
    );
  }
}

/// Pulse/glow wrapper for status indicators.
class AppStatusGlow extends StatefulWidget {
  final Widget child;
  final Color color;
  final bool isActive;
  final BoxShape shape;
  final BorderRadius? borderRadius;

  const AppStatusGlow({
    super.key,
    required this.child,
    required this.color,
    this.isActive = true,
    this.shape = BoxShape.circle,
    this.borderRadius,
  });

  @override
  State<AppStatusGlow> createState() => _AppStatusGlowState();
}

class _AppStatusGlowState extends State<AppStatusGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return widget.child;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.circle
                ? null
                : widget.borderRadius,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.3 * _animation.value),
                blurRadius: 10 * _animation.value,
                spreadRadius: 2 * _animation.value,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A digit/value switcher for smooth stock/capacity changes.
class AppAnimatedValue extends StatelessWidget {
  final String value;
  final TextStyle style;
  final TextAlign textAlign;

  const AppAnimatedValue({
    super.key,
    required this.value,
    required this.style,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotionTokens.fast,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.2),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Text(
        value,
        key: ValueKey<String>(value),
        style: style,
        textAlign: textAlign,
      ),
    );
  }
}

/// Enter/Exit animations for list items.
class AppFadeSlide extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration? delay;

  const AppFadeSlide({
    super.key,
    required this.child,
    this.index = 0,
    this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final staggeredDelay = delay ?? Duration(milliseconds: 50 * index);

    return FutureBuilder(
      future: Future.delayed(staggeredDelay),
      builder: (context, snapshot) {
        return TweenAnimationBuilder<double>(
          tween: snapshot.connectionState == ConnectionState.done
              ? Tween(begin: 0.0, end: 1.0)
              : Tween(begin: 0.0, end: 0.0),
          duration: AppMotionTokens.standard,
          curve: AppMotionTokens.enterCurve,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: child,
        );
      },
    );
  }
}

class AppQuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final bool isMax;
  final Color? color;
  final VoidCallback? onTapValue;

  const AppQuantityStepper({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    this.isMax = false,
    this.color,
    this.onTapValue,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? const Color(0xFFFF9800);

    return Container(
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: activeColor.withValues(alpha: 0.1), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove,
            onTap: onDecrement,
            enabled: quantity > 0,
            color: activeColor,
          ),
          SizedBox(
            width: 24,
            child: Center(
              child: GestureDetector(
                onTap: onTapValue,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Text(
                    '$quantity',
                    key: ValueKey<int>(quantity),
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: activeColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            onTap: onIncrement,
            enabled: !isMax,
            color: activeColor,
          ),
        ],
      ),
    );
  }
}

/// A premium slot chip with smooth color lerping and scale feedback.
class AppSlotChip extends StatelessWidget {
  final String label;
  final String timeText;
  final bool isSelected;
  final bool isFull;
  final bool isWarning;
  final VoidCallback onTap;
  final Color? activeColor;

  const AppSlotChip({
    super.key,
    required this.label,
    required this.timeText,
    required this.isSelected,
    this.isFull = false,
    this.isWarning = false,
    required this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isFull
        ? Colors.grey[100]
        : isSelected
        ? (activeColor ?? const Color(0xFF1B2A10))
        : Colors.white;

    final textColor = isFull
        ? Colors.grey[400]
        : isSelected
        ? Colors.white
        : Colors.black87;

    final content = AnimatedContainer(
      duration: AppMotionTokens.standard,
      curve: AppMotionTokens.standardCurve,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? Colors.transparent
              : (isFull ? Colors.grey[200]! : Colors.grey[300]!),
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: (activeColor ?? const Color(0xFF1B2A10)).withValues(
                    alpha: 0.3,
                  ),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.lexend(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: isSelected ? Colors.white70 : Colors.grey[500],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            timeText,
            style: GoogleFonts.lexend(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: isFull ? null : onTap,
      child: isWarning && !isFull && !isSelected
          ? AppStatusGlow(
              color: Colors.orange.withValues(alpha: 0.5),
              isActive: true,
              borderRadius: BorderRadius.circular(16),
              shape: BoxShape.rectangle,
              child: content,
            )
          : content,
    );
  }
}

class _StepperButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final Color color;

  const _StepperButton({
    required this.icon,
    required this.onTap,
    required this.enabled,
    required this.color,
  });

  @override
  State<_StepperButton> createState() => _StepperButtonState();
}

class _StepperButtonState extends State<_StepperButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => widget.enabled ? _controller.forward() : null,
      onTapUp: (_) => widget.enabled ? _controller.reverse() : null,
      onTapCancel: () => widget.enabled ? _controller.reverse() : null,
      onTap: widget.enabled ? widget.onTap : null,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: Icon(
            widget.icon,
            size: 18,
            color: widget.enabled ? widget.color : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}

class AppFavoriteButton extends StatefulWidget {
  final bool isFavorite;
  final VoidCallback onTap;
  final double size;

  const AppFavoriteButton({
    super.key,
    required this.isFavorite,
    required this.onTap,
    this.size = 20,
  });

  @override
  State<AppFavoriteButton> createState() => _AppFavoriteButtonState();
}

class _AppFavoriteButtonState extends State<AppFavoriteButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.3,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticIn)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(AppFavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFavorite && !oldWidget.isFavorite) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
          child: Icon(
            widget.isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: widget.isFavorite ? const Color(0xFFFF5252) : Colors.white,
            size: widget.size,
          ),
        ),
      ),
    );
  }
}
