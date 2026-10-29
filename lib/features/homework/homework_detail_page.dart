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
            child: const Text('查看该课全部'),
          ),
      ],
      body: AppContentColumn(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            padding: EdgeInsets.all(pageX),
            children: [
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 8),
                    _DetailBody(item: seed),
                  ],
                ),
              ),
            ],
          ),
          data: (item) => ListView(
            padding: EdgeInsets.fromLTRB(
              pageX,
              AppSpace.md,
              pageX,
              AppSpace.xl,
            ),
            children: [
              _DetailBody(item: item),
              if (courseId == null || courseId <= 0) ...[
                const SizedBox(height: AppSpace.md),
                Text(
                  '该待办缺少课程 id，无法打开「该课全部」。',
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
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: p.selected,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(AppIcons.homework, color: p.primary, size: 26),
          ),
          const SizedBox(height: 16),
          Text(
            item.title.isEmpty ? '未命名作业' : item.title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: p.ink,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          _kv('课程', item.courseName.isEmpty ? '—' : item.courseName, p),
          _kv('截止', item.dueLabel, p),
          if (item.type.isNotEmpty)
            _kv('类型', item.isHomework ? '课程作业' : item.type, p),
          if (item.status.isNotEmpty) _kv('状态', item.status, p),
          const SizedBox(height: 16),
          Divider(color: p.border),
          const SizedBox(height: 12),
          Text(
            '作业说明',
            style: TextStyle(fontWeight: FontWeight.w600, color: p.ink),
          ),
          const SizedBox(height: 12),
          SelectableText(
            item.description.trim().isEmpty
                ? '老师暂未提供作业说明'
                : homeworkDescriptionText(item.description),
            style: TextStyle(
              color: item.description.trim().isEmpty ? p.muted : p.ink,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '附件${item.attachments.isEmpty ? '' : '（${item.attachments.length}）'}',
            style: TextStyle(fontWeight: FontWeight.w600, color: p.ink),
          ),
          const SizedBox(height: 8),
          if (item.attachments.isEmpty)
            Text('暂无附件', style: TextStyle(color: p.muted)),
          for (final file in item.attachments)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.content,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.border),
              ),
              child: Row(
                children: [
                  Icon(AppIcons.document, color: p.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                    IconButton(
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
          const SizedBox(height: 16),
          const SizedBox(height: AppSpace.xs),
          HomeworkStatusBadges(item: item),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, AppPalette p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(k, style: TextStyle(fontSize: 13, color: p.muted)),
          ),
          Expanded(
            child: Text(v, style: TextStyle(fontSize: 13, color: p.ink)),
          ),
        ],
      ),
    );
  }
}
