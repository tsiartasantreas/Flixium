import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iflixify/core/theme/app_colors.dart';

void main() {
  test('AppColors exposes the Netflix palette (accent reverted to Netflix red)', () {
    expect(AppColors.bgBase, const Color(0xFF141414));
    expect(AppColors.bgElevated, const Color(0xFF181818));
    expect(AppColors.bgSurface, const Color(0xFF222222));
    expect(AppColors.textPrimary, const Color(0xFFFFFFFF));
    expect(AppColors.textSecondary, const Color(0xFFB3B3B3));
    // User-approved change (v5.3.0): accent uses Netflix red directly.
    expect(AppColors.accentPrimary, const Color(0xFFE50914));
  });
}
