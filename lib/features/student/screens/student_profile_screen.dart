import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/themes/student_theme.dart';
import '../../../core/providers.dart';
import '../widgets/logout_dialog.dart';

class StudentProfileScreen extends ConsumerWidget {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);
    final profile = userProfileAsync.value;

    final name = profile?.displayName ?? 'Student';
    final studentId = profile?.studentId ?? '20248592';
    final department = profile?.department ?? 'Computer Science';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';

    return Scaffold(
      backgroundColor: StudentTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        leading: Center(
          child: Container(
            margin: const EdgeInsets.only(left: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: StudentTheme.primary,
                size: 18,
              ),
              onPressed: () => context.go('/student/dashboard'),
            ),
          ),
        ),
        title: Text(
          'My Profile',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: StudentTheme.primary,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
            ),
            child: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.settings_outlined, color: StudentTheme.primary, size: 20),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Profile Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Profile Image
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: StudentTheme.primary.withValues(alpha: 0.1), width: 1.5),
                          ),
                          child: CircleAvatar(
                            radius: 54,
                            backgroundColor: StudentTheme.background,
                            child: profile?.imageUrl?.isNotEmpty ?? false
                                ? ClipOval(
                                    child: Image.network(
                                      profile!.imageUrl!,
                                      width: 108,
                                      height: 108,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Text(
                                    initial,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 42,
                                      fontWeight: FontWeight.w800,
                                      color: StudentTheme.primary,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: StudentTheme.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile?.email ?? '',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: StudentTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: StudentTheme.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                      ),
                      child: Text(
                        'ID: $studentId • $department',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: StudentTheme.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.push('/student/profile/edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: StudentTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Edit Profile',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Preferences Section
            _buildSectionHeader('Preferences'),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                ),
                child: Column(
                  children: [
                    _buildPreferenceItem(
                      icon: Icons.notifications_none_rounded,
                      iconColor: StudentTheme.primary,
                      iconBg: StudentTheme.primary.withValues(alpha: 0.05),
                      title: 'Notifications',
                      trailing: Switch(
                        value: true,
                        onChanged: (val) {},
                        activeColor: StudentTheme.primary,
                      ),
                    ),
                    const Divider(height: 1, color: StudentTheme.background, indent: 72),
                    _buildPreferenceItem(
                      icon: Icons.lock_outline_rounded,
                      iconColor: const Color(0xFF3B82F6),
                      iconBg: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                      title: 'Change Password',
                      onTap: () => context.push('/student/profile/change-password'),
                    ),
                    const Divider(height: 1, color: StudentTheme.background, indent: 72),
                    _buildPreferenceItem(
                      icon: Icons.power_settings_new_rounded,
                      iconColor: const Color(0xFFEF4444),
                      iconBg: const Color(0xFFEF4444).withValues(alpha: 0.08),
                      title: 'Log Out',
                      textColor: const Color(0xFFEF4444),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => LogoutDialog(
                            onConfirm: () async {
                              await FirebaseAuth.instance.signOut();
                              if (context.mounted) {
                                context.go('/login');
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Support Section
            _buildSectionHeader('Support'),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                ),
                child: _buildPreferenceItem(
                  icon: Icons.help_outline_rounded,
                  iconColor: StudentTheme.textSecondary,
                  iconBg: StudentTheme.background,
                  title: 'Help & Support',
                  onTap: () {},
                ),
              ),
            ),

            const SizedBox(height: 48),
            Text(
              'Version 2.4.0',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: StudentTheme.textSecondary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: StudentTheme.primary,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildPreferenceItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    VoidCallback? onTap,
    Widget? trailing,
    Color? textColor,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: textColor ?? StudentTheme.primary,
        ),
      ),
      trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: StudentTheme.primary.withValues(alpha: 0.2)),
    );
  }
}

