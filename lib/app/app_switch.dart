import 'package:flutter/material.dart';

/// Cross-platform switch — Material track themed via [AppTheme], never [Switch.adaptive].
///
/// Slightly scaled so settings rows stay Quiet Utility–dense (default M3 switch reads large).
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  static const _scale = 0.88;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: _scale,
      alignment: Alignment.centerRight,
      child: Switch(
        value: value,
        onChanged: onChanged,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
