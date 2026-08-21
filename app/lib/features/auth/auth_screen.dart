import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_service.dart';
import '../../core/data/supabase_client.dart';
import '../../core/data/sync_coordinator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../shell/main_shell.dart';

/// Netflix-style sign-in / sign-up screen.
///
/// Toggles between two modes (sign-in and sign-up) with a single form.
/// A "Continue as Guest" option lets users skip authentication entirely.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.authService, this.initialSignUp = false});

  /// Injectable for testing.
  final AuthService? authService;

  /// When true, the screen starts in sign-up mode instead of sign-in.
  final bool initialSignUp;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  String? _error;
  bool _showResendConfirmation = false;

  AuthService get _auth => widget.authService ?? AuthService();

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialSignUp;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

    if (result.needsEmailConfirmation) {
      // Supabase created the user but requires email confirmation.
      // Show a message and stay on the auth screen — do NOT navigate away.
      setState(() {
        _error = null;
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please check your email to confirm your account before signing in.',
          ),
          duration: Duration(seconds: 6),
        ),
      );
      // Switch to sign-in mode so the user can sign in after confirming.
      setState(() {
        _isSignUp = false;
      });
    } else if (result.isSuccess) {
      // Persist the auth flag so the app skips the auth screen on next launch.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_user_email', email);
      if (!mounted) return;

      // Sync favourites and watch progress from the cloud so the user's
      // data is available immediately after sign-in (especially important
      // when signing in on a new device or after sign-out).
      unawaited(SyncCoordinator.maybeFullSync());

      // Pop back to the caller (Settings) which reloads user state.
      // If the auth screen was launched standalone (not pushed from
      // Settings), fall back to replacing with MainShell.
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        _navigateToHome();
      }
    } else {
      final rawError = result.error ?? 'Authentication failed. Please try again.';
      // Provide a clearer message for common Supabase auth errors.
      final friendlyError = _friendlyAuthError(rawError);
      final isEmailNotConfirmed = rawError.toLowerCase().contains('not confirmed');
      setState(() {
        _error = friendlyError;
        _isLoading = false;
        _showResendConfirmation = isEmailNotConfirmed;
      });
    }
  }

  void _continueAsGuest() {
    _navigateToHome();
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    String? dialogError;
    bool dialogLoading = false;
    bool sent = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.bgElevated,
              title: const Text(
                'Reset Password',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!sent) ...[
                    const Text(
                      'Enter your email and we will send you a password reset link.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: AppColors.bgBase,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ] else ...[
                    const Icon(
                      Icons.mark_email_read,
                      size: 48,
                      color: Colors.greenAccent,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Password reset email sent! Check your inbox.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  if (dialogError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      dialogError!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    sent ? 'Done' : 'Cancel',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                if (!sent)
                  ElevatedButton(
                    onPressed: dialogLoading
                        ? null
                        : () async {
                            final email = emailController.text.trim();
                            if (email.isEmpty || !email.contains('@')) {
                              setDialogState(() {
                                dialogError = 'Please enter a valid email.';
                              });
                              return;
                            }

                            setDialogState(() {
                              dialogLoading = true;
                              dialogError = null;
                            });

                            // Ensure Supabase is initialized.
                            if (!SupabaseService.isInitialized) {
                              try {
                                await SupabaseService.initialize();
                              } catch (e) {
                                setDialogState(() {
                                  dialogLoading = false;
                                  dialogError =
                                      'Failed to connect. Check your internet.';
                                });
                                return;
                              }
                            }

                            try {
                              // IMPORTANT: The redirectTo URL must also be added
                              // in the Supabase Dashboard under:
                              //   Authentication > URL Configuration > Redirect URLs
                              //   Add: https://iflixify.wasmer.app/reset-password
                              await SupabaseService.client.auth
                                  .resetPasswordForEmail(
                                email,
                                redirectTo:
                                    'https://iflixify.wasmer.app/reset-password',
                              );
                              setDialogState(() {
                                sent = true;
                                dialogLoading = false;
                              });
                            } catch (e) {
                              final msg = e is AuthException
                                  ? e.message
                                  : 'Could not send reset email. Please try again.';
                              setDialogState(() {
                                dialogLoading = false;
                                dialogError = msg;
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentPrimary,
                      foregroundColor: AppColors.textPrimary,
                    ),
                    child: dialogLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textPrimary,
                            ),
                          )
                        : const Text('Send Reset Link'),
                  ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();
  }

  Future<void> _resendConfirmationEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _error = 'Please enter your email address first.';
      });
      return;
    }

    setState(() => _isLoading = true);

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

    try {
      await SupabaseService.client.auth.resend(
        type: OtpType.signup,
        email: email,
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _showResendConfirmation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Confirmation email sent! Check your inbox.'),
          duration: Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not send confirmation email. Please try again.';
        _isLoading = false;
      });
    }
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.live_tv,
                  size: 64,
                  color: AppColors.accentPrimary,
                ),
                SizedBox(height: 16),
                Text(
                  'iFlixify IPTV',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.accentPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                  ),
                ),
              ],
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
              child: Column(
                children: [
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_showResendConfirmation) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 36,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _resendConfirmationEmail,
                        icon: const Icon(Icons.email_outlined, size: 16),
                        label: const Text(
                          'Resend Confirmation Email',
                          style: TextStyle(fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentPrimary,
                          foregroundColor: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
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

          // Forgot password link (sign-in only).
          if (!_isSignUp) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading ? null : _showForgotPasswordDialog,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: AppColors.accentPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],

          // Confirm password field (sign-up only).
          if (_isSignUp) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: _inputDecoration('Confirm Password'),
              validator: (value) {
                if (!_isSignUp) return null;
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
          ],

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
                      _showResendConfirmation = false;
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

  /// Converts raw Supabase auth error messages into user-friendly text.
  String _friendlyAuthError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid credentials') ||
        lower.contains('user not found')) {
      return 'Invalid email or password. Please check your credentials or sign up.';
    }
    if (lower.contains('email not confirmed') ||
        lower.contains('not confirmed')) {
      return 'Please confirm your email address first. Check your inbox for a confirmation link.';
    }
    if (lower.contains('user already registered') ||
        lower.contains('already been registered') ||
        lower.contains('already registered')) {
      return 'An account with this email already exists. Try signing in instead.';
    }
    if (lower.contains('signup') || lower.contains('sign up')) {
      return 'Registration failed. Please check your details and try again.';
    }
    if (lower.contains('weak password') || lower.contains('password')) {
      return 'Password is too weak. Please use a stronger password.';
    }
    if (lower.contains('invalid email') || lower.contains('unable to validate email')) {
      return 'Please enter a valid email address.';
    }
    if (lower.contains('network') || lower.contains('connection')) {
      return 'Network error. Please check your internet connection.';
    }
    if (lower.contains('too many') || lower.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    // Return the original message if we don't have a friendlier version.
    return raw;
  }

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
