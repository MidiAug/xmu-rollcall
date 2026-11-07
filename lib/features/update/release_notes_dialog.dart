import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/update/app_release.dart';

class ReleaseNotesDialog extends StatelessWidget {
  const ReleaseNotesDialog({
    super.key,
    required this.update,
    required this.routeSelector,
    required this.onLink,
    required this.onDownload,
  });
  final ReleaseUpdate update;
  final Widget routeSelector;
  final void Function(String?) onLink;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final text = TextStyle(fontSize: 14, height: 1.65, color: p.ink);
    final heading = text.copyWith(
      fontSize: 16,
      height: 1.45,
      fontWeight: FontWeight.w600,
    );
    return AppDialogFrame(
      maxWidth: 540,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: MediaQuery.sizeOf(context).height - 56,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '更新说明',
                          style: heading.copyWith(fontSize: 18),
                        ),
                      ),
                      const AppSheetCloseButton(tooltip: '关闭更新说明'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: AppSpace.xxs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'v${update.version.name}',
                        style: AppTypography.control.copyWith(color: p.ink),
                      ),
                      Text(
                        update.target == UpdateTarget.windows
                            ? 'Windows'
                            : 'Android',
                        style: AppTypography.caption.copyWith(color: p.muted),
                      ),
                      Text(
                        '${(update.size / 1024 / 1024).toStringAsFixed(1)} MB',
                        style: AppTypography.caption.copyWith(color: p.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: p.border),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: MarkdownBody(
                  data: update.notes,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                      .copyWith(
                        p: text,
                        h1: heading,
                        h2: heading,
                        h3: heading.copyWith(fontSize: 14),
                        h1Padding: const EdgeInsets.only(top: 4, bottom: 6),
                        h2Padding: const EdgeInsets.only(top: 4, bottom: 6),
                        h3Padding: const EdgeInsets.only(top: 2, bottom: 4),
                        a: text.copyWith(color: p.primary),
                        blockSpacing: 12,
                        listIndent: 18,
                        blockquote: text.copyWith(color: p.muted, fontSize: 13),
                        blockquotePadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        blockquoteDecoration: BoxDecoration(
                          color: p.content,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: p.content,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                  onTapLink: (_, href, _) => onLink(href),
                  imageBuilder: (_, _, alt) => Text(
                    alt ?? '图片',
                    style: TextStyle(color: p.muted, fontSize: 12),
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: p.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final download = ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: AppMobileUi.useTouchChrome(context)
                          ? AppMobileUi.target
                          : AppDensity.controlHeight(context),
                    ),
                    child: AppButton(label: '下载', onPressed: onDownload),
                  );
                  if (bounds.maxWidth < 300) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: routeSelector,
                        ),
                        const SizedBox(height: AppSpace.xs),
                        Align(
                          alignment: Alignment.centerRight,
                          child: download,
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: routeSelector,
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      download,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
