import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/network/request_failure.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// Keeps cached content visible while making refresh failures explicit.
class RefreshFeedback extends StatelessWidget {
  const RefreshFeedback({
    super.key,
    required this.child,
    this.error,
    this.updatedAt,
    required this.onRetry,
  });
  final Widget child;
  final Object? error;
  final DateTime? updatedAt;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final at = updatedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpace.pageXOf(context),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      '${requestFailureMessage(error)}；显示上次数据',
                      style: TextStyle(color: p.danger, fontSize: 12),
                    ),
                  ),
                ),
                TextButton(onPressed: onRetry, child: const Text('重试')),
              ],
            ),
          ),
        if (at != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpace.pageXOf(context),
              4,
              AppSpace.pageXOf(context),
              8,
            ),
            child: Text(
              '更新于 ${at.month}/${at.day} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
              style: TextStyle(color: p.muted, fontSize: 11),
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}
