import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../app/themes/student_theme.dart';
import '../../../core/providers.dart';

class StudentEditProfileScreen extends ConsumerStatefulWidget {
  const StudentEditProfileScreen({super.key});

  @override
  ConsumerState<StudentEditProfileScreen> createState() =>
      _StudentEditProfileScreenState();
}

class _StudentEditProfileScreenState
    extends ConsumerState<StudentEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _studentIdController;
  late TextEditingController _deptController;
  late TextEditingController _yearController;
  bool _isLoading = false;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider).value;
    _nameController = TextEditingController(text: profile?.displayName ?? '');
    _studentIdController = TextEditingController(
      text: profile?.studentId ?? '',
    );
    _deptController = TextEditingController(text: profile?.department ?? '');
    _yearController = TextEditingController(text: profile?.year ?? '');
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 75,
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _studentIdController.dispose();
    _deptController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        final Map<String, dynamic> updateData = {
          'displayName': _nameController.text.trim(),
          'studentId': _studentIdController.text.trim(),
          'department': _deptController.text.trim(),
          'year': _yearController.text.trim(),
        };

        if (_imageFile != null) {
          final imageUrl = await ref.read(firestoreServiceProvider).uploadProfileImage(
                _imageFile!,
                user.uid,
              );
          updateData['imageUrl'] = imageUrl;
        }

        await ref.read(firestoreServiceProvider).updateUserProfile(user.uid, updateData);

        ref.invalidate(userProfileProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Profile updated successfully',
                style: GoogleFonts.lexend(),
              ),
              backgroundColor: StudentTheme.statusGreen,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error updating profile: $e',
              style: GoogleFonts.lexend(),
            ),
            backgroundColor: StudentTheme.statusRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StudentTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: StudentTheme.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.splineSans(
            fontWeight: FontWeight.w700,
            fontSize: 24,
            color: StudentTheme.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 180),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Image from Stitch
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: StudentTheme.surfaceVariant, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Container(
                            color: StudentTheme.surfaceVariant,
                            child: _imageFile != null
                                ? Image.file(_imageFile!, fit: BoxFit.cover)
                                : (ref.watch(userProfileProvider).value?.imageUrl?.isNotEmpty ?? false)
                                    ? Image.network(
                                        ref.watch(userProfileProvider).value!.imageUrl!,
                                        fit: BoxFit.cover,
                                      )
                                    : const Icon(
                                        Icons.person_rounded,
                                        size: 64,
                                        color: StudentTheme.primaryOrange,
                                      ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: StudentTheme.primaryOrange,
                                shape: BoxShape.circle,
                                border: Border.all(color: StudentTheme.background, width: 4),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  _buildEditField(
                    label: 'Full Name',
                    controller: _nameController,
                    hint: 'Enter your full name',
                    icon: Icons.person_outline_rounded,
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 24),

                  _buildEditField(
                    label: 'Student ID',
                    controller: _studentIdController,
                    hint: 'Enter Student ID',
                    icon: Icons.badge_outlined,
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Student ID is required' : null,
                  ),
                  const SizedBox(height: 24),

                  _buildEditField(
                    label: 'Department / Major',
                    controller: _deptController,
                    hint: 'e.g. Computer Science',
                    icon: Icons.school_outlined,
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Department is required' : null,
                  ),
                  const SizedBox(height: 24),

                  _buildEditField(
                    label: 'Year / Semester',
                    controller: _yearController,
                    hint: 'e.g. 3rd Year',
                    icon: Icons.date_range_outlined,
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Year is required' : null,
                  ),
                  const SizedBox(height: 24),

                  // Email (Read-only as per typical profile UIs or as hint)
                  _buildEditField(
                    label: 'Email Address',
                    controller: TextEditingController(text: ref.read(userProfileProvider).value?.email ?? ''),
                    hint: 'student@university.edu',
                    icon: Icons.mail_outline_rounded,
                    enabled: false,
                  ),
                  const SizedBox(height: 48),

                  // Save Changes Button (Inside scrollable content)
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: StudentTheme.primaryOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0, // Simplified for inline
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Save Changes',
                              style: GoogleFonts.splineSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.splineSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: StudentTheme.textTertiary,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          enabled: enabled,
          style: GoogleFonts.splineSans(
            color: enabled ? StudentTheme.textPrimary : StudentTheme.textTertiary,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.splineSans(color: StudentTheme.textTertiary.withValues(alpha: 0.5)),
            prefixIcon: Icon(icon, color: StudentTheme.textTertiary, size: 20),
            filled: true,
            fillColor: StudentTheme.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 20),
            errorStyle: GoogleFonts.splineSans(fontSize: 12),
          ),
          validator: validator,
        ),
      ],
    );
  }
}

