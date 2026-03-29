import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers.dart';
import '../../../core/models/user_profile_model.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {

  late final AnimationController _wordCtrl;
  late final Animation<double>   _wordFade;

  Ticker? _ticker;

  final _outerSpring = _Spring(stiffness: 140, damping: 22);
  final _innerSpring = _Spring(stiffness: 80,  damping: 18);

  final GlobalKey _oKey = GlobalKey();
  Offset _oCenter   = Offset.zero;
  double _oOuterR   = 0;
  double _oInnerR   = 0;
  double _maxOuterR = 600;
  double _maxInnerR = 300;

  double _wordOpacity  = 0.0;
  double _nqOpacity    = 1.0;
  double _bgOpacity    = 0.0;
  double _ringAlpha    = 0.0;
  double _ringOuterR   = 0;
  double _ringInnerR   = 0;
  bool   _oVisible     = true;
  bool   _ringVisible  = false;
  bool   _redirected   = false;

  static const Duration _springDuration = Duration(milliseconds: 700);

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    _wordCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _wordFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _wordCtrl, curve: Curves.easeOutCubic));
    _wordCtrl.addListener(
        () => setState(() => _wordOpacity = _wordFade.value));

    // Global safety timer: if anything hangs, redirect after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && !_redirected) {
        print('SplashScreen: Safety timeout triggered');
        _handleRedirect();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  void _measureO(Size screen) {
    final box = _oKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos  = box.localToGlobal(Offset.zero);
    final size = box.size;
    _oCenter   = Offset(pos.dx + size.width / 2, pos.dy + size.height / 2);
    _oOuterR   = size.height * 0.47;
    _oInnerR   = size.height * 0.25;
    _maxOuterR = math.sqrt(
      math.pow(math.max(_oCenter.dx, screen.width  - _oCenter.dx), 2) +
      math.pow(math.max(_oCenter.dy, screen.height - _oCenter.dy), 2),
    ) + 60;
    _maxInnerR = _maxOuterR * 0.48;
  }

  Future<void> _run() async {
    print('SplashScreen: _run started');
    try {
      final screen = MediaQuery.of(context).size;
      print('SplashScreen: screen size $screen');

      print('SplashScreen: Starting word fade-in');
      await _wordCtrl.forward().timeout(const Duration(seconds: 2));
      print('SplashScreen: Word fade-in complete');

      await Future.delayed(const Duration(milliseconds: 650));
      print('SplashScreen: Delay complete, measuring "o"');

      _measureO(screen);

      if (!mounted) return;
      setState(() {
        _oVisible    = false;
        _ringVisible = true;
        _ringAlpha   = 1.0;
        _ringOuterR  = _oOuterR;
        _ringInnerR  = _oInnerR;
      });
      print('SplashScreen: "o" hidden, ring visible. Starting spring.');

      await _runSpring().timeout(const Duration(seconds: 3));
      print('SplashScreen: Spring complete');

      final fadeSteps = 12;
      for (int i = 1; i <= fadeSteps; i++) {
        if (!mounted) return;
        await Future.delayed(
            Duration(milliseconds: (200 / fadeSteps).round()));
        setState(() => _ringAlpha = 1.0 - (i / fadeSteps));
      }
      setState(() => _ringVisible = false);
      print('SplashScreen: Ring fade-out complete');

      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      print('SplashScreen: Redirecting...');
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
      _handleRedirect();
    } catch (e, stack) {
      print('SplashScreen ERROR: $e');
      print(stack);
      if (mounted) {
        _handleRedirect(); // Safety fallback
      }
    }
  }

  void _handleRedirect() {
    if (!mounted || _redirected) return;
    _redirected = true;

    final authState = ref.read(authStateProvider);

    if (authState.value == null) {
      context.go('/login');
    } else {
      final profile = ref.read(userProfileProvider);
      if (profile.value == null) {
        context.go('/login');
      } else {
        switch (profile.value!.role) {
          case UserRole.student:
            context.go('/student/dashboard');
            break;
          case UserRole.staff:
            context.go('/staff/dashboard');
            break;
          case UserRole.admin:
            context.go('/admin/dashboard');
            break;
        }
      }
    }
  }

  Future<void> _runSpring() {
    final completer = Completer<void>();

    _ticker = createTicker((elapsed) {
      if (!mounted) { _ticker?.stop(); return; }

      final t = elapsed.inMicroseconds / 1e6;

      final outerP = _outerSpring.solve(t).clamp(0.0, 1.0);
      final innerP = _innerSpring.solve(t).clamp(0.0, 1.0);

      final outerR = _lerp(_oOuterR,   _maxOuterR, outerP);
      final innerR = _lerp(_oInnerR,   _maxInnerR, innerP);

      double bgO  = _bgOpacity;
      double nqO  = _nqOpacity;
      if (outerP > 0.42) {
        final p = _easeOutCubic(((outerP - 0.42) / 0.58).clamp(0.0, 1.0));
        bgO = p;
        nqO = (1.0 - p).clamp(0.0, 1.0);
      }

      setState(() {
        _ringOuterR = outerR;
        _ringInnerR = innerR;
        _bgOpacity  = bgO;
        _nqOpacity  = nqO;
      });

      if (elapsed >= _springDuration) {
        setState(() {
          _ringOuterR = _maxOuterR;
          _ringInnerR = _maxInnerR;
          _bgOpacity  = 1.0;
          _nqOpacity  = 0.0;
        });
        _ticker?.stop();
        _ticker?.dispose();
        _ticker = null;
        completer.complete();
      }
    });
    _ticker!.start();
    return completer.future;
  }

  @override
  void dispose() {
    _wordCtrl.dispose();
    _ticker?.stop();
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: _bgOpacity,
            child: Container(color: Colors.white),
          ),

          if (_ringVisible)
            CustomPaint(
              painter: _RingPainter(
                center:      _oCenter,
                outerRadius: _ringOuterR,
                innerRadius: _ringInnerR,
                alpha:       _ringAlpha,
              ),
            ),

          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Opacity(
                  opacity: (_wordOpacity * _nqOpacity).clamp(0, 1),
                  child: Text('n', style: _s()),
                ),
                Opacity(
                  opacity: _oVisible ? _wordOpacity.clamp(0, 1) : 0.0,
                  child: Text('o', key: _oKey, style: _s()),
                ),
                Opacity(
                  opacity: (_wordOpacity * _nqOpacity).clamp(0, 1),
                  child: Text('q', style: _s()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _s() => GoogleFonts.plusJakartaSans(
        fontSize: 100,
        fontWeight: FontWeight.w800,
        color: Colors.black,
        letterSpacing: -4,
        height: 1.0,
      );

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
  static double _easeOutCubic(double t) =>
      1 - math.pow(1 - t, 3).toDouble();
}

class _Spring {
  final double stiffness;
  final double damping;

  const _Spring({
    required this.stiffness,
    required this.damping,
  });

  double solve(double t) {
    const double mass = 1.0;
    final w0   = math.sqrt(stiffness / mass);
    final zeta = damping / (2 * math.sqrt(stiffness * mass));

    if (zeta < 1.0) {
      final wd = w0 * math.sqrt(1 - zeta * zeta);
      return 1 -
          math.exp(-zeta * w0 * t) *
          (math.cos(wd * t) + (zeta * w0 / wd) * math.sin(wd * t));
    } else if (zeta == 1.0) {
      return 1 - math.exp(-w0 * t) * (1 + w0 * t);
    } else {
      final r1 = -w0 * (zeta - math.sqrt(zeta * zeta - 1));
      final r2 = -w0 * (zeta + math.sqrt(zeta * zeta - 1));
      final c2 = r1 / (r1 - r2);
      final c1 = 1 - c2;
      return 1 - (c1 * math.exp(r1 * t) + c2 * math.exp(r2 * t));
    }
  }
}

class _RingPainter extends CustomPainter {
  final Offset center;
  final double outerRadius;
  final double innerRadius;
  final double alpha;

  const _RingPainter({
    required this.center,
    required this.outerRadius,
    required this.innerRadius,
    required this.alpha,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (alpha <= 0 || outerRadius <= 0) return;
    final paint = Paint()
      ..color = Colors.black.withOpacity(alpha.clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;
    final path = Path()
      ..addOval(Rect.fromCircle(center: center, radius: outerRadius))
      ..addOval(Rect.fromCircle(center: center, radius: innerRadius));
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.outerRadius != outerRadius || o.innerRadius != innerRadius ||
      o.alpha != alpha || o.center != center;
}
