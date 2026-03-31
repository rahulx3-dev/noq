import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/app_message.dart';
import '../../../app/app_routes.dart';
import '../../../core/models/user_profile_model.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _isResending = false;
  bool _isChecking = false;
  int _timerSeconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _timerSeconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        setState(() => _timerSeconds--);
      } else {
        _timer?.cancel();
      }
    });
  }

  Future<void> _handleResend() async {
    if (_timerSeconds > 0) return;

    setState(() => _isResending = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (mounted) {
        showAppMessage(
          context,
          'Verification link resent!',
          type: AppMessageType.success,
        );
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        showAppMessage(context, 'Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _checkVerification() async {
    setState(() => _isChecking = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      final updatedUser = FirebaseAuth.instance.currentUser;

      if (updatedUser != null && updatedUser.emailVerified) {
        // Force token refresh to ensure router/providers see the verified status
        await updatedUser.getIdToken(true);
        
        final firestore = ref.read(firestoreServiceProvider);
        final profileDoc = await firestore.getUserProfile(updatedUser.uid);
        
        if (mounted) {
          if (profileDoc.exists) {
            final profile = UserProfile.fromFirestore(profileDoc);
            String destination = AppRoutes.studentDashboard;
            
            if (profile.role == UserRole.admin) {
              destination = AppRoutes.adminDashboard;
            } else if (profile.role == UserRole.staff) {
              destination = AppRoutes.staffDashboard;
            }
            
            // Invalidate profile provider to ensure fresh data on dashboard
            ref.invalidate(userProfileProvider);
            context.go(destination);
          } else {
            context.go(AppRoutes.studentDashboard);
          }
        }
      } else {
        if (mounted) {
          showAppMessage(
            context,
            'Email not yet verified. Please check your inbox or try again in a moment.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showAppMessage(context, 'Error checking status: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'your email';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mark_email_unread_outlined,
                color: theme.primaryColor,
                size: 64,
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'Verify email',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: theme.primaryColor,
                letterSpacing: -1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "We've sent a verification link to $userEmail. Please check your inbox and verify to continue.",
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _isChecking ? null : _checkVerification,
              child: _isChecking
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text("I've verified"),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Didn't receive link? ",
                  style: GoogleFonts.plusJakartaSans(color: theme.textTheme.bodySmall?.color),
                ),
                TextButton(
                  onPressed: (_timerSeconds > 0 || _isResending) ? null : _handleResend,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _timerSeconds > 0 ? 'Resend in ${_timerSeconds}s' : 'Resend',
                    style: GoogleFonts.plusJakartaSans(
                      color: (_timerSeconds > 0 || _isResending) 
                          ? const Color(0xFF9CA3AF) 
                          : theme.primaryColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () async {
                await ref.read(authServiceProvider).signOut();
                if (mounted) {
                  context.go(AppRoutes.authNav);
                }
              },
              child: Text(
                'Back to Login',
                style: GoogleFonts.plusJakartaSans(
                  color: theme.textTheme.bodySmall?.color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
