import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:qcutapp/app/app_routes.dart';
import '../../../core/providers.dart';
import '../../../app/themes/admin_theme.dart';

class AdminCanteenDetailsScreen extends ConsumerStatefulWidget {
  const AdminCanteenDetailsScreen({super.key});

  @override
  ConsumerState<AdminCanteenDetailsScreen> createState() =>
      _AdminCanteenDetailsScreenState();
}

class _AdminCanteenDetailsScreenState
    extends ConsumerState<AdminCanteenDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _openTimeController = TextEditingController();
  final _closeTimeController = TextEditingController();
  bool _isOpenToday = true;
  bool _isSaving = false;
  bool _isLoading = true;
  String? _logoUrl;       // current logo URL from Firestore
  bool _isUploadingLogo = false;

  @override
  void initState() {
    super.initState();
    _loadCanteenData();
  }

  Future<void> _loadCanteenData() async {
    try {
      final canteen = await ref.read(canteenProvider.future).timeout(const Duration(seconds: 5));
      if (canteen != null) {
        _nameController.text = canteen.name;
        _emailController.text = canteen.email;
        _phoneController.text = canteen.phone;
        _addressController.text = canteen.address;
        _openTimeController.text = canteen.openTime;
        _closeTimeController.text = canteen.closeTime;
        _isOpenToday = canteen.isOpenToday;
        _logoUrl = canteen.logoUrl;
      }
    } catch (e) {
      debugPrint('Error loading canteen data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load canteen details. $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final data = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'openTime': _openTimeController.text.trim(),
        'closeTime': _closeTimeController.text.trim(),
        'isOpenToday': _isOpenToday,
        if (_logoUrl != null) 'logoUrl': _logoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await ref.read(firestoreServiceProvider).updateCanteen('default', data);

      // Invalidate the provider to refresh the dashboard title immediately
      ref.invalidate(canteenProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Canteen details saved successfully.'),
            backgroundColor: AdminTheme.success,
          ),
        );
        context.pop(); // Go back after success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving details: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _openTimeController.dispose();
    _closeTimeController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _isUploadingLogo = true);
    try {
      final file = File(picked.path);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('canteens/default/logo.jpg');
      final uploadTask = await storageRef.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await uploadTask.ref.getDownloadURL();

      // Immediately persist to Firestore
      await ref.read(firestoreServiceProvider).updateCanteen('default', {
        'logoUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      ref.invalidate(canteenProvider);

      if (mounted) {
        setState(() => _logoUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo uploaded successfully!'),
            backgroundColor: AdminTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AdminTheme.primary),
        ),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width > 900;
    final bgColor = const Color(0xFFF9FAFB);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go(AppRoutes.adminDashboard),
                icon: const Icon(Icons.arrow_back, color: AdminTheme.textPrimary),
              ),
              title: Text(
                'Canteen Configuration',
                style: GoogleFonts.plusJakartaSans(
                  color: AdminTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              centerTitle: true,
            ),
      bottomNavigationBar: !isDesktop
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: _isSaving
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminTheme.success, // Changed from AdminTheme.primary
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Save Changes',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            )
          : null,
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isDesktop ? 48 : 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1024), // max-w-5xl
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isDesktop) _buildDesktopHeader(context),
                  const SizedBox(height: 32),
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 1,
                          child: _buildLeftColumn(),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          flex: 2,
                          child: _buildRightColumn(isDesktop),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLeftColumn(),
                        const SizedBox(height: 24),
                        _buildRightColumn(isDesktop),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRoutes.adminDashboard),
          icon: const Icon(Icons.arrow_back_rounded, size: 28),
          color: AdminTheme.textPrimary,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Settings',
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey[500]),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  'Canteen Details',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AdminTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Canteen Configuration',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: AdminTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Manage your canteen's public information and operating hours.",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        Row(
          children: [
            OutlinedButton(
              onPressed: () => context.pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[600],
                side: BorderSide(color: Colors.grey[200]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 12),
            _isSaving
                ? const SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : ElevatedButton.icon(
                    onPressed: _saveChanges,
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: Text(
                      'Save Changes',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      elevation: 4,
                      shadowColor: AdminTheme.primary.withValues(alpha: 0.4),
                    ),
                  ),
          ],
        ),
      ],
    );
  }

  Widget _buildLeftColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Canteen Logo',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AdminTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _isUploadingLogo ? null : _pickAndUploadLogo,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 2,
                              ),
                              image: _logoUrl != null && !_isUploadingLogo
                                  ? DecorationImage(
                                      image: NetworkImage(_logoUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _isUploadingLogo
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: AdminTheme.primary,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : _logoUrl == null
                                    ? Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_photo_alternate_rounded,
                                            size: 40,
                                            color: Colors.grey[300],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Upload Logo',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey[400],
                                            ),
                                          ),
                                        ],
                                      )
                                    : null,
                          ),
                          // Edit overlay badge when logo exists
                          if (_logoUrl != null && !_isUploadingLogo)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AdminTheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _isUploadingLogo ? null : _pickAndUploadLogo,
                      icon: const Icon(Icons.photo_library_outlined, size: 16),
                      label: Text(
                        _logoUrl == null ? 'Choose from Gallery' : 'Change Logo',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Recommended: 500×500px.\nJPG or PNG.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue[100]!.withValues(alpha: 0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_rounded, color: Colors.blue[500], size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Public Visibility',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Changes made here will be instantly reflected on the student ordering app. Please ensure all contact details are accurate.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.blue[600]!.withValues(alpha: 0.8),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightColumn(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.storefront_rounded, color: Colors.grey[400], size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'General Information',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AdminTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildTextField(
                'Canteen Name',
                'e.g. Main Block Canteen',
                controller: _nameController,
                validator: (v) => v!.isEmpty ? 'Name required' : null,
              ),
              const SizedBox(height: 20),
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField(
                        'Phone Number',
                        '+1 (555) 000-0000',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        icon: Icons.phone_rounded,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildTextField(
                        'Email Address',
                        'admin@school.com',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        icon: Icons.email_rounded,
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    _buildTextField(
                      'Phone Number',
                      '+1 (555) 000-0000',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      icon: Icons.phone_rounded,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      'Email Address',
                      'admin@school.com',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      icon: Icons.email_rounded,
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              _buildTextField(
                'Full Address',
                'Enter full address',
                controller: _addressController,
                maxLines: 3,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, color: Colors.grey[400], size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Operating Hours',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AdminTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'Open Today',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Switch(
                        value: _isOpenToday,
                        onChanged: (v) => setState(() => _isOpenToday = v),
                        activeThumbColor: Colors.green,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTimeField(
                        'Opening Time',
                        _openTimeController,
                        'Time when students can start placing orders.',
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: _buildTimeField(
                        'Closing Time',
                        _closeTimeController,
                        'Last order acceptance time.',
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    _buildTimeField(
                      'Opening Time',
                      _openTimeController,
                      'Time when students can start placing orders.',
                    ),
                    const SizedBox(height: 20),
                    _buildTimeField(
                      'Closing Time',
                      _closeTimeController,
                      'Last order acceptance time.',
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lunch Break Closure',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AdminTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Temporarily stop orders during break',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AdminTheme.primary,
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Text(
                        'Configure',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    String hint, {
    TextEditingController? controller,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            color: AdminTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey[400]),
            prefixIcon: icon != null
                ? Icon(icon, size: 20, color: Colors.grey[400])
                : null,
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: maxLines > 1 ? 16 : 0,
            ),
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
              borderSide: BorderSide(
                color: AdminTheme.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeField(
      String label, TextEditingController controller, String helperText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
            );
            if (time != null) {
              if (mounted) {
                controller.text = time.format(context);
              }
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    controller.text.isEmpty ? 'HH:MM' : controller.text,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: controller.text.isEmpty
                          ? Colors.grey[400]
                          : AdminTheme.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.access_time_rounded,
                  size: 20,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          helperText,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }
}

