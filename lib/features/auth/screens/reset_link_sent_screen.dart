import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/app_message.dart';

class ResetLinkSentScreen extends ConsumerStatefulWidget {
  final String email;
  const ResetLinkSentScreen({super.key, required this.email});

  @override
  ConsumerState<ResetLinkSentScreen> createState() =>
      _ResetLinkSentScreenState();
}

class _ResetLinkSentScreenState extends ConsumerState<ResetLinkSentScreen> {
  bool _isResending = false;

  Future<void> _handleResend() async {
    setState(() => _isResending = true);
    try {
      await ref.read(authServiceProvider).resetPassword(email: widget.email);
      if (mounted) {
        showAppMessage(
          context,
          'Reset link resent successfully!',
          type: AppMessageType.success,
        );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
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
                Icons.mark_email_read_outlined,
                color: theme.primaryColor,
                size: 64,
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'Link sent',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: theme.primaryColor,
                letterSpacing: -1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'A reset link has been sent to ${widget.email}. Please check your inbox.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => context.go('/login'),
              child: const Text('Back to Login'),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Didn't receive link? ",
                  style: GoogleFonts.plusJakartaSans(color: theme.textTheme.bodySmall?.color),
                ),
                GestureDetector(
                  onTap: _isResending ? null : _handleResend,
                  child: Text(
                    'Resend',
                    style: GoogleFonts.plusJakartaSans(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
