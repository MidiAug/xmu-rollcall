import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

void main() {
  test('dark theme uses muted steel primary not Material purple', () {
    final theme = AppTheme.dark();
    expect(theme.colorScheme.primary, AppPalette.darkPalette.primary);
    expect(theme.colorScheme.primary, isNot(const Color(0xFF6750A4)));
    expect(theme.scaffoldBackgroundColor, AppPalette.darkPalette.canvas);
  });

  test('light theme swaps canvas and content backgrounds', () {
    final theme = AppTheme.light();
    expect(theme.scaffoldBackgroundColor, AppPalette.lightPalette.canvas);
    expect(theme.colorScheme.surface, AppPalette.lightPalette.surface);
    expect(theme.scaffoldBackgroundColor, isNot(AppPalette.darkPalette.canvas));
  });
}
