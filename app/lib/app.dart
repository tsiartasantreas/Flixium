import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/data/supabase_client.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/netflix_theme.dart';
import 'features/auth/auth_screen.dart';
import 'features/shell/main_shell.dart';

/// Root widget of the iFlixify IPTV app.
///
/// Supabase is NEVER initialized at startup — its native Android plugin
/// (app_links via supabase_flutter) crashes on Android 16. Initialize
/// lazily only when the user explicitly signs in. The app works fully
/// in guest mode without any network dependency.
class FlixiumApp extends StatefulWidget {
  const FlixiumApp({super.key});

  @override
  State<FlixiumApp> createState() => _FlixiumAppState();
}

class _FlixiumAppState extends State<FlixiumApp> {
  bool _initialized = false;
  bool _hasCachedAuth = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Initialize Supabase so auth works on first try.
    try {
      await SupabaseService.initialize();
    } catch (_) {
      // If Supabase fails to initialize (e.g. no network), the app can
      // still run in guest mode.
    }

    final prefs = await SharedPreferences.getInstance();
    final cachedEmail = prefs.getString('auth_user_email');

    // If we have a cached email AND an active Supabase session, the user
    // is already logged in — skip the auth screen.
    if (cachedEmail != null && SupabaseService.isInitialized) {
      final session = SupabaseService.client.auth.currentSession;
      _hasCachedAuth = session != null;
    } else {
      _hasCachedAuth = cachedEmail != null;
    }

    if (mounted) {
      setState(() {
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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

    // If the user previously signed in, go straight to MainShell.
    // Supabase will be lazily initialized on first network action.
    // Otherwise, show the auth screen where the user can sign in or
    // continue as guest.
    return MaterialApp(
      title: 'iFlixify IPTV',
      debugShowCheckedModeBanner: false,
      theme: NetflixTheme.dark,
      home: _hasCachedAuth ? const MainShell() : const AuthScreen(),
    );
  }
}
