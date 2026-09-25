import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/pull_to_refresh.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/login_page.dart';
import 'package:xmu_rollcall/features/rollcall/course_catalog_providers.dart';

/// 我的 → 课程：Sticky Catalog 只读列表（R-35 §4 / §8）。
class CoursesPage extends ConsumerWidget {
  const CoursesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final async = ref.watch(courseCatalogProvider);
    final p = AppPalette.of(context);

    return SubpageScaffold(
      title: '课程',
      actions: [
        if (auth.isSignedIn)
          AppRefreshButton(
            onRefresh: () =>
                ref.read(courseCatalogProvider.notifier).refresh(),
          ),
      ],
      body: AppContentColumn(
        child: !auth.isSignedIn
            ? EmptyHint(
                icon: Icons.lock_outline,
                title: '尚未登录',
                detail: '登录后可查看本学期课程',
                action: FilledButton.icon(
                  onPressed: () => showLoginDialog(context),
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('登录'),
                ),
              )
            : AppPullToRefresh(
                color: p.primary,
                onRefresh: () =>
                    ref.read(courseCatalogProvider.notifier).refresh(),
                child: async.when(
                  skipLoadingOnReload: true,
                  skipLoadingOnRefresh: true,
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
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
                              onPressed: () => ref
                                  .read(courseCatalogProvider.notifier)
                                  .refresh(),
                              child: const Text('重试'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  data: (snap) => _CatalogBody(snap: snap),
                ),
              ),
      ),
    );
  }
}

class _CatalogBody extends StatelessWidget {
  const _CatalogBody({required this.snap});

  final CourseCatalogSnapshot? snap;

  @override
  Widget build(BuildContext context) {
    final courses = snap?.courses ?? const <CatalogCourse>[];
    if (courses.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: const [
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyHint(
              icon: Icons.school_outlined,
              title: '暂无课程',
              detail: '下拉刷新，或确认账号已选课',
            ),
          ),
        ],
      );
    }

    final fetched = snap?.fetchedAt;
    final meta = fetched == null
        ? null
        : '缓存于 ${fetched.toLocal().toString().substring(0, 16)}'
            '${snap?.semesterId != null ? ' · 学期 ${snap!.semesterId}' : ''}';

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpace.pageXOf(context),
        AppSpace.md,
        AppSpace.pageXOf(context),
        AppSpace.xl,
      ),
      itemCount: courses.length + (meta != null ? 1 : 0),
      separatorBuilder: (_, _) =>
          SizedBox(height: AppSpace.stackOf(context) * 0.55),
      itemBuilder: (context, i) {
        if (meta != null && i == 0) {
          final p = AppPalette.of(context);
          return Text(
            meta,
            style: TextStyle(fontSize: 12, color: p.muted),
          );
        }
        final c = courses[meta != null ? i - 1 : i];
        final p = AppPalette.of(context);
        final slotCount = c.timetables.values.fold<int>(
          0,
          (n, slots) => n + slots.length,
        );
        return AppHoverSurface(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.title.trim().isEmpty ? '未命名课程' : c.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  slotCount > 0 ? 'ID ${c.id} · $slotCount 个时段' : 'ID ${c.id}',
                  style: TextStyle(fontSize: 12, color: p.muted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
