import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// A measured value and its label, without a separate tile for every number.
class AppMetric extends StatelessWidget {
  const AppMetric({super.key, required this.value, required this.label});
  final String value, label;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: p.ink,
            fontSize: 24,
            height: 1.25,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 5),
        Text(label, style: TextStyle(color: p.muted, fontSize: 12)),
      ],
    );
  }
}
