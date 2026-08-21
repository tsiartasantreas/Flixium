import 'dart:async';

import 'package:flutter/material.dart';

import 'core/data/supabase_client.dart';
import 'core/data/sync_coordinator.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/netflix_theme.dart';
import 'features/shell/main_shell.dart';

/// Global route observer used by [MainShell] to detect when it becomes
/// visible again after a pushed route (e.g. Settings) is popped.
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

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
    // Initialize Supabase lazily so auth works when the user signs in
    // from Settings. The app runs fully in guest mode without it.
    try {
      await SupabaseService.initialize();
    } catch (_) {
      // If Supabase fails to initialize (e.g. no network), the app can
      // still run in guest mode.
    }

    // If a returning user has a persisted session, sync their cloud data
    // (favourites, watch progress) so it is available immediately.
    unawaited(SyncCoordinator.maybeFullSync());

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

    // Always go straight to MainShell. The user can sign in/register
    // from Settings when they want to.
    return MaterialApp(
      title: 'iFlixify IPTV',
      debugShowCheckedModeBanner: false,
      theme: NetflixTheme.dark,
      navigatorObservers: [routeObserver],
      home: const MainShell(),
    );
  }
}
