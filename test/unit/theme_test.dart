import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

void main() {
  test('dark theme uses SoulLog primary not Material purple', () {
    final theme = AppTheme.dark();
    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.colorScheme.primary, isNot(const Color(0xFF6750A4)));
    expect(theme.scaffoldBackgroundColor, AppColors.canvas);
  });
}
