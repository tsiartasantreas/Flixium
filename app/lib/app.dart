import 'package:flutter/material.dart';
import 'core/theme/app_colors.dart';

/// Minimal app — no Supabase, no Drift init, no auth.
/// Just renders the Netflix background to confirm the app launches.
class FlixiumApp extends StatelessWidget {
  const FlixiumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iFlixify IPTV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bgBase,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accentPrimary,
          surface: AppColors.bgBase,
        ),
      ),
      home: const _MinimalHome(),
    );
  }
}

class _MinimalHome extends StatelessWidget {
  const _MinimalHome();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'iFlixify IPTV',
              style: TextStyle(
                color: AppColors.accentPrimary,
                fontSize: 40,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Minimal test build — if you see this, the base app launches.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            SizedBox(height: 24),
            Text(
              'v2.2.0-alpha',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
