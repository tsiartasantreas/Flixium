import 'package:flutter/material.dart';

import 'core/config/env.dart';
import 'core/data/supabase_client.dart';
import 'core/entitlement/entitlement_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/netflix_theme.dart';
import 'features/auth/auth_screen.dart';
import 'features/shell/main_shell.dart';

/// Root widget of the Flixium IPTV app.
///
/// On startup the app initializes Supabase, checks the current auth state,
/// and routes to either the [AuthScreen] or [MainShell].
class FlixiumApp extends StatefulWidget {
  const FlixiumApp({super.key});

  @override
  State<FlixiumApp> createState() => _FlixiumAppState();
}

class _FlixiumAppState extends State<FlixiumApp> {
  bool _initialized = false;
  bool _authChecked = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Initialize Supabase if credentials are configured.
    if (Env.isConfigured) {
      try {
        await SupabaseService.initialize();
        // Refresh entitlement tier on app start.
        await EntitlementService().refreshTier();
      } catch (_) {
        // If Supabase init fails, the app still works in guest mode.
      }
    }

    if (mounted) {
      setState(() {
        _initialized = true;
        _authChecked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Splash / loading state while Supabase initializes.
    if (!_initialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: NetflixTheme.dark,
        home: const Scaffold(
          backgroundColor: AppColors.bgBase,
          body: Center(
            child: CircularProgressIndicator(color: AppColors.accentPrimary),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'iFlixify IPTV',
      debugShowCheckedModeBanner: false,
      theme: NetflixTheme.dark,
      home: _authChecked ? _buildHome() : const MainShell(),
    );
  }

  Widget _buildHome() {
    // If Supabase is configured and initialized, check auth state.
    // If Supabase failed to init, skip to main shell (guest mode).
    if (Env.isConfigured && SupabaseService.isInitialized) {
      try {
        if (SupabaseService.auth.currentUser != null) {
          return const MainShell();
        }
      } catch (_) {
        // Supabase auth check failed — continue as guest.
      }
    }
    return const MainShell();
  }
}
