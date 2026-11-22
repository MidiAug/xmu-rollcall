import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// A measured value and its label, without a separate tile for every number.
class AppMetric extends StatelessWidget {
  const AppMetric({
    super.key,
    required this.value,
    required this.label,
    this.valueSize = 24,
    this.valueColor,
    this.inset = false,
  });
  final String value, label;
  final double valueSize;
  final Color? valueColor;
  final bool inset;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: p.muted, fontSize: 12)),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? p.ink,
            fontSize: valueSize,
            height: 1.25,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
    return inset
        ? Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.subWell,
              borderRadius: BorderRadius.circular(AppRadii.subWell),
              border: Border.all(color: p.subWellRim),
            ),
            child: content,
          )
        : content;
  }
}
