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
  ExamStatus? _status;
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
                return AppPageViewport(
                  maxWidth: AppLayout.workspaceMaxWidth,
                  builder: (context, contentInsets) => ListView(
                    padding:
                        contentInsets +
                        EdgeInsets.fromLTRB(
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
                        status: _status,
                        onStatusChanged: (value) =>
                            setState(() => _status = value),
                      ),
                      if (_status != null && groups[_status]!.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            '该状态暂无考试安排',
                            style: TextStyle(
                              color: AppPalette.of(context).muted,
                            ),
                          ),
                        ),
                      if (snapshot.exams.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: EmptyHint(
                            icon: AppIcons.calendar,
                            title: '本学期暂无考试安排',
                          ),
                        ),
                      for (final status in [
                        ExamStatus.upcoming,
                        ExamStatus.unarranged,
                        ExamStatus.finished,
                      ])
                        if (groups[status]!.isNotEmpty &&
                            (_status == null || _status == status)) ...[
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
                          Panel(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                for (final (index, exam)
                                    in groups[status]!.indexed) ...[
                                  if (index > 0)
                                    Divider(
                                      height: 1,
                                      indent: 20,
                                      endIndent: 20,
                                      color: AppPalette.of(context).border,
                                    ),
                                  _ExamCard(
                                    exam: exam,
                                    now: now,
                                    featured:
                                        status == ExamStatus.upcoming &&
                                        index == 0,
                                  ),
                                ],
                              ],
                            ),
                          ),
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
    required this.status,
    required this.onStatusChanged,
  });
  final ExamStatus? status;
  final ValueChanged<ExamStatus?> onStatusChanged;
  final ExamSnapshot snapshot;
  final Map<ExamStatus, List<AcademicExam>> groups;
  final bool updating;
  final String? warning;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      key: const ValueKey('exam-metadata'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: AppSpace.md,
          runSpacing: AppSpace.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Wrap(
              spacing: AppSpace.xs,
              runSpacing: AppSpace.xxs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${snapshot.term.substring(0, 4)}—${int.parse(snapshot.term.substring(0, 4)) + 1}学年',
                  style: AppTypography.body.copyWith(
                    color: p.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppStatusBadge('第${snapshot.term[4]}学期'),
              ],
            ),
            Text(
              '上次核对 ${snapshot.at.toLocal().toString().substring(0, 16)}',
              style: AppTypography.caption.copyWith(color: p.muted),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.xs),
        LayoutBuilder(
          builder: (context, bounds) => SizedBox(
            width: bounds.maxWidth.clamp(0.0, 500.0),
            child: AppSegmentedControl<ExamStatus?>(
              key: const ValueKey('exam-status-filter'),
              value: status,
              onChanged: onStatusChanged,
              expanded: true,
              compact: true,
              trackOnTouch: true,
              segments: [
                AppSegment<ExamStatus?>(
                  value: null,
                  label: '全部 ${snapshot.exams.length}',
                ),
                for (final item in [
                  ExamStatus.upcoming,
                  ExamStatus.unarranged,
                  ExamStatus.finished,
                ])
                  AppSegment<ExamStatus?>(
                    value: item,
                    label:
                        '${_label(item)} ${groups[item]!.length}${item == ExamStatus.unarranged ? '门' : '场'}',
                  ),
              ],
            ),
          ),
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
  const _ExamCard({
    required this.exam,
    required this.now,
    this.featured = false,
  });
  final AcademicExam exam;
  final DateTime now;
  final bool featured;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final date = exam.date;
    final finished = exam.statusAt(now) == ExamStatus.finished;
    final touch = AppMobileUi.useTouchChrome(context);
    final timing = date == null
        ? '考试时间尚未公布'
        : exam.start == null || exam.end == null
        ? '时间待公布'
        : '${_time(exam.start!)}—${_time(exam.end!)}';
    final color = finished ? p.muted : p.ink;
    final time = Text(
      timing,
      style: TextStyle(
        color: color,
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w500,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    final title = AppTruncatedText(
      exam.course,
      style: TextStyle(
        color: color,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (touch) ...[
          title,
          const SizedBox(height: 6),
          time,
        ] else
          Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 20),
              time,
            ],
          ),
        if (date != null ||
            exam.seat.isNotEmpty ||
            exam.mode.isNotEmpty ||
            exam.name.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              if (date != null)
                Text(
                  exam.room.isEmpty ? '地点待公布' : exam.room,
                  style: TextStyle(color: p.muted, fontSize: 13, height: 1.5),
                ),
              if (exam.seat.isNotEmpty)
                Text(
                  '座位 ${exam.seat}',
                  style: TextStyle(color: p.inkBody, fontSize: 13, height: 1.5),
                ),
              if (exam.mode.isNotEmpty)
                Text(exam.mode, style: TextStyle(color: p.muted, fontSize: 12)),
              if (exam.name.isNotEmpty)
                Text(exam.name, style: TextStyle(color: p.muted, fontSize: 12)),
            ],
          ),
        ],
      ],
    );
    return Padding(
      key: ValueKey('exam-${exam.id}'),
      padding: EdgeInsets.all(touch ? 18 : 24),
      child: LayoutBuilder(
        builder: (context, bounds) {
          final scaler = MediaQuery.textScalerOf(context);
          if (bounds.maxWidth < 380 && scaler.scale(14) > 18) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date == null
                      ? '待安排'
                      : '${date.month}月${date.day}日  周${'一二三四五六日'[date.weekday - 1]}',
                  style: TextStyle(
                    color: featured ? p.primary : p.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                details,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 64 * scaler.scale(1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date == null
                          ? '待定'
                          : '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: featured ? p.primary : color,
                        fontSize: date == null ? 14 : 20,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    if (date != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        '周${'一二三四五六日'[date.weekday - 1]}',
                        style: TextStyle(color: p.muted, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                width: featured ? 2 : 1,
                height: 56 * scaler.scale(1),
                color: featured ? p.primary : p.divider,
              ),
              const SizedBox(width: 18),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}
