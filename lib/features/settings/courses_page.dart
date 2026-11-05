import 'package:xmu_rollcall/features/location/place_providers.dart';
import 'package:xmu_rollcall/features/location/saved_locations_page.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/features/schedule/semester_preferences.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/desktop/desktop_page.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/app/shell_tab_scope.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/features/auth/login_page.dart';
import 'package:xmu_rollcall/features/settings/timetable_grid_view.dart';
import 'package:xmu_rollcall/features/assist/assist_dialogs.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/session/session_key.dart';

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
    final cached = auth.isSignedIn && uid != null
        ? ref.watch(academicCachedScheduleProvider(uid)).valueOrNull
        : null;
    // A slow sync must not hide an already saved timetable.
    final visibleTimetable = timetable?.isLoading == true && cached != null
        ? AsyncData(AcademicTimetableState(schedule: cached))
        : timetable;
    final info = uid == null
        ? null
        : ref.watch(semesterInfoProvider(uid)).valueOrNull;
    final placeUserId =
        widget.assistUserId == ref.watch(selectedRollcallAccountProvider)
        ? null
        : uid;
    final missingPlaces = ref.watch(
      placeUserId == null
          ? unmatchedRoomsProvider
          : unmatchedRoomsForUserProvider(placeUserId),
    );
    final p = AppPalette.of(context);
    Widget failure(String message, {bool login = false}) => EmptyHint(
      icon: AppIcons.week,
      title: '暂时无法获取教务课表',
      detail: message,
      action: FilledButton(
        onPressed: () async {
          if (login) {
            if (widget.assistUserId == null) {
              await showLoginDialog(context);
            } else {
              final ctrl = ref.read(assistControllerProvider.notifier);
              await showAssistImportDialog(
                context,
                onImportToken: (token) async {
                  final imported = await ctrl.importToken(token);
                  if (imported.userId == widget.assistUserId) {
                    await ref
                        .read(academicSyncProvider)
                        .sync(
                          imported.userId,
                          sso: ref
                              .read(sessionClientRegistryProvider)
                              .forKey(SessionKey.assist(imported.userId))
                              .cookieJar,
                          force: true,
                        );
                  }
                },
                onImportPlain: (username, password) async {
                  final imported = await ctrl.importPlainAccount(
                    username: username,
                    password: password,
                  );
                  if (imported.userId == widget.assistUserId) {
                    await ref
                        .read(academicSyncProvider)
                        .sync(
                          imported.userId,
                          username: username,
                          password: password,
                          force: true,
                        );
                  }
                },
              );
            }
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
    final desktopTab =
        PlatformHooks.isDesktop &&
        !AppMobileUi.useTouchChrome(context) &&
        widget.accountName == null &&
        !Navigator.of(context).canPop();
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - now.weekday + 1);
    final sunday = monday.add(const Duration(days: 6));
    final meta = _semester
        ? info == null
              ? '学期课表'
              : '${semesterLabel(info.term)}${info.start == null ? '' : '  ${info.start!.year}年${info.start!.month}月${info.start!.day}日起'}'
        : '${info?.weekLabel(now) ?? '本周课表'}  ${monday.month}月${monday.day}日—${sunday.month}月${sunday.day}日';
    final selector = auth.isSignedIn
        ? AppSegmentedControl<bool>(
            segments: const [
              AppSegment(value: false, label: '本周', icon: AppIcons.week),
              AppSegment(value: true, label: '学期', icon: AppIcons.calendar),
            ],
            value: _semester,
            onChanged: (value) => setState(() => _semester = value),
          )
        : null;
    final content = !auth.isSignedIn
        ? EmptyHint(
            icon: AppIcons.lock,
            title: '尚未登录',
            detail: '登录后可查看教务课表',
            action: FilledButton(
              onPressed: () => showLoginDialog(context),
              child: const Text('登录'),
            ),
          )
        : timetable == null
        ? const SizedBox.shrink()
        : visibleTimetable!.when(
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
                  if (missingPlaces.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpace.pageXOf(context),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            backgroundColor: Colors.transparent,
                            minimumSize: const Size(0, 36),
                            alignment: Alignment.centerLeft,
                          ),
                          onPressed: () => AppPageRoutes.push(
                            context,
                            SavedLocationsPage(userId: placeUserId),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: p.selected,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Icon(
                                  AppIcons.location,
                                  size: 16,
                                  color: p.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '${missingPlaces.length} 个上课地点未定位',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: p.muted),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '打开地图',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: p.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                              const SizedBox(width: 4),
                              Icon(AppIcons.right, size: 14, color: p.primary),
                            ],
                          ),
                        ),
                      ),
                    ),
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
                        courses: ref.watch(
                          academicDisplayCoursesProvider(schedule),
                        ),
                      ),
                      assistUserId: widget.assistUserId,
                      semester: _semester,
                      meta: meta,
                      showMeta: !desktopTab,
                    ),
                  ),
                ],
              );
            },
          );
    if (desktopTab) {
      return DesktopPage(
        title: '课表',
        showHeader: auth.isSignedIn,
        headerLeading: Row(
          children: [
            ?selector,
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                meta,
                key: const ValueKey('timetable-header-meta'),
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        child: content,
      );
    }
    return SubpageScaffold(
      title: widget.accountName == null ? '课表' : '${widget.accountName}的课表',
      actions: selector == null ? null : [selector],
      body: content,
    );
  }
}

class _TimetableBody extends StatelessWidget {
  const _TimetableBody({
    super.key,
    required this.snap,
    this.assistUserId,
    this.semester = false,
    required this.meta,
    this.showMeta = true,
  });
  final bool semester;
  final String meta;
  final bool showMeta;
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
          if (showMeta)
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
