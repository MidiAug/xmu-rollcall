import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/features/schedule/semester_preferences.dart';
import 'exam_models.dart';
import 'exam_providers.dart';

class ExamPage extends ConsumerStatefulWidget {
  const ExamPage({super.key});
  @override
  ConsumerState<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends ConsumerState<ExamPage>
    with WidgetsBindingObserver {
  Timer? _clock;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Presentation only: an examination finishing does not need a request.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted &&
          TickerMode.valuesOf(context).enabled &&
          ModalRoute.of(context)?.isCurrent == true &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        TickerMode.valuesOf(context).enabled &&
        ModalRoute.of(context)?.isCurrent == true &&
        ref.read(authControllerProvider).isSignedIn) {
      ref.invalidate(examSnapshotProvider);
      setState(() {});
    }
  }

  Future<void> _refresh() async {
    try {
      await ref.read(examSnapshotProvider.notifier).refresh();
    } catch (_) {
      /* provider presents error */
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final selected = ref.watch(selectedRollcallAccountProvider);
    final data = auth.isSignedIn ? ref.watch(examSnapshotProvider) : null;
    final updating =
        auth.isSignedIn &&
        (data!.isLoading || ref.read(examSnapshotProvider.notifier).updating);
    final now = ref.read(examClockProvider)();
    return SubpageScaffold(
      title: '考试安排',
      actions: [
        if (auth.isSignedIn)
          AppRefreshButton(
            key: ValueKey('exams-refresh-${auth.profile?.id}-$selected'),
            tooltip: '更新考试安排',
            busy: updating,
            onRefresh: _refresh,
          ),
      ],
      body: !auth.isSignedIn
          ? const EmptyHint(
              icon: AppIcons.person,
              title: '请先登录',
              detail: '查看当前账号的本科考试安排',
            )
          : data!.when(
              loading: () => const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在读取考试安排…'),
                  ],
                ),
              ),
              error: (error, _) => EmptyHint(
                icon: AppIcons.calendar,
                title: '暂时无法读取考试安排',
                detail: error is FormatException
                    ? error.message
                    : '请稍后重试，或重新登录当前账号以连接教务',
                action: FilledButton(
                  onPressed: _refresh,
                  child: const Text('重试'),
                ),
              ),
              data: (snapshot) {
                if (snapshot.term != currentSemester(now)) {
                  return EmptyHint(
                    icon: AppIcons.calendar,
                    title: '已进入新学期',
                    detail: '更新以查看本学期考试安排',
                    action: FilledButton(
                      onPressed: _refresh,
                      child: const Text('读取本学期'),
                    ),
                  );
                }
                final notifier = ref.read(examSnapshotProvider.notifier);
                final groups = <ExamStatus, List<AcademicExam>>{
                  for (final status in ExamStatus.values)
                    status:
                        snapshot.exams
                            .where((e) => e.statusAt(now) == status)
                            .toList()
                          ..sort(
                            (a, b) => (a.start ?? a.date ?? now).compareTo(
                              b.start ?? b.date ?? now,
                            ),
                          ),
                };
                return AppContentColumn(
                  maxWidth: 900,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      AppSpace.pageXOf(context),
                      12,
                      AppSpace.pageXOf(context),
                      28,
                    ),
                    children: [
                      _ExamOverview(
                        snapshot: snapshot,
                        groups: groups,
                        updating: notifier.updating,
                        warning: notifier.warning,
                      ),
                      if (snapshot.exams.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: EmptyHint(
                            icon: AppIcons.calendar,
                            title: '本学期暂无考试安排',
                            detail: '教务发布后会在这里显示，可随时手动更新',
                          ),
                        ),
                      for (final status in [
                        ExamStatus.upcoming,
                        ExamStatus.unarranged,
                        ExamStatus.finished,
                      ])
                        if (groups[status]!.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 26, bottom: 12),
                            child: Row(
                              children: [
                                Text(
                                  _label(status),
                                  style: TextStyle(
                                    color: AppPalette.of(context).ink,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                AppStatusBadge('${groups[status]!.length}'),
                                if (status == ExamStatus.finished) ...[
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: Text(
                                      '按公布的结束时间归类',
                                      style: TextStyle(
                                        color: AppPalette.of(context).muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          for (final exam in groups[status]!)
                            _ExamCard(exam: exam, now: now),
                        ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}

String _label(ExamStatus status) => switch (status) {
  ExamStatus.unarranged => '未安排',
  ExamStatus.upcoming => '未考试',
  ExamStatus.finished => '已考试',
};
String _time(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

class _ExamOverview extends StatelessWidget {
  const _ExamOverview({
    required this.snapshot,
    required this.groups,
    required this.updating,
    required this.warning,
  });
  final ExamSnapshot snapshot;
  final Map<ExamStatus, List<AcademicExam>> groups;
  final bool updating;
  final String? warning;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${snapshot.term.substring(0, 4)}—${int.parse(snapshot.term.substring(0, 4)) + 1}学年',
              style: TextStyle(
                color: p.ink,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            AppStatusBadge('第${snapshot.term[4]}学期'),
          ],
        ),
        const SizedBox(height: 18),
        AppGlassSurface(
          blur: 0,
          opacity: 1,
          borderRadius: BorderRadius.circular(AppRadii.card),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              for (final status in [
                ExamStatus.upcoming,
                ExamStatus.unarranged,
                ExamStatus.finished,
              ])
                Expanded(
                  child: AppMetric(
                    value:
                        '${groups[status]!.length}${status == ExamStatus.unarranged ? '门' : '场'}',
                    label: _label(status),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '上次核对 ${snapshot.at.toLocal().toString().substring(0, 16)}',
          style: TextStyle(color: p.muted, fontSize: 12),
        ),
        if (updating) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 8),
          Text('正在核对教务更新…', style: TextStyle(color: p.muted, fontSize: 12)),
        ],
        if (warning != null) ...[
          const SizedBox(height: 12),
          Text(
            '$warning；已有安排仍保留',
            style: TextStyle(color: p.warning, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exam, required this.now});
  final AcademicExam exam;
  final DateTime now;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final date = exam.date;
    final finished = exam.statusAt(now) == ExamStatus.finished;
    final emphasis = date == null || finished ? p.muted : p.primary;
    return Container(
      key: ValueKey('exam-${exam.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: p.controlSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                if (date == null) ...[
                  Icon(AppIcons.calendar, color: emphasis, size: 24),
                  const SizedBox(height: 6),
                  Text('待安排', style: TextStyle(color: emphasis, fontSize: 10)),
                ] else ...[
                  Text(
                    '${date.month}月',
                    style: TextStyle(color: emphasis, fontSize: 11),
                  ),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      color: emphasis,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    '周${'一二三四五六日'[date.weekday - 1]}',
                    style: TextStyle(color: emphasis, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTruncatedText(
                  exam.course,
                  style: TextStyle(
                    color: finished ? p.muted : p.ink,
                    fontSize: 16,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(AppIcons.clock, color: p.muted, size: 15),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            date == null
                                ? '考试时间尚未公布'
                                : exam.start == null
                                ? '时间待公布'
                                : '${_time(exam.start!)}—${_time(exam.end!)}',
                            style: TextStyle(
                              color: emphasis,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (exam.seat.isNotEmpty) AppStatusBadge('座位 ${exam.seat}'),
                    if (exam.mode.isNotEmpty) AppStatusBadge(exam.mode),
                    if (exam.name.isNotEmpty)
                      Text(
                        exam.name,
                        style: TextStyle(
                          color: p.muted,
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                  ],
                ),
                if (date != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          AppIcons.location,
                          color: p.muted,
                          size: 15,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          exam.room.isEmpty ? '地点待公布' : exam.room,
                          style: TextStyle(
                            color: p.muted,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
