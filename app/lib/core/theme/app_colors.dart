import 'package:flutter/material.dart';

/// Netflix-clone color tokens (spec §6.1).
///
/// Every value matches the Netflix palette EXCEPT [accentPrimary], which is the
/// one permitted visual deviation (Netflix red #E50914 → our accent).
class AppColors {
  AppColors._();

  // Backgrounds — identical to Netflix.
  static const Color bgBase = Color(0xFF141414);
  static const Color bgElevated = Color(0xFF181818);
  static const Color bgSurface = Color(0xFF222222);

  // Text — identical to Netflix.
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);

  // The ONE allowed deviation. Netflix uses #E50914; we use a rose-red accent.
  // Value is provisional — locked at the start of P2 (spec §17).
  static const Color accentPrimary = Color(0xFFE11D48);
  static const Color accentHover = Color(0xFFF43F5E);
}
