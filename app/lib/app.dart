import 'package:flutter/material.dart';
import 'core/theme/app_colors.dart';
import 'features/shell/main_shell.dart';

class FlixiumApp extends StatelessWidget {
  const FlixiumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flixium IPTV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bgBase,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accentPrimary,
          surface: AppColors.bgBase,
        ),
      ),
      home: const MainShell(),
    );
  }
}
