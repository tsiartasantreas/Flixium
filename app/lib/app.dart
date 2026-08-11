import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/netflix_theme.dart';
import 'features/shell/main_shell.dart';

/// Root widget of the Flixium IPTV app.
///
/// On startup the app initializes Supabase, checks the current auth state,
/// and routes to the [MainShell].
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
    // Supabase is NOT initialized at startup — its native Android plugin
    // (supabase_flutter) crashes on Android 16 (Galaxy Fold 5). Initialize
    // lazily only when the user actually signs in. The app works fully in
    // guest mode without any network dependency.
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
    // Always go to main shell — Supabase is initialized lazily when the user
    // signs in, never at startup. No crash on Android 16.
    return const MainShell();
  }
}
