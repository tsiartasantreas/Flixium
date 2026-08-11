import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/data/supabase_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../shell/main_shell.dart';

/// Netflix-style sign-in / sign-up screen.
///
/// Toggles between two modes (sign-in and sign-up) with a single form.
/// A "Continue as Guest" option lets users skip authentication entirely.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.authService});

  /// Injectable for testing.
  final AuthService? authService;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  String? _error;

  AuthService get _auth => widget.authService ?? AuthService();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Password validation
  // ---------------------------------------------------------------------------

  bool get _hasMinLength => _passwordController.text.length >= 8;
  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_passwordController.text);
  bool get _hasLowercase => RegExp(r'[a-z]').hasMatch(_passwordController.text);
  bool get _hasDigit => RegExp(r'[0-9]').hasMatch(_passwordController.text);
  bool get _hasSpecialChar => RegExp(r'[!@#$%^&*(),.?":{}|<>\-_=+\[\]\\\/~`]').hasMatch(_passwordController.text);

  /// Returns null when valid, or an error string for the form validator.
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (!_isSignUp) {
      // Sign-in: only require non-empty.
      return null;
    }
    if (!_hasMinLength) return 'Password must be at least 8 characters';
    if (!_hasUppercase) return 'Password must contain at least 1 uppercase letter';
    if (!_hasLowercase) return 'Password must contain at least 1 lowercase letter';
    if (!_hasDigit) return 'Password must contain at least 1 number';
    if (!_hasSpecialChar) return 'Password must contain at least 1 special character';
    return null;
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Ensure Supabase is initialized before attempting auth.
    // Supabase is lazy (not at app startup) to avoid native plugin crash on Android 16.
    if (!SupabaseService.isInitialized) {
      try {
        await SupabaseService.initialize();
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = 'Failed to connect. Please check your internet.';
          _isLoading = false;
        });
        return;
      }
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final result = _isSignUp
        ? await _auth.signUp(email, password, name: _nameController.text.trim())
        : await _auth.signIn(email, password);

    if (!mounted) return;

    if (result.isSuccess) {
      _navigateToHome();
    } else {
      setState(() {
        _error = result.error ?? 'Authentication failed. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _continueAsGuest() {
    _navigateToHome();
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.horizontalPadding,
            ),
            child: _buildAuthForm(),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Auth form
  // ---------------------------------------------------------------------------

  Widget _buildAuthForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo / branding.
          const Icon(
            Icons.live_tv,
            size: 64,
            color: AppColors.accentPrimary,
          ),
          const SizedBox(height: 16),
          const Text(
            'FLIXIUM',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 32),

          // Error banner.
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Name field (sign-up only).
          if (_isSignUp) ...[
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: _inputDecoration('Name'),
              validator: (value) {
                if (!_isSignUp) return null;
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
          ],

          // Email field.
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: _inputDecoration('Email'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password field.
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: _inputDecoration('Password'),
            validator: _validatePassword,
            onChanged: (_) => setState(() {}), // Refresh checklist.
            onFieldSubmitted: (_) => _submit(),
          ),

          // Password requirements checklist (sign-up only).
          if (_isSignUp) ...[
            const SizedBox(height: 12),
            _buildPasswordRequirements(),
          ],

          const SizedBox(height: 24),

          // Submit button.
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentPrimary,
                foregroundColor: AppColors.textPrimary,
                disabledBackgroundColor:
                    AppColors.accentPrimary.withValues(alpha: 0.5),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textPrimary,
                      ),
                    )
                  : Text(
                      _isSignUp ? 'Create Account' : 'Sign In',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Toggle sign-in / sign-up.
          TextButton(
            onPressed: _isLoading
                ? null
                : () => setState(() {
                      _isSignUp = !_isSignUp;
                      _error = null;
                    }),
            child: Text(
              _isSignUp
                  ? 'Already have an account? Sign In'
                  : "Don't have an account? Sign Up",
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Divider.
          Row(
            children: [
              const Expanded(
                child: Divider(color: AppColors.bgSurface),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'OR',
                  style: TextStyle(
                    color: AppColors.textSecondary
                        .withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Expanded(
                child: Divider(color: AppColors.bgSurface),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Guest button.
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: _isLoading ? null : _continueAsGuest,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.bgSurface),
              ),
              child: const Text(
                'Continue as Guest',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Password requirements checklist
  // ---------------------------------------------------------------------------

  Widget _buildPasswordRequirements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _requirementRow('At least 8 characters', _hasMinLength),
        _requirementRow('At least 1 uppercase letter (A-Z)', _hasUppercase),
        _requirementRow('At least 1 lowercase letter (a-z)', _hasLowercase),
        _requirementRow('At least 1 number (0-9)', _hasDigit),
        _requirementRow('At least 1 special character (!@#\$...)', _hasSpecialChar),
      ],
    );
  }

  Widget _requirementRow(String label, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: met ? Colors.greenAccent : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: met ? Colors.greenAccent : AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.bgElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: AppColors.accentPrimary),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
