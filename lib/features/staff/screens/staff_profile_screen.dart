import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../app/themes/staff_theme.dart';
import '../../../core/providers.dart';

class StaffProfileScreen extends ConsumerWidget {
  const StaffProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: StaffTheme.background,
      body: SafeArea(
        child: userProfileAsync.when(
          data: (profile) {
            if (profile == null) {
              return const Center(child: Text('Profile not found'));
            }

            final isAlertsEnabled = profile.orderAlertsEnabled;

            return Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildProfileCard(profile),
                const SizedBox(height: 24),
                _buildSettingsSection(ref, isAlertsEnabled),
                const Spacer(),
                _buildLogoutButton(ref, context),
                const SizedBox(height: 32),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error loading profile: $e')),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Text(
            'Profile & Settings',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: StaffTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(dynamic profile) {
    final name = profile.displayName;
    final email = profile.email;
    final role = profile.role.toString().split('.').last.toUpperCase();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: StaffTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StaffTheme.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            offset: Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: StaffTheme.primary.withOpacity(0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'S',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: StaffTheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: StaffTheme.textPrimary,
                  ),
                ),
                Text(
                  email,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: StaffTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: StaffTheme.background,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: StaffTheme.border),
                  ),
                  child: Text(
                    role,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: StaffTheme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(WidgetRef ref, bool isAlertsEnabled) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: StaffTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StaffTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'SETTINGS',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: StaffTheme.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
          ),
          SwitchListTile(
            title: Text(
              'Order Alerts (Audio)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: StaffTheme.textPrimary,
              ),
            ),
            subtitle: Text(
              'Hear voice announcements for new tokens',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: StaffTheme.textSecondary,
              ),
            ),
            value: isAlertsEnabled,
            activeThumbColor: StaffTheme.primary,
            activeTrackColor: StaffTheme.primary.withOpacity(0.2),
            onChanged: (val) async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .update({'orderAlertsEnabled': val});
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(WidgetRef ref, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () {
            _showLogoutConfirmation(context, ref);
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: BorderSide(color: Colors.red.shade200, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.red.shade50,
          ),
          child: Text(
            'Log Out',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade600,
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: StaffTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: StaffTheme.border),
          ),
          title: Text(
            'Confirm Logout',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: StaffTheme.textPrimary,
            ),
          ),
          content: Text(
            'Are you sure you want to log out of your staff account?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: StaffTheme.textSecondary,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancel',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: StaffTheme.textSecondary,
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: StaffTheme.statusSkipped,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await ref.read(authServiceProvider).signOut();
              },
              child: Text(
                'Log Out',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
