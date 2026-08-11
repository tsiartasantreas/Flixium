import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/netflix_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // No Supabase init at startup — app launches instantly in guest mode.
    // Auth is only triggered when the user explicitly signs in.
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

    // Always go to main shell — auth handled in settings/auth screen.
    return MaterialApp(
      title: 'iFlixify IPTV',
      debugShowCheckedModeBanner: false,
      theme: NetflixTheme.dark,
      home: const MainShell(),
    );
  }
}
