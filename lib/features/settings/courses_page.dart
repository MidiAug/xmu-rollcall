import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/pull_to_refresh.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/login_page.dart';
import 'package:xmu_rollcall/features/rollcall/course_catalog_providers.dart';
import 'package:xmu_rollcall/features/settings/timetable_grid_view.dart';
import 'package:xmu_rollcall/features/settings/course_schedule_editor.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';

/// 我的 → 本学期课表：周×节网格（Sticky Catalog）。
class CoursesPage extends ConsumerStatefulWidget {
  const CoursesPage({super.key, this.assistUserId, this.accountName});
  final int? assistUserId;
  final String? accountName;

  @override
  ConsumerState<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends ConsumerState<CoursesPage> {
  int? get assistUserId => widget.assistUserId;
  String? get accountName => widget.accountName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final catalog = ref.read(scopedCourseCatalogProvider(assistUserId));
      try {
        await ref.read(catalog.future);
        if (mounted) await ref.read(catalog.notifier).ensureFresh();
      } catch (_) {
        // The page exposes the retry action and any existing offline snapshot.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final catalog = ref.watch(scopedCourseCatalogProvider(assistUserId));
    final async = ref.watch(catalog);
    final p = AppPalette.of(context);

    return SubpageScaffold(
      title: accountName == null ? '课表' : '$accountName的课表',
      actions: [
        if (auth.isSignedIn &&
            async.valueOrNull?.courses.any((c) => !c.hasPlatformSchedule) ==
                true)
          TextButton.icon(
            onPressed: () => AppPageRoutes.push(
              context,
              CourseSchedulesPage(assistUserId: assistUserId),
            ),
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text('补全安排'),
          ),
        if (auth.isSignedIn)
          AppRefreshButton(
            onRefresh: () => ref.read(catalog.notifier).refresh(),
          ),
      ],
      body: !auth.isSignedIn
          ? EmptyHint(
              icon: Icons.lock_outline,
              title: '尚未登录',
              detail: '登录后可查看本学期课表',
              action: FilledButton.icon(
                onPressed: () => showLoginDialog(context),
                icon: const Icon(Icons.login, size: 18),
                label: const Text('登录'),
              ),
            )
          : async.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => AppPullToRefresh(
                color: p.primary,
                onRefresh: () => ref.read(catalog.notifier).refresh(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '暂时无法更新课表',
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
                                ref.read(catalog.notifier).refresh(),
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              data: (snap) =>
                  _TimetableBody(snap: snap, assistUserId: assistUserId),
            ),
    );
  }
}

class _TimetableBody extends StatelessWidget {
  const _TimetableBody({required this.snap, this.assistUserId});
  final int? assistUserId;

  final CourseCatalogSnapshot? snap;

  @override
  Widget build(BuildContext context) {
    final withSlots = snap?.timetableCourses ?? const <CatalogCourse>[];
    if (withSlots.isEmpty) {
      return const EmptyHint(
        icon: Icons.calendar_view_week_outlined,
        title: '暂无课表安排',
        detail: '可在右上角补全安排，或刷新平台课表',
      );
    }

    final fetched = snap?.fetchedAt;
    final meta = fetched == null
        ? null
        : '${snap?.termResolved == true ? '本学期课程' : '学期信息未确认，请刷新'} · 更新于 ${fetched.toLocal().toString().substring(0, 19)}';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.pageXOf(context),
        AppSpace.sm,
        AppSpace.pageXOf(context),
        AppSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (meta != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: Text(meta, style: Theme.of(context).textTheme.bodySmall),
            ),
          Expanded(
            child: TimetableGridView(
              courses: withSlots,
              assistUserId: assistUserId,
            ),
          ),
        ],
      ),
    );
  }
}
