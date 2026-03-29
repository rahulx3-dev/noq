import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers.dart';
import '../../../core/models/user_profile_model.dart';

class VerifySuccessScreen extends ConsumerWidget {
  const VerifySuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                color: Colors.green.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Colors.green,
                size: 64,
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'Verified!',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: theme.primaryColor,
                letterSpacing: -1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your email has been successfully verified. You can now start ordering your favorite campus meals.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                final profile = ref.read(userProfileProvider).value;
                if (profile != null) {
                  switch (profile.role) {
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
                } else {
                  context.go('/login');
                }
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Get Started'),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}
