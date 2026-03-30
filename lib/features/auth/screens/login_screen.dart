import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/app_message.dart';
import '../../../core/widgets/app_password_validator.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _idEmailController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _idEmailController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isPasswordValid(String password) {
    if (password.length < 9) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return false;
    return true;
  }

  Future<void> _handleLogin() async {
    final idEmail = _idEmailController.text.trim();
    final password = _passwordController.text;

    if (idEmail.isEmpty || password.isEmpty) {
      showAppMessage(context, 'Please fill in all fields');
      return;
    }

    if (!_isPasswordValid(password)) {
      showAppMessage(
        context,
        'Password must be 9+ characters, include 1 uppercase and 1 special character',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String loginEmail = '';
      if (idEmail.contains('@')) {
        loginEmail = idEmail;
      } else {
        final extraEmail = _emailController.text.trim();
        if (extraEmail.isEmpty) {
          showAppMessage(context, 'Email is required for ID-based login');
          setState(() => _isLoading = false);
          return;
        }
        loginEmail = extraEmail;
      }

      await ref
          .read(authServiceProvider)
          .signIn(email: loginEmail, password: password);
    } catch (e) {
      if (mounted) {
        String message = 'Login failed';
        final errStr = e.toString().toLowerCase();
        
        if (errStr.contains('permission-denied') || 
            errStr.contains('invalid-credential') ||
            errStr.contains('wrong-password') ||
            errStr.contains('user-not-found')) {
          message = 'Incorrect student ID or password';
        } else if (errStr.contains('network-request-failed')) {
          message = 'Network error. Please check your connection.';
        } else if (errStr.contains('too-many-requests')) {
          message = 'Too many attempts. Please try again later.';
        } else {
          message = 'An unexpected error occurred. Please try again.';
        }
        
        showAppMessage(context, message);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          children: [
            const SizedBox(height: 100),
            Image.asset(
              'assets/icon/noq_logo.png',
              height: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            Text(
              'Welcome to noq',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: theme.primaryColor,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Login to order your favorite campus meals',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                color: theme.textTheme.bodySmall?.color ?? Colors.grey,
              ),
            ),
            const SizedBox(height: 40),
            _buildFieldLabel('Student Email or ID', theme),
            const SizedBox(height: 8),
            TextField(
              controller: _idEmailController,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: const InputDecoration(
                hintText: 'e.g. 20248592 or student@college.edu',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 20),
            _buildFieldLabel('Password', theme),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            AppPasswordValidator(password: _passwordController.text),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/forgot-password'),
                child: Text(
                  'Forgot Password?',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Login'),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account? ",
                  style: GoogleFonts.plusJakartaSans(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push('/signup'),
                  child: Text(
                    'Sign Up',
                    style: GoogleFonts.plusJakartaSans(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, ThemeData theme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: theme.primaryColor,
        ),
      ),
    );
  }
}
