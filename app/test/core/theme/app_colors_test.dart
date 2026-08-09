import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixium/core/theme/app_colors.dart';

void main() {
  test('AppColors exposes the Netflix-base palette with the accent deviation', () {
    expect(AppColors.bgBase, const Color(0xFF141414));
    expect(AppColors.bgElevated, const Color(0xFF181818));
    expect(AppColors.bgSurface, const Color(0xFF222222));
    expect(AppColors.textPrimary, const Color(0xFFFFFFFF));
    expect(AppColors.textSecondary, const Color(0xFFB3B3B3));
    // The ONE allowed deviation: Netflix red #E50914 → our accent #E11D48.
    expect(AppColors.accentPrimary.toARGB32(), isNot(const Color(0xFFE50914).toARGB32()));
    expect(AppColors.accentPrimary, const Color(0xFFE11D48));
    expect(AppColors.accentHover, const Color(0xFFF43F5E));
  });
}
