import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/location/course_location_setting.dart';
import 'package:xmu_rollcall/features/rollcall/course_catalog_providers.dart';

/// Course defaults can be configured before a rollcall or timetable exists.
class CourseLocationsPage extends ConsumerWidget {
  const CourseLocationsPage({super.key, this.assistUserId});
  final int? assistUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(scopedCourseCatalogProvider(assistUserId));
    final data = ref.watch(catalog);
    return SubpageScaffold(
      title: '课程签到地点',
      actions: [
        AppRefreshButton(onRefresh: () => ref.read(catalog.notifier).refresh()),
      ],
      body: !ref.watch(authControllerProvider).isSignedIn
          ? const EmptyHint(icon: Icons.lock_outline, title: '请先登录')
          : data.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: TextButton(
                  onPressed: () => ref.read(catalog.notifier).refresh(),
                  child: const Text('课程加载失败，点击重试'),
                ),
              ),
              data: (snapshot) {
                final courses =
                    snapshot?.courses.where((c) => !c.isTeaching).toList() ??
                    [];
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      '为当前账号的课程设置默认签到地点。开启自动签到和检测后生效；同课不同教室可在课表详情中单独设置。',
                    ),
                    const SizedBox(height: 16),
                    if (courses.isEmpty) const Text('暂无课程，请刷新课表'),
                    for (final course in courses)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Panel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                course.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              CourseLocationSetting(
                                courseId: course.id,
                                courseTitle: course.title,
                                assistUserId: assistUserId,
                                displayLocation: course.location,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}
