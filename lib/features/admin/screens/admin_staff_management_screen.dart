import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:qcutapp/core/widgets/app_password_validator.dart';
import '../../../core/providers.dart';
import '../../../app/themes/admin_theme.dart';
import '../widgets/admin_breadcrumbs.dart';

class AdminStaffManagementScreen extends ConsumerStatefulWidget {
  const AdminStaffManagementScreen({super.key});

  @override
  ConsumerState<AdminStaffManagementScreen> createState() =>
      _AdminStaffManagementScreenState();
}

class _AdminStaffManagementScreenState
    extends ConsumerState<AdminStaffManagementScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'Kitchen Staff';
  bool _isAdding = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: AdminTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AdminTheme.textPrimary),
        title: Text(
          'Staff Management',
          style: GoogleFonts.plusJakartaSans(
            color: AdminTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              onPressed: _repairStaffRoles,
              icon: const Icon(Icons.build_outlined, size: 18),
              label: const Text('Repair Staff'),
              style: TextButton.styleFrom(
                foregroundColor: AdminTheme.accentOrange,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: _showAddStaffDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Staff'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(120, 40),
                backgroundColor: AdminTheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: ref.watch(firestoreServiceProvider).usersCollection.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allUsers = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['uid'] = doc.id;
            return data;
          }).toList();

          // Filter for staff roles
          final staffList = allUsers.where((u) {
            final role = u['role']?.toString().toUpperCase() ?? '';
            return role == 'STAFF' ||
                role == 'ADMIN' ||
                role == 'MANAGER' ||
                role == 'KITCHEN_STAFF' ||
                role == 'KITCHEN STAFF';
          }).toList();

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isDesktop ? 32 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AdminBreadcrumbs(
                        items: [
                          AdminBreadcrumbItem(label: 'Home', route: '/admin'),
                          AdminBreadcrumbItem(
                            label: 'Profile & Settings',
                            route: '/admin/profile',
                          ),
                          AdminBreadcrumbItem(label: 'Staff Management'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Staff Management',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildStatRow(staffList),
                      const SizedBox(height: 32),
                      _buildStaffList(staffList),
                    ],
                  ),
                ),
              ),
              _buildBottomBar(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AdminTheme.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            const Spacer(),
            SizedBox(
              width: 200,
              height: 50,
              child: ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Confirm Changes',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(List<Map<String, dynamic>> staff) {
    final activeCount = staff.where((s) => s['status'] == 'Active').length;
    final pendingCount = staff.length - activeCount;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Staff',
            staff.length.toString(),
            Icons.people_outline,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Active Now',
            activeCount.toString(),
            Icons.check_circle_outline,
            color: AdminTheme.success,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Pending Invites',
            pendingCount.toString(),
            Icons.pending_actions,
            color: AdminTheme.accentOrange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color ?? AdminTheme.textPrimary, size: 24),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AdminTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: AdminTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffList(List<Map<String, dynamic>> staffList) {
    if (staffList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminTheme.border),
        ),
        child: Column(
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No staff members found',
              style: GoogleFonts.plusJakartaSans(color: AdminTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTheme.border),
      ),
      child: Column(
        children: [
          ...staffList.map((staff) {
            final isPending = staff['status'] == 'Pending';
            return Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: AdminTheme.primary.withOpacity(0.1),
                    child: Text(
                      (staff['displayName'] ?? staff['name'] ?? 'S')[0],
                      style: GoogleFonts.plusJakartaSans(
                        color: AdminTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    staff['displayName'] ?? staff['name'] ?? 'Unnamed',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      color: AdminTheme.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    '${(staff['staffRole'] ?? staff['role']).toString().replaceAll('_', ' ')} • ${staff['email']}',
                    style: GoogleFonts.plusJakartaSans(
                      color: AdminTheme.textPrimary.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isPending
                              ? AdminTheme.accentOrange.withOpacity(0.1)
                              : AdminTheme.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          staff['status'] ?? 'Active',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isPending
                                ? AdminTheme.accentOrange
                                : AdminTheme.success,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.more_vert, size: 20),
                        onPressed: () => _showStaffActions(staff),
                      ),
                    ],
                  ),
                ),
                if (staff != staffList.last)
                  const Divider(height: 1, color: AdminTheme.border),
              ],
            );
          }),
        ],
      ),
    );
  }

  void _showAddStaffDialog() {
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    final phoneController = TextEditingController();
    _selectedRole = 'Kitchen Staff';
    bool isActive = false;
    bool obscurePassword = true;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxWidth: 420,
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 40,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[100]!),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Add New Staff',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: AdminTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Create an account for a new staff member',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    
                    // Body
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDialogInput(
                              label: 'Full Name',
                              controller: _nameController,
                              hint: 'e.g. John Doe',
                              icon: Icons.person_outline,
                            ),
                            const SizedBox(height: 16),
                            _buildDialogInput(
                              label: 'Email Address',
                              controller: _emailController,
                              hint: 'john@example.com',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 16),
                            _buildDialogInput(
                              label: 'Temporary Password',
                              controller: _passwordController,
                              hint: 'Min 9 characters',
                              icon: Icons.lock_outline,
                                obscureText: obscurePassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    color: Colors.grey[400],
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setDialogState(() => obscurePassword = !obscurePassword);
                                  },
                                ),
                                onChanged: (_) => setDialogState(() {}),
                            ),
                            AppPasswordValidator(password: _passwordController.text),
                            const SizedBox(height: 16),
                            _buildDialogInput(
                               label: 'Phone Number (Optional)',
                               controller: phoneController,
                               hint: '+1 (555) 000-0000',
                               icon: Icons.phone_outlined,
                               keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            // Role Dropdown (preserved from original logic)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                                  child: Text(
                                    'Role',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedRole,
                                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[400]),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey[200]!),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey[200]!),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: AdminTheme.primary, width: 1.5),
                                    ),
                                  ),
                                  items: ['Kitchen Staff', 'Counter Staff', 'Manager', 'Admin'].map((role) {
                                    return DropdownMenuItem(value: role, child: Text(role));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => _selectedRole = val);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Active Toggle
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[100]!),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Set as Active',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AdminTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Enable account immediately',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Switch.adaptive(
                                    value: isActive,
                                    activeThumbColor: AdminTheme.primary,
                                    onChanged: (val) => setDialogState(() => isActive = val),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Footer
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey[600],
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(color: Colors.grey[200]!),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isAdding
                                  ? null
                                  : () async {
                                      final name = _nameController.text.trim();
                                      final email = _emailController.text.trim();
                                      final password = _passwordController.text.trim();
                                      final phone = phoneController.text.trim();
                                      
                                      final isPasswordValid = password.length >= 9 && 
                                                              password.contains(RegExp(r'[A-Z]')) && 
                                                              password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
                                      
                                      if (name.isEmpty || email.isEmpty || !isPasswordValid) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Please fill all required fields correctly (password 9+ chars, 1 caps, 1 special).'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                        return;
                                      }

                                      setDialogState(() => _isAdding = true);

                                      try {
                                        // Check for existing user document by email to prevent duplicates
                                        final existingQuery = await FirebaseFirestore.instance
                                            .collection('users')
                                            .where('email', isEqualTo: email)
                                            .limit(1)
                                            .get();

                                        DocumentReference docRef;
                                        if (existingQuery.docs.isNotEmpty) {
                                          docRef = existingQuery.docs.first.reference;
                                          debugPrint('REPAIR: Updating existing user doc ${docRef.id} for $email');
                                        } else {
                                          docRef = FirebaseFirestore.instance.collection('users').doc();
                                          debugPrint('REPAIR: Creating new user doc ${docRef.id} for $email');
                                        }

                                        await docRef.set({
                                          'displayName': name,
                                          'email': email,
                                          'role': 'staff', // Enforce 'staff' for permissions
                                          'staffRole': _selectedRole.toUpperCase().replaceAll(' ', '_'),
                                          'status': isActive ? 'Active' : 'Pending',
                                          'phone': phone,
                                          'isActive': isActive,
                                          'inviteStatus': isActive ? 'accepted' : 'pending',
                                          'invitedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
                                          'createdAt': FieldValue.serverTimestamp(),
                                          'updatedAt': FieldValue.serverTimestamp(),
                                        }, SetOptions(merge: true));

                                        if (context.mounted) {
                                          Navigator.pop(dialogContext);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(existingQuery.docs.isNotEmpty 
                                                ? 'Staff profile updated for $name.' 
                                                : 'Staff profile created for $name.'),
                                              backgroundColor: AdminTheme.success,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                              backgroundColor: Colors.redAccent,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (context.mounted) setDialogState(() => _isAdding = false);
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AdminTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                                shadowColor: AdminTheme.primary.withValues(alpha: 0.3),
                              ),
                              child: _isAdding
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(
                                      'Create Account',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _repairStaffRoles() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Repair Staff Roles?'),
        content: const Text(
          'This will normalize all staff variants (MANAGER, KITCHEN_STAFF, etc.) '
          'to role: "staff" as required for Firestore permissions. '
          'Descriptive roles will be preserved in a new field. '
          'This will NOT touch Admin or Student accounts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.primary),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      int scanned = 0;
      int changed = 0;
      int skipped = 0;

      final usersSnap = await FirebaseFirestore.instance.collection('users').get();
      scanned = usersSnap.docs.length;

      final normalizedRoles = [
        'KITCHEN_STAFF', 'KITCHEN STAFF', 'MANAGER', 'CASHIER', 
        'CHEF', 'COUNTER_STAFF', 'COUNTER STAFF', 'STAFF'
      ];

      final batch = FirebaseFirestore.instance.batch();
      bool hasChanges = false;

      for (var doc in usersSnap.docs) {
        final data = doc.data();
        final currentRole = (data['role'] as String? ?? '').toUpperCase();
        
        // Skip admins and students explicitly
        if (currentRole == 'ADMIN' || currentRole == 'STUDENT') {
          skipped++;
          continue;
        }

        // Normalize if it's a known variant OR if it's already 'STAFF' but lacks 'staffRole'
        final isStaffVariant = normalizedRoles.contains(currentRole);
        final lacksStaffRole = data['staffRole'] == null;

        if (isStaffVariant && (currentRole != 'STAFF' || lacksStaffRole)) {
          batch.update(doc.reference, {
            'role': 'staff',
            'staffRole': currentRole,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          changed++;
          hasChanges = true;
        } else {
          skipped++;
        }
      }

      if (hasChanges) {
        await batch.commit();
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Repair Complete'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Users Scanned: $scanned'),
                Text('Profiles Normalized: $changed'),
                Text('Skipped (Correct/Admin/Student): $skipped'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Repair failed: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showStaffActions(Map<String, dynamic> staff) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Staff Details'),
              onTap: () {
                Navigator.pop(context);
                _showEditStaffDialog(staff);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Staff member', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteStaff(staff);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showEditStaffDialog(Map<String, dynamic> staff) {
    _nameController.text = staff['displayName'] ?? staff['name'] ?? '';
    _emailController.text = staff['email'] ?? '';
    final phoneController = TextEditingController(text: staff['phone'] ?? '');
    _selectedRole = (staff['staffRole'] ?? staff['role'] ?? 'Kitchen Staff')
        .toString()
        .replaceAll('_', ' ')
        .toLowerCase();
    
    // Capitalize first letters for dropdown match
    _selectedRole = _selectedRole.split(' ').map((str) {
      if (str.isEmpty) return str;
      return str[0].toUpperCase() + str.substring(1);
    }).join(' ');
    
    // Ensure it matches one of the dropdown items
    final validRoles = ['Kitchen Staff', 'Counter Staff', 'Manager', 'Admin'];
    if (!validRoles.contains(_selectedRole)) {
      _selectedRole = 'Kitchen Staff';
    }

    bool isActive = staff['status'] == 'Active' || staff['isActive'] == true;
    bool isUpdating = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxWidth: 420,
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
                      ),
                      child: Text(
                        'Edit Staff Member',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            _buildDialogInput(
                              label: 'Full Name',
                              controller: _nameController,
                              hint: 'Name',
                              icon: Icons.person_outline,
                            ),
                            const SizedBox(height: 16),
                            _buildDialogInput(
                              label: 'Email Address',
                              controller: _emailController,
                              hint: 'Email',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 16),
                            _buildDialogInput(
                              label: 'Phone Number',
                              controller: phoneController,
                              hint: 'Phone',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _selectedRole,
                              decoration: InputDecoration(
                                labelText: 'Role',
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: validRoles.map((role) => DropdownMenuItem(value: role, child: Text(role))).toList(),
                              onChanged: (val) => setDialogState(() => _selectedRole = val!),
                            ),
                            const SizedBox(height: 16),
                            SwitchListTile.adaptive(
                              title: const Text('Active Status'),
                              value: isActive,
                              onChanged: (val) => setDialogState(() => isActive = val),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isUpdating ? null : () async {
                                setDialogState(() => isUpdating = true);
                                try {
                                  await FirebaseFirestore.instance.collection('users').doc(staff['uid']).update({
                                    'displayName': _nameController.text.trim(),
                                    'email': _emailController.text.trim(),
                                    'phone': phoneController.text.trim(),
                                    'staffRole': _selectedRole.toUpperCase().replaceAll(' ', '_'),
                                    'isActive': isActive,
                                    'status': isActive ? 'Active' : 'Pending',
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  });
                                  if (context.mounted) Navigator.pop(dialogContext);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
                                  }
                                } finally {
                                  if (context.mounted) setDialogState(() => isUpdating = false);
                                }
                              },
                              child: isUpdating ? const CircularProgressIndicator() : const Text('Update Account'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteStaff(Map<String, dynamic> staff) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Staff Member?'),
        content: Text('Are you sure you want to remove ${staff['displayName'] ?? staff['name']}? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseFirestore.instance.collection('users').doc(staff['uid']).delete();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff member deleted.')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogInput({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AdminTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey[400]),
            prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AdminTheme.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
