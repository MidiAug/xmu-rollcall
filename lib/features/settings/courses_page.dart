import 'package:xmu_rollcall/features/schedule/semester_preferences.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/app/shell_tab_scope.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/login_page.dart';
import 'package:xmu_rollcall/features/settings/timetable_grid_view.dart';

/// Direct academic timetable, independent of TronClass course discovery.
class CoursesPage extends ConsumerStatefulWidget {
  const CoursesPage({super.key, this.assistUserId, this.accountName});
  final int? assistUserId;
  final String? accountName;
  @override
  ConsumerState<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends ConsumerState<CoursesPage>
    with ShellTabAware<CoursesPage> {
  bool _semester = false;
  int _viewEpoch = 0;
  @override
  AppDestination get shellTab => AppDestination.timetable;
  @override
  void onShellTabRetap() {
    super.onShellTabRetap();
    setState(() {
      _semester = false;
      _viewEpoch++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final uid = widget.assistUserId ?? auth.profile?.id;
    final timetable = auth.isSignedIn && uid != null
        ? ref.watch(academicTimetableProvider(uid))
        : null;
    final info = uid == null
        ? null
        : ref.watch(semesterInfoProvider(uid)).valueOrNull;
    final p = AppPalette.of(context);
    Widget failure(String message, {bool login = false}) => EmptyHint(
      icon: AppIcons.week,
      title: '暂时无法获取教务课表',
      detail: message,
      action: FilledButton(
        onPressed: () async {
          if (login) {
            await showLoginDialog(context);
          } else if (uid != null) {
            await ref.read(academicSyncProvider).sync(uid, force: true);
          }
          if (mounted && uid != null) {
            ref.invalidate(academicTimetableProvider(uid));
          }
        },
        child: Text(login ? '重新登录' : '重试'),
      ),
    );
    return SubpageScaffold(
      title: widget.accountName == null ? '课表' : '${widget.accountName}的课表',
      actions: [
        if (auth.isSignedIn)
          AppSegmentedControl<bool>(
            segments: const [
              AppSegment(value: false, label: '本周', icon: AppIcons.week),
              AppSegment(value: true, label: '学期', icon: AppIcons.calendar),
            ],
            value: _semester,
            onChanged: (value) => setState(() => _semester = value),
          ),
      ],
      body: !auth.isSignedIn
          ? EmptyHint(
              icon: Icons.lock_outline,
              title: '尚未登录',
              detail: '登录后可查看教务课表',
              action: FilledButton(
                onPressed: () => showLoginDialog(context),
                child: const Text('登录'),
              ),
            )
          : timetable == null
          ? const SizedBox.shrink()
          : timetable.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => failure('请稍后重试'),
              data: (value) {
                final schedule = value.schedule;
                if (schedule == null) {
                  return failure(
                    value.message ?? '尚未连接教务，请重新登录账号',
                    login: value.needsLogin,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (value.message != null)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpace.pageXOf(context),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                value.message!,
                                style: TextStyle(color: p.muted),
                              ),
                            ),
                            if (value.needsLogin)
                              TextButton(
                                onPressed: () => showLoginDialog(context),
                                child: const Text('重新登录'),
                              ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: _TimetableBody(
                        key: ValueKey(_viewEpoch),
                        snap: CourseCatalogSnapshot(
                          fetchedAt: schedule.fetchedAt,
                          courses: schedule.displayOnlyCourses(const []),
                        ),
                        assistUserId: widget.assistUserId,
                        semester: _semester,
                        semesterInfo: info,
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _TimetableBody extends StatelessWidget {
  const _TimetableBody({
    super.key,
    required this.snap,
    this.assistUserId,
    this.semester = false,
    this.semesterInfo,
  });
  final bool semester;
  final SemesterInfo? semesterInfo;
  final int? assistUserId;

  final CourseCatalogSnapshot? snap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - now.weekday + 1);
    final all = snap?.timetableCourses ?? const <CatalogCourse>[];
    final withSlots = semester
        ? all
        : [
            for (final c in all)
              c.withTimetables({
                for (final e in c.timetables.entries)
                  if (e.value.any(
                    (s) => s.occursOn(monday.add(Duration(days: e.key - 1))),
                  ))
                    e.key: e.value
                        .where(
                          (s) =>
                              s.occursOn(monday.add(Duration(days: e.key - 1))),
                        )
                        .toList(),
              }),
          ].where((c) => c.timetables.isNotEmpty).toList();
    if (withSlots.isEmpty) {
      return EmptyHint(
        icon: AppIcons.week,
        title: all.isNotEmpty && !semester ? '本周没有课程安排' : '暂无课表安排',
        detail: all.isNotEmpty && !semester ? '切换到学期查看全部课程' : '教务暂无课程安排',
      );
    }

    final weekStart = '${monday.month}月${monday.day}日';
    final sunday = monday.add(const Duration(days: 6));
    final meta = semester
        ? semesterInfo == null
              ? '学期课表'
              : semesterLabel(semesterInfo!.term).replaceAll(' · ', '  ')
        : '${semesterInfo?.weekLabel(now) ?? '本周课表'}  $weekStart—${sunday.month}月${sunday.day}日';
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
