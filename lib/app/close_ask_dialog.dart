import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

enum CloseAskAction { tray, quit }

class CloseAskResult {
  const CloseAskResult({required this.action, required this.remember});

  final CloseAskAction action;
  final bool remember;
}

/// Close-window ask (sports `close-ask` parity). Returns null if dismissed.
Future<CloseAskResult?> showCloseAskDialog(
  BuildContext context, {
  required bool busy,
  required bool rememberDefaultChecked,
}) {
  return showDialog<CloseAskResult>(
    context: context,
    barrierDismissible: !busy,
    barrierColor: Colors.black.withValues(alpha: 0.48),
    builder: (ctx) => _CloseAskDialog(
      busy: busy,
      rememberDefaultChecked: rememberDefaultChecked,
    ),
  );
}

class _CloseAskDialog extends StatefulWidget {
  const _CloseAskDialog({
    required this.busy,
    required this.rememberDefaultChecked,
  });

  final bool busy;
  final bool rememberDefaultChecked;

  @override
  State<_CloseAskDialog> createState() => _CloseAskDialogState();
}

class _CloseAskDialogState extends State<_CloseAskDialog> {
  late bool _remember = widget.rememberDefaultChecked;
  var _busyFlag = false;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final title = widget.busy ? '检测进行中' : '关闭窗口';
    final lead = widget.busy
        ? '当前正在轮询进行中签到。最小化到托盘可继续等待；退出将停止检测并结束进程。'
        : '课堂检测开启时建议最小化到托盘，避免误关进程。';
    final quitLabel = widget.busy ? '退出并停止检测' : '退出应用';

    return PopScope(
      canPop: !_busyFlag,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        backgroundColor: p.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
          side: BorderSide(color: p.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  lead,
                  style: TextStyle(fontSize: 13, height: 1.4, color: p.muted),
                ),
                if (!widget.busy) ...[
                  const SizedBox(height: 14),
                  Material(
                    type: MaterialType.transparency,
                    borderRadius: BorderRadius.circular(AppRadii.control),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _busyFlag
                          ? null
                          : () => setState(() => _remember = !_remember),
                      borderRadius: BorderRadius.circular(AppRadii.control),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: _remember,
                              onChanged: _busyFlag
                                  ? null
                                  : (v) =>
                                        setState(() => _remember = v ?? false),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '记住我的选择',
                            style: TextStyle(fontSize: 13, color: p.ink),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busyFlag
                      ? null
                      : () {
                          setState(() => _busyFlag = true);
                          Navigator.pop(
                            context,
                            CloseAskResult(
                              action: CloseAskAction.tray,
                              remember: widget.busy ? false : _remember,
                            ),
                          );
                        },
                  child: const Text('最小化到托盘'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _busyFlag
                      ? null
                      : () {
                          setState(() => _busyFlag = true);
                          Navigator.pop(
                            context,
                            CloseAskResult(
                              action: CloseAskAction.quit,
                              remember: widget.busy ? false : _remember,
                            ),
                          );
                        },
                  child: Text(quitLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
