import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/rollcall/session_prior.dart';
import 'package:xmu_rollcall/features/rollcall/session_prior_panel.dart';

void openSessionPriorPreview(BuildContext context) {
  AppPageRoutes.push(context, const SessionPriorPreviewPage());
}

/// Debug preview: task-priority card + session prior footnotes.
class SessionPriorPreviewPage extends StatelessWidget {
  const SessionPriorPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final pageX = AppSpace.pageXOf(context);
    return SubpageScaffold(
      title: '上课段先验预览',
      body: ListView(
        padding: EdgeInsets.fromLTRB(pageX, AppSpace.md, pageX, AppSpace.xl),
        children: [
          Text(
            '本地假数据。任务优先：识别 → 任务条 → 先验脚注。',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppPalette.of(context).muted,
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          const _CaseLabel(text: '符合先验 — 二维码'),
          const SizedBox(height: AppSpace.sm),
          _MockRollcallCard(
            title: '工程伦理（预览）',
            teacher: '预览老师',
            type: RollcallType.qrcode,
            statusLabel: '待签到',
            prior: _qrHeavyPrior(nowMinutes: 14 * 60 + 52),
            actionHint: '扫描',
          ),
          const SizedBox(height: AppSpace.lg),
          const _CaseLabel(text: '不符合先验 — 突然数字'),
          const SizedBox(height: AppSpace.sm),
          _MockRollcallCard(
            title: '工程伦理（预览）',
            teacher: '预览老师',
            type: RollcallType.number,
            statusLabel: '待签到',
            numberCode: '0837',
            prior: _qrHeavyPrior(nowMinutes: 14 * 60 + 55),
            actionHint: '一键签到',
          ),
          const SizedBox(height: AppSpace.lg),
          const _CaseLabel(text: '样本不足'),
          const SizedBox(height: AppSpace.sm),
          _MockRollcallCard(
            title: '操作系统（预览）',
            teacher: '预览老师',
            type: RollcallType.number,
            statusLabel: '待签到',
            numberCode: '2190',
            prior: _sparsePrior(nowMinutes: 14 * 60 + 40),
            actionHint: '一键签到',
          ),
          const SizedBox(height: AppSpace.lg),
          const _CaseLabel(text: '无课表段'),
          const SizedBox(height: AppSpace.sm),
          _MockRollcallCard(
            title: '选修课（无课表）',
            teacher: '预览老师',
            type: RollcallType.radar,
            statusLabel: '待签到',
            prior: const SessionPriorState(unscoped: true),
            actionHint: '选择位置',
          ),
        ],
      ),
    );
  }
}

SessionPriorState _qrHeavyPrior({required int nowMinutes}) {
  final block = SessionBlock(
    startSequence: 5,
    endSequence: 6,
    coreStart: DateTime(2026, 1, 1, 14, 30),
    coreEnd: DateTime(2026, 1, 1, 16, 10),
  );
  const points = [
    14 * 60 + 45,
    14 * 60 + 50,
    14 * 60 + 52,
    15 * 60 + 5,
    15 * 60 + 10,
  ];
  return SessionPriorState(
    snapshot: SessionPriorSnapshot(
      block: block,
      weekday: 2,
      pointsMinutes: points,
      commonStartMinutes: points.first,
      commonEndMinutes: points.last,
      typeCounts: const {
        RollcallType.qrcode: 4,
        RollcallType.number: 1,
      },
      sampleCount: 5,
    ),
    nowMinutes: nowMinutes,
  );
}

SessionPriorState _sparsePrior({required int nowMinutes}) {
  final block = SessionBlock(
    startSequence: 5,
    endSequence: 6,
    coreStart: DateTime(2026, 1, 1, 14, 30),
    coreEnd: DateTime(2026, 1, 1, 16, 10),
  );
  return SessionPriorState(
    snapshot: SessionPriorSnapshot(
      block: block,
      weekday: 2,
      pointsMinutes: const [14 * 60 + 48],
      commonStartMinutes: 14 * 60 + 48,
      commonEndMinutes: 14 * 60 + 48,
      typeCounts: const {RollcallType.number: 1},
      sampleCount: 1,
    ),
    nowMinutes: nowMinutes,
  );
}

class _CaseLabel extends StatelessWidget {
  const _CaseLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: AppPalette.of(context).ink,
      ),
    );
  }
}

/// Mirrors real list chrome: Identify → Task strip → Prior footnote.
class _MockRollcallCard extends StatelessWidget {
  const _MockRollcallCard({
    required this.title,
    required this.teacher,
    required this.type,
    required this.statusLabel,
    required this.prior,
    required this.actionHint,
    this.numberCode,
  });

  final String title;
  final String teacher;
  final RollcallType type;
  final String statusLabel;
  final SessionPriorState prior;
  final String actionHint;
  final String? numberCode;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isNumber = numberCode != null;
    final metaStyle = TextStyle(
      fontSize: 12,
      height: 1.3,
      color: palette.muted,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          height: 1.25,
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: AppSpace.xxs),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              teacher,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: metaStyle,
                            ),
                          ),
                          const SizedBox(width: AppSpace.xs),
                          Text(rollcallTypeZh(type), style: metaStyle),
                          const SizedBox(width: AppSpace.xs),
                          _chip(palette, statusLabel),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!isNumber) ...[
                  const SizedBox(width: AppSpace.sm),
                  FilledButton(
                    onPressed: () {},
                    child: Text(actionHint),
                  ),
                ],
              ],
            ),
            if (isNumber) ...[
              const SizedBox(height: AppSpace.sm),
              Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.sm,
                  AppSpace.xs,
                  AppSpace.xs,
                  AppSpace.xs,
                ),
                decoration: BoxDecoration(
                  color: palette.surfaceHigh,
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        numberCode!,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 4,
                          height: 1.15,
                          color: palette.ink,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    FilledButton(
                      onPressed: () {},
                      child: Text(actionHint),
                    ),
                  ],
                ),
              ),
            ],
            SessionPriorPanel(
              courseId: 'preview',
              currentType: type,
              previewState: prior,
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(AppPalette palette, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.hover,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: palette.ink,
          fontWeight: FontWeight.w600,
          fontSize: 11,
          height: 1.2,
        ),
      ),
    );
  }
}
