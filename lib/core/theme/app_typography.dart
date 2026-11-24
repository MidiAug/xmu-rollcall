import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

abstract final class AppTypography {
  static String? get family => switch (defaultTargetPlatform) {
    TargetPlatform.windows => 'Microsoft YaHei UI',
    TargetPlatform.macOS || TargetPlatform.iOS => 'PingFang SC',
    TargetPlatform.android => null,
    _ => 'Noto Sans CJK SC',
  };
  static const fallback = [
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'PingFang SC',
    'Noto Sans CJK SC',
    'Segoe UI',
    'Roboto',
  ];
  static List<String>? get fallbackForPlatform =>
      family == null ? null : fallback;
  static TextStyle get pageTitle => TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallbackForPlatform,
    fontSize: 26,
    height: 1.28,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  static TextStyle get cardTitle => TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallbackForPlatform,
    fontSize: 20,
    height: 1.4,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  static TextStyle get sectionTitle => TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallbackForPlatform,
    fontSize: 16,
    height: 1.4,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  static TextStyle get body => TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallbackForPlatform,
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
  static TextStyle get control =>
      body.copyWith(fontSize: 13, fontWeight: FontWeight.w500, height: 1.4);
  static TextStyle get caption => body.copyWith(fontSize: 12, height: 1.45);
}
