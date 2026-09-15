/// Hybrid design tokens: DSH surfaces + SoulLog primary/accent.
library;

import 'package:flutter/material.dart';

abstract final class AppColors {
  static const canvas = Color(0xFF151517);
  static const surface = Color(0xFF2C2C2E);
  static const surfaceHigh = Color(0xFF353638);
  static const content = Color(0xFF18191C);
  static const primary = Color(0xFF3C74C4);
  static const accent = Color(0xFFE67E22);
  static const ink = Color(0xFFF9FAFB);
  static const muted = Color(0xFFADB2B8);
  static const danger = Color(0xFFF25A5A);
  static const border = Color(0x14FFFFFF);
  static const borderStrong = Color(0x1FFFFFFF);

  // Light
  static const canvasLight = Color(0xFFF5F5F7);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const contentLight = Color(0xFFF8F9FA);
  static const inkLight = Color(0xFF1C1C1E);
  static const mutedLight = Color(0xFF6B7280);
  static const primaryLight = Color(0xFF3B82F6);
}

abstract final class AppRadii {
  static const input = 10.0;
  static const card = 12.0;
  static const button = 18.0;
  static const dialog = 24.0;
}

abstract final class AppLayout {
  static const shellBreakpoint = 600.0;
  static const sidebarWidth = 232.0;
  static const railExtendedWidth = 200.0;
  static const navItemHeight = 40.0;
}
