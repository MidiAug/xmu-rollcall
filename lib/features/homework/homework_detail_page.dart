import 'package:xmu_rollcall/app/app_service_symbol.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/homework/homework_course_page.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/features/homework/homework_status_badges.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';

/// 作业详情（只读）；右上「查看该课全部」。
class HomeworkDetailPage extends ConsumerWidget {
  const HomeworkDetailPage({super.key, required this.seed});

  final HomeworkItem seed;

  void _openCourse(BuildContext context, int courseId, String courseName) {
    AppPageRoutes.push(
      context,
      HomeworkCoursePage(
        courseId: courseId,
        courseName: courseName,
        detailBuilder: (item) => HomeworkDetailPage(seed: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(selectedRollcallAccountProvider, (before, after) {
      if (before == after) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
    });
    final p = AppPalette.of(context);
    final pageX = AppSpace.pageXOf(context);
    final key = HomeworkDetailKey(
      activityId: seed.id,
      courseId: seed.courseId,
      seed: seed,
    );
    final async = ref.watch(homeworkDetailProvider(key));
    final courseId = async.valueOrNull?.courseId ?? seed.courseId;

    return SubpageScaffold(
      title: '作业详情',
      actions: [
        if (courseId != null && courseId > 0)
          TextButton(
            onPressed: () => _openCourse(
              context,
              courseId,
              (async.valueOrNull ?? seed).courseName,
            ),
            child: const Text('课程作业'),
          ),
      ],
      body: AppPageViewport(
        builder: (context, contentInsets) => async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            padding: contentInsets + EdgeInsets.all(pageX),
            children: [
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '拉取失败',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('$e', style: TextStyle(color: p.muted)),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          ref.invalidate(homeworkDetailProvider(key)),
                      child: const Text('重试'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '以下为列表缓存摘要',
                      style: TextStyle(fontSize: 12, color: p.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.md),
              _DetailBody(item: seed),
            ],
          ),
          data: (item) => ListView(
            padding:
                contentInsets +
                EdgeInsets.fromLTRB(pageX, AppSpace.md, pageX, AppSpace.xl),
            children: [
              _DetailBody(item: item),
              if (courseId == null || courseId <= 0) ...[
                const SizedBox(height: AppSpace.md),
                Text(
                  '未提供课程信息，暂时无法查看该课全部作业。',
                  style: TextStyle(fontSize: 12, color: p.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.item});

  final HomeworkItem item;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final description = homeworkDescriptionText(item.description);
    final hasReadingContent =
        description.isNotEmpty || item.attachments.isNotEmpty;
    return Column(
      key: ValueKey('homework-detail-content-${item.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          key: ValueKey('homework-detail-summary-${item.id}'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              item.title.isEmpty ? '未命名作业' : item.title,
              style: AppTypography.pageTitle.copyWith(color: p.ink),
            ),
            const SizedBox(height: AppSpace.sm),
            AppTruncatedText(
              item.courseName.isEmpty ? '课程未提供' : item.courseName,
              style: AppTypography.body.copyWith(color: p.muted),
            ),
            const SizedBox(height: AppSpace.lg),
            SettingsSection(
              padTop: false,
              hasLeading: false,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpace.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '截止时间',
                        style: AppTypography.body.copyWith(color: p.muted),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Text(
                          item.dueAt == null
                              ? item.dueLabel
                              : '截止 ${item.dueLabel}',
                          textAlign: TextAlign.end,
                          style: AppTypography.body.copyWith(color: p.ink),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpace.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '提交状态',
                        style: AppTypography.body.copyWith(color: p.muted),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: HomeworkStatusBadges(item: item),
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.type.isNotEmpty && !item.isHomework)
                  Padding(
                    padding: const EdgeInsets.all(AppSpace.md),
                    child: Text(
                      '课程活动',
                      style: AppTypography.caption.copyWith(color: p.muted),
                    ),
                  ),
              ],
            ),
          ],
        ),
        if (!hasReadingContent) ...[
          const SizedBox(height: AppSpace.sm),
          Text(
            '暂无作业说明和附件',
            style: AppTypography.caption.copyWith(color: p.muted),
          ),
        ] else ...[
          const SizedBox(height: AppSpace.lg),
          const SizedBox(height: AppSpace.md),
        ],
        if (description.isNotEmpty) ...[
          Text('作业说明', style: AppTypography.control.copyWith(color: p.ink)),
          const SizedBox(height: AppSpace.xs),
          Panel(
            lifted: true,
            child: SelectableText(
              description,
              key: ValueKey('homework-description-${item.id}'),
              style: AppTypography.body.copyWith(color: p.ink, height: 1.7),
            ),
          ),
        ],
        if (item.attachments.isNotEmpty) ...[
          if (description.isNotEmpty) const SizedBox(height: AppSpace.lg),
          Text(
            '附件（${item.attachments.length}）',
            style: AppTypography.control.copyWith(color: p.ink),
          ),
          const SizedBox(height: AppSpace.xs),
        ],
        for (final file in item.attachments)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: p.border),
            ),
            child: Row(
              children: [
                const AppServiceSymbol(icon: AppIcons.document, size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(file.name, style: TextStyle(color: p.ink)),
                      if (file.size != null)
                        Text(
                          '${(file.size! / 1024).toStringAsFixed(1)} KB',
                          style: TextStyle(color: p.muted, fontSize: 12),
                        ),
                      if (file.url == null)
                        Text(
                          '平台未提供下载链接',
                          style: TextStyle(color: p.muted, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                if (file.url != null)
                  AppIconButton(
                    tooltip: '下载附件',
                    icon: const Icon(AppIcons.download, size: 20),
                    onPressed: () async {
                      try {
                        if (!await launchUrl(
                              file.url!,
                              mode: LaunchMode.externalApplication,
                            ) &&
                            context.mounted) {
                          AppToast.show(context, '无法打开附件下载链接', error: true);
                        }
                      } catch (_) {
                        if (context.mounted) {
                          AppToast.show(context, '无法打开附件下载链接', error: true);
                        }
                      }
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
