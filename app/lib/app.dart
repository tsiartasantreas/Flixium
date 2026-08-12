import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    // No Supabase init at startup — app launches instantly in guest mode.
    // Auth is only triggered when the user explicitly signs in.
    // Check if the user previously signed in (cached flag from SharedPreferences).
    final prefs = await SharedPreferences.getInstance();
    _hasCachedAuth = prefs.getString('auth_user_email') != null;

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
