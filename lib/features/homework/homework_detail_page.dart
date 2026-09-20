import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/homework/homework_course_page.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';

/// 作业详情（只读）；右上「查看该课全部」。
class HomeworkDetailPage extends ConsumerWidget {
  const HomeworkDetailPage({super.key, required this.seed});

  final HomeworkItem seed;

  void _openCourse(BuildContext context, int courseId, String courseName) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: AppMotion.duration,
        reverseTransitionDuration: AppMotion.duration,
        pageBuilder: (context, animation, secondaryAnimation) =>
            HomeworkCoursePage(courseId: courseId, courseName: courseName),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: AppMotion.curve,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppPalette.of(context);
    final pageX = AppSpace.pageXOf(context);
    final key = HomeworkDetailKey(
      activityId: seed.id,
      courseId: seed.courseId,
      seed: seed,
    );
    final async = ref.watch(homeworkDetailProvider(key));
    final courseId = seed.courseId;

    return SubpageScaffold(
      title: '作业详情',
      actions: [
        if (courseId != null && courseId > 0)
          TextButton(
            onPressed: () => _openCourse(
              context,
              courseId,
              seed.courseName,
            ),
            child: const Text('查看该课全部'),
          ),
      ],
      body: async.when(
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
                    onPressed: () => ref.invalidate(homeworkDetailProvider(key)),
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
          padding: EdgeInsets.fromLTRB(pageX, AppSpace.md, pageX, AppSpace.xl),
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
          Text(
            item.title.isEmpty ? '未命名作业' : item.title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: p.ink,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          _kv('课程', item.courseName.isEmpty ? '—' : item.courseName, p),
          _kv('截止', item.dueLabel, p),
          if (item.type.isNotEmpty) _kv('类型', item.type, p),
          if (item.status.isNotEmpty) _kv('状态', item.status, p),
          if (item.description.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpace.md),
            Text(
              '说明',
              style: TextStyle(fontSize: 12, color: p.muted),
            ),
            const SizedBox(height: AppSpace.xxs),
            Text(
              item.description.trim(),
              style: TextStyle(color: p.ink, height: 1.45),
            ),
          ],
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
