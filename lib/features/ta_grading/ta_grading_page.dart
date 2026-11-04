import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/app_checkbox.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/app/shell_tab_scope.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/network/request_failure.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'ta_batch.dart';
import 'ta_csv.dart';
import 'ta_models.dart';
import 'ta_providers.dart';
import 'ta_repository.dart';
import 'ta_widgets.dart';
import 'ta_mobile_assignment_page.dart';

class TaGradingPage extends ConsumerWidget {
  const TaGradingPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(taRepositoryProvider);
    final courses = ref.watch(currentTeachingCoursesProvider);
    return PageScaffold(
      onBack: Navigator.of(context).canPop()
          ? () => Navigator.of(context).maybePop()
          : null,
      title: taIsMobile(context) ? '助教作业' : '修改作业',
      subtitle: taIsMobile(context) ? '课程进度与学生提交' : '作业进度、打包下载与批量评分',
      child: repository.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Failure(
          error: e,
          retry: () => ref.invalidate(taRepositoryProvider),
        ),
        data: (repo) => courses.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _Failure(
            error: e,
            retry: () => ref.invalidate(currentTeachingCoursesProvider),
          ),
          data: (items) => _TaCourses(
            key: ObjectKey(repo),
            repository: repo,
            courses: items,
          ),
        ),
      ),
    );
  }
}

class _TaCourses extends StatefulWidget {
  const _TaCourses({
    super.key,
    required this.repository,
    required this.courses,
  });
  final TaGradingRepository repository;
  final List<CatalogCourse> courses;
  @override
  State<_TaCourses> createState() => _TaCoursesState();
}

class _TaCoursesState extends State<_TaCourses> {
  int? _course;
  Future<List<TaAssignment>>? _assignments;
  Future<List<TaAssignment>> _readAssignments(
    int id, {
    bool refresh = false,
  }) async {
    await widget.repository.restoreAssignments(id);
    if (!mounted || _course != id) {
      return widget.repository.cachedAssignments(id)?.items ?? const [];
    }
    if (widget.repository.cachedAssignments(id) != null) {
      setState(() {});
    }
    return widget.repository.assignments(id, refresh: refresh);
  }

  void _select(int id, {bool refresh = false}) {
    setState(() {
      _course = id;
      _assignments = _readAssignments(id, refresh: refresh);
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.courses.isNotEmpty) {
      _course = int.tryParse(widget.courses.first.id);
      if (_course != null) {
        _assignments = _readAssignments(_course!);
      }
    }
  }

  @override
  void didUpdateWidget(covariant _TaCourses oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.courses.any((c) => c.id == '$_course')) {
      _course = widget.courses.isEmpty
          ? null
          : int.tryParse(widget.courses.first.id);
      _assignments = _course == null ? null : _readAssignments(_course!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    if (widget.courses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: p.accentSurface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(Icons.school_outlined, size: 32, color: p.primary),
              ),
              const SizedBox(height: 20),
              Text('还没有助教课程', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                '获得课程的教师或助教权限后，作业会显示在这里。',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: p.muted),
              ),
            ],
          ),
        ),
      );
    }
    final course = widget.courses.firstWhere(
      (c) => c.id == '$_course',
      orElse: () => widget.courses.first,
    );
    return AppContentColumn(
      maxWidth: 1000,
      child: FutureBuilder<List<TaAssignment>>(
        key: ValueKey((_course, _assignments)),
        future: _assignments,
        initialData: _course == null
            ? null
            : widget.repository.cachedAssignments(_course!)?.items,
        builder: (context, snapshot) {
          final assignments =
              snapshot.data ??
              (_course == null
                  ? null
                  : widget.repository.cachedAssignments(_course!)?.items);
          if (snapshot.hasError && assignments == null) {
            return _Failure(
              error: snapshot.error!,
              retry: () => _select(_course!),
            );
          }
          if (assignments == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: assignments.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: p.accentSurface.withValues(alpha: .6),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.school_outlined,
                                color: p.primary,
                                size: 21,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '助教工作台',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(color: p.primary),
                              ),
                              const Spacer(),
                              AppRefreshButton(
                                tooltip: '更新作业',
                                iconSize: 20,
                                busy:
                                    snapshot.connectionState ==
                                    ConnectionState.waiting,
                                onRefresh: () async {
                                  if (_course != null) {
                                    _select(_course!, refresh: true);
                                    try {
                                      await _assignments;
                                    } catch (_) {
                                      // FutureBuilder keeps cached content and reports the failure.
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          AppTruncatedText(
                            course.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              TaTag('${assignments.length} 项作业'),
                              TaTag(
                                '待批改 ${assignments.fold<int>(0, (n, a) => n + (a.submitted - a.graded).clamp(0, a.submitted))}',
                                color: p.warning,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (widget.courses.length > 1) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final c in widget.courses)
                            SizedBox(
                              width: 220,
                              child: Material(
                                color: c.id == '$_course'
                                    ? p.selected
                                    : p.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(color: p.borderStrong),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () {
                                    final id = int.tryParse(c.id);
                                    if (id != null && id != _course) {
                                      _select(id);
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Icon(
                                          c.id == '$_course'
                                              ? Icons.check_circle_outline
                                              : Icons.circle_outlined,
                                          size: 16,
                                          color: p.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: AppTruncatedText(c.title),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (snapshot.hasError)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          '更新失败，保留上次作业列表',
                          style: TextStyle(color: p.warning),
                        ),
                      ),
                    if (widget.repository.cachedAssignments(_course!)
                        case final cached?)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          '上次核对 ${cached.checkedAt.toLocal().toString().substring(0, 16)}',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: p.muted),
                        ),
                      ),
                    const SizedBox(height: 26),
                    Text(
                      '课程作业',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (assignments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Text('这门课还没有作业'),
                      ),
                  ],
                );
              }
              final item = assignments[index - 1];
              final pending = (item.submitted - item.graded).clamp(
                0,
                item.submitted,
              );
              return Material(
                color: p.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: p.borderStrong),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () async {
                    final courseId = _course!;
                    await AppPageRoutes.push(
                      context,
                      taIsMobile(context)
                          ? TaMobileAssignmentPage(
                              repository: widget.repository,
                              courseId: courseId,
                              assignment: item,
                            )
                          : TaAssignmentPage(
                              repository: widget.repository,
                              courseId: courseId,
                              assignment: item,
                            ),
                    );
                    if (mounted &&
                        widget.repository.active &&
                        _course == courseId) {
                      _select(courseId);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: p.controlSurface,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(
                                Icons.assignment_outlined,
                                color: p.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppTruncatedText(
                                item.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.chevron_right, color: p.muted, size: 20),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            Text(
                              '应交 ${item.expected}',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(color: p.muted),
                            ),
                            Text(
                              '已提交 ${item.submitted}',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(color: p.muted),
                            ),
                            Text(
                              '已批改 ${item.graded}',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(color: p.muted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  minHeight: 4,
                                  value: item.expected == 0
                                      ? 0
                                      : (item.submitted / item.expected).clamp(
                                          0,
                                          1,
                                        ),
                                  backgroundColor: p.controlSurface,
                                  color: p.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            TaTag(
                              pending == 0 ? '暂无待批改' : '待批改 $pending',
                              color: pending == 0 ? p.muted : p.warning,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class TaAssignmentPage extends ConsumerStatefulWidget {
  const TaAssignmentPage({
    super.key,
    required this.repository,
    required this.courseId,
    required this.assignment,
  });
  final TaGradingRepository repository;
  final int courseId;
  final TaAssignment assignment;
  @override
  ConsumerState<TaAssignmentPage> createState() => _TaAssignmentPageState();
}

class _TaAssignmentPageState extends ConsumerState<TaAssignmentPage>
    with WidgetsBindingObserver, ShellTabAware<TaAssignmentPage> {
  @override
  AppDestination get shellTab => AppDestination.campusTools;
  @override
  void onShellTabHidden() {
    super.onShellTabHidden();
    _batch.stop();
    _repository.dispose();
    _poll?.cancel();
  }

  late final TaGradingRepository _repository;
  late Future<void> _loading;
  TaAssignment? _detail;
  late TaAssignment _summary;
  List<TaStudent> _students = [];
  final _selected = <int>{};
  String _search = '';
  int _submissionFilter = 0;
  final _checkingScores = <int>{};
  TaZip? _zip, _oldZip;
  bool _downloadMatchesSelection = false, _packSelectionChanged = false;
  bool _building = false, _zipBusy = false, _importing = false;
  String? _zipMessage;
  Timer? _poll;
  int _checks = 0;
  bool _zipCoolingDown = false;
  Timer? _zipCooldown;
  List<TaGradeRow> _rows = [];
  VoidCallback? _refreshCsv;
  String? _csvError;
  bool _overwrite = false, _allowUnsubmitted = false;
  final _batch = TaGradeBatch();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _summary = widget.assignment;
    _repository = widget.repository.fork();
    _loading = _load();
  }

  Future<void> _load() async {
    final detail = await _repository.detail(
      widget.courseId,
      widget.assignment.id,
    );
    final students = await _repository.students(
      widget.courseId,
      widget.assignment.id,
    );
    if (!mounted) {
      return;
    }
    _detail = detail;
    _students = students;
    _selected.removeWhere((id) => !students.any((s) => s.id == id));
    unawaited(_checkZip());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _zipCooldown?.cancel();
    _batch.stop();
    _repository.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _poll?.cancel();
  }

  void _changed() {
    if (mounted) setState(() {});
    _refreshCsv?.call();
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _checkZip() async {
    if (!mounted ||
        !_repository.active ||
        _zipBusy ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return;
    }
    if (WidgetsBinding.instance.lifecycleState case final state?
        when state != AppLifecycleState.resumed) {
      return;
    }
    if (_zipCoolingDown) {
      return;
    }
    _zipCoolingDown = true;
    _zipCooldown?.cancel();
    _zipCooldown = Timer(const Duration(seconds: 5), () {
      _zipCoolingDown = false;
      _changed();
    });
    _zipBusy = true;
    try {
      final zip = await _repository.zipStatus(widget.assignment.id);
      if (!mounted) {
        return;
      }
      final fresh =
          _oldZip == null || zip.id != _oldZip!.id || zip.key != _oldZip!.key;
      if (!_building || fresh && zip.download != null) {
        _zip = zip;
        if (_building && zip.download != null) {
          _downloadMatchesSelection = !_packSelectionChanged;
        }
        if (zip.download != null) {
          _building = false;
          _zipMessage = null;
        }
      }
      if (zip.status == 'failed' || zip.status == 'error') {
        _building = false;
        _zipMessage = '服务器打包失败，可重新打包';
      }
    } catch (error) {
      if (mounted) _zipMessage = requestFailureMessage(error);
    } finally {
      _zipBusy = false;
      _changed();
      if (mounted && _building && _repository.active && ++_checks < 60) {
        _poll?.cancel();
        _poll = Timer(const Duration(seconds: 5), _checkZip);
      }
    }
  }

  Future<void> _pack() async {
    if (_zipBusy || _batch.running || !_repository.active) {
      return;
    }
    _poll?.cancel();
    setState(() {
      _zipBusy = true;
      _zipMessage = null;
      _packSelectionChanged = false;
      _downloadMatchesSelection = false;
    });
    try {
      // Obtain a baseline immediately before re-packaging; stale ready packages
      // remain hidden until the server returns a different package identity.
      _oldZip = await _repository.zipStatus(widget.assignment.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _zip = null;
        _building = true;
        _checks = 0;
      });
      await _repository.startZip(
        widget.assignment.id,
        _selected.toList(),
        _students.map((s) => s.id).toList(),
      );
      if (mounted) _zipMessage = '服务器正在打包，请稍候';
    } catch (error) {
      if (mounted) {
        _zipMessage = _building
            ? '打包请求未确认，请检查状态后再决定是否重新打包'
            : requestFailureMessage(error);
      }
    } finally {
      _zipBusy = false;
      _zipCooldown?.cancel();
      _zipCoolingDown = false;
      _changed();
      if (mounted && _building) {
        unawaited(_checkZip());
      }
    }
  }

  Future<void> _import() async {
    if (_batch.running || _importing || !_repository.active) {
      return;
    }
    setState(() {
      _importing = true;
      _csvError = null;
    });
    _refreshCsv?.call();
    try {
      final text = await ref.read(taCsvReaderProvider)();
      if (text == null || !mounted || !_repository.active) {
        return;
      }
      final rows = parseTaCsv(text, _students);
      setState(() {
        _rows = rows;
        _overwrite = false;
        _allowUnsubmitted = false;
      });
    } on FormatException catch (error) {
      _csvError = error.message;
    } catch (_) {
      _csvError = '无法读取 CSV，请检查文件编码与访问权限';
    } finally {
      if (mounted) {
        _importing = false;
        _changed();
      }
    }
  }

  Future<void> _submit() async {
    if (_batch.running || !_repository.active) {
      return;
    }
    final yes = await showAppConfirmDialog(
      context,
      title: '确认提交成绩',
      message:
          '作业：${widget.assignment.title}\n将逐条处理 ${_rows.where((r) => r.status == TaRowStatus.ready).length} 行成绩。'
          '\n${_overwrite ? '允许覆盖已有成绩' : '已有成绩将跳过'}'
          '\n${_allowUnsubmitted ? '允许为未提交学生评分' : '未提交学生将跳过'}',
      cancelLabel: '取消',
      confirmLabel: '确认提交',
    );
    if (yes != true || !mounted || !_repository.active) {
      return;
    }
    widget.repository.markAssignmentsStale(widget.courseId);
    await _batch.run(
      repository: _repository,
      activityId: widget.assignment.id,
      rows: _rows,
      overwrite: _overwrite,
      allowUnsubmitted: _allowUnsubmitted,
      onChanged: _changed,
    );
    if (!mounted || !_repository.active) {
      return;
    }
    final saved = {
      for (final row in _rows)
        if (row.status == TaRowStatus.saved)
          row.student!.id: double.parse(row.score),
    };
    setState(
      () => _students = [
        for (final student in _students)
          if (saved.containsKey(student.id))
            TaStudent(
              id: student.id,
              number: student.number,
              name: student.name,
              submitted: student.submitted,
              score: saved[student.id],
              scoreChecked: true,
            )
          else
            student,
      ],
    );
    try {
      _repository.markAssignmentsStale(widget.courseId);
      final assignments = await _repository.assignments(widget.courseId);
      if (!mounted) {
        return;
      }
      setState(() {
        _summary = assignments.firstWhere(
          (a) => a.id == widget.assignment.id,
          orElse: () => _summary,
        );
      });
    } catch (_) {
      _message('成绩处理已结束，作业进度未更新，请返回后刷新');
    }
  }

  Future<void> _checkStudent(TaStudent student) async {
    if (_batch.running ||
        !_repository.active ||
        !_checkingScores.add(student.id)) {
      return;
    }
    _changed();
    try {
      final score = await _repository.currentScore(
        widget.assignment.id,
        student.id,
      );
      if (!mounted) {
        return;
      }
      setState(
        () => _students = [
          for (final s in _students)
            if (s.id == student.id)
              TaStudent(
                id: s.id,
                number: s.number,
                name: s.name,
                submitted: s.submitted,
                score: score,
                scoreChecked: true,
              )
            else
              s,
        ],
      );
    } catch (error) {
      _message(requestFailureMessage(error));
    } finally {
      _checkingScores.remove(student.id);
      _changed();
    }
  }

  Future<void> _openCsvReview() async {
    if (!_repository.active) {
      return;
    }
    var copied = false;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Consumer(
          builder: (context, dialogRef, _) {
            if (!identical(
                  dialogRef.watch(taRepositoryProvider).valueOrNull,
                  widget.repository,
                ) ||
                !_repository.active) {
              return AppNoticeDialog(
                title: '当前页面已失效',
                message: '请返回后重新选择账号与作业。',
                onClose: () => Navigator.pop(context),
              );
            }
            return StatefulBuilder(
              builder: (context, update) {
                _refreshCsv = () {
                  if (context.mounted) {
                    update(() {});
                  }
                };
                final invalid = _rows.where((r) => r.issue != null).length;
                final saved = _rows
                    .where((r) => r.status == TaRowStatus.saved)
                    .length;
                final canSubmit =
                    !_batch.running &&
                    !_importing &&
                    invalid == 0 &&
                    !_rows.any(
                      (r) =>
                          r.status == TaRowStatus.uncertain ||
                          r.status == TaRowStatus.failed,
                    ) &&
                    _rows.any((r) => r.status == TaRowStatus.ready);
                final palette = AppPalette.of(context);
                return PopScope(
                  canPop: !_batch.running,
                  child: AppDialogFrame(
                    maxWidth: _rows.isEmpty ? 480 : 720,
                    insetPadding: const EdgeInsets.all(AppSpace.md),
                    child: SizedBox(
                      key: const ValueKey('ta-csv-content'),
                      width: double.infinity,
                      height: _rows.isEmpty
                          ? null
                          : (324.0 + _rows.length * 42).clamp(
                              300.0,
                              (MediaQuery.sizeOf(context).height * .82).clamp(
                                300.0,
                                620.0,
                              ),
                            ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _rows.isEmpty ? '导入成绩' : '核对成绩表',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                ),
                                AppSheetCloseButton(
                                  enabled: !_batch.running,
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_csvError != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  _csvError!,
                                  style: TextStyle(color: palette.danger),
                                ),
                              ),
                            if (_rows.isEmpty)
                              Flexible(
                                fit: FlexFit.loose,
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        '选择 CSV 成绩表，核对后再确认提交。',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(color: palette.muted),
                                      ),
                                      const SizedBox(height: AppSpace.md),
                                      Container(
                                        padding: const EdgeInsets.all(
                                          AppSpace.md,
                                        ),
                                        decoration: BoxDecoration(
                                          color: palette.content,
                                          border: Border.all(
                                            color: palette.borderStrong,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            AppRadii.control,
                                          ),
                                        ),
                                        child: SelectableText(
                                          'user_no,score\nDEMO0001,86\nDEMO0002,90',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(height: 1.6),
                                        ),
                                      ),
                                      const SizedBox(height: AppSpace.sm),
                                      Text(
                                        '两列依次为学号、成绩。学号保留前导零，成绩范围为 0 至 100。',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: palette.muted),
                                      ),
                                      const SizedBox(height: AppSpace.sm),
                                    ],
                                  ),
                                ),
                              ),
                            if (_rows.isNotEmpty) ...[
                              Text(
                                '共 ${_rows.length} 行，错误 $invalid 行，已保存 $saved 行',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: Scrollbar(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: 620,
                                      child: Column(
                                        children: [
                                          _csvRow([
                                            '学号',
                                            '姓名',
                                            '新成绩',
                                            '处理结果',
                                          ], heading: true),
                                          Expanded(
                                            child: ListView.builder(
                                              itemCount: _rows.length,
                                              itemBuilder: (_, i) {
                                                final row = _rows[i];
                                                return _csvRow(
                                                  [
                                                    row.number,
                                                    row.student?.name ?? '未匹配',
                                                    row.score,
                                                    row.issue ??
                                                        row.result ??
                                                        '待提交',
                                                  ],
                                                  error:
                                                      row.issue != null ||
                                                      row.status ==
                                                          TaRowStatus.failed ||
                                                      row.status ==
                                                          TaRowStatus.uncertain,
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              AppCheckboxRow(
                                label: '允许覆盖已有成绩',
                                value: _overwrite,
                                onChanged: _batch.running
                                    ? null
                                    : (v) {
                                        _overwrite = v;
                                        update(() {});
                                      },
                              ),
                              AppCheckboxRow(
                                label: '允许为未提交者评分',
                                value: _allowUnsubmitted,
                                onChanged: _batch.running
                                    ? null
                                    : (v) {
                                        _allowUnsubmitted = v;
                                        update(() {});
                                      },
                              ),
                              if (_batch.running)
                                const LinearProgressIndicator(minHeight: 2),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (_batch.running)
                                  TextButton(
                                    onPressed: () {
                                      _batch.stop();
                                      update(() {});
                                    },
                                    child: const Text('停止后续提交'),
                                  ),
                                if (_rows.isEmpty)
                                  TextButton(
                                    onPressed: () async {
                                      await Clipboard.setData(
                                        const ClipboardData(
                                          text:
                                              'user_no,score\nDEMO0001,86\nDEMO0002,90\n',
                                        ),
                                      );
                                      if (context.mounted) {
                                        update(() => copied = true);
                                      }
                                    },
                                    child: Text(copied ? '已复制模板' : '复制模板'),
                                  ),
                                if (!_batch.running && _rows.isEmpty)
                                  AppButton(
                                    label: _importing ? '正在读取…' : '选择 CSV 文件',
                                    icon: AppIcons.upload,
                                    busy: _importing,
                                    onPressed: _import,
                                  ),
                                if (!_batch.running && _rows.isNotEmpty)
                                  TextButton(
                                    onPressed: _importing ? null : _import,
                                    child: Text(_importing ? '正在读取…' : '更换文件'),
                                  ),
                                if (_rows.isNotEmpty)
                                  AppButton(
                                    label: '提交成绩',
                                    icon: AppIcons.check,
                                    onPressed: canSubmit ? _submit : null,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
    } finally {
      _refreshCsv = null;
      if (mounted) setState(() {});
    }
  }

  Widget _csvRow(
    List<String> cells, {
    bool heading = false,
    bool error = false,
  }) {
    final p = AppPalette.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 42),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: heading ? p.content : null,
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: i == 3 ? 3 : 2,
              child: Text(
                cells[i],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: error ? p.danger : p.ink,
                  fontWeight: heading ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!identical(
      ref.watch(taRepositoryProvider).valueOrNull,
      widget.repository,
    )) {
      return PageScaffold(
        onBack: () => Navigator.of(context).maybePop(),
        title: '修改作业',
        child: Center(child: Text('账号已变更，请返回重新选择课程')),
      );
    }
    if (!_repository.active) {
      return PageScaffold(
        onBack: () => Navigator.of(context).maybePop(),
        title: '修改作业',
        child: Center(child: Text('处理已停止，请返回重新打开作业')),
      );
    }
    final p = AppPalette.of(context);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _batch.stop();
          _repository.dispose();
          _poll?.cancel();
        }
      },
      child: PageScaffold(
        onBack: () => Navigator.of(context).maybePop(),
        title: widget.assignment.title,
        subtitle:
            '应交 ${_summary.expected}    已提交 ${_summary.submitted}    已批改 ${_summary.graded}',
        child: Material(
          color: p.canvas,
          child: FutureBuilder<void>(
            future: _loading,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _Failure(
                  error: snapshot.error!,
                  retry: () => setState(() {
                    _loading = _load();
                  }),
                );
              }
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final visible = _students
                  .where(
                    (s) =>
                        '${s.number} ${s.name}'.contains(_search) &&
                        (_submissionFilter == 0 ||
                            (_submissionFilter == 1
                                ? s.submitted
                                : !s.submitted)),
                  )
                  .toList();
              final blocked = _batch.running || _importing || _zipBusy;
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 6, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _studentToolbar(blocked),
                    const SizedBox(height: 14),
                    if (_building || _zipMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            if (_building)
                              const Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                _zipMessage ?? '正在打包',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            TextButton(
                              onPressed: _zipBusy || _zipCoolingDown
                                  ? null
                                  : _checkZip,
                              child: const Text('检查状态'),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: Card(
                        child: LayoutBuilder(
                          builder: (context, bounds) {
                            final table = Column(
                              children: [
                                _studentTableRow(
                                  null,
                                  visible,
                                  heading: true,
                                  blocked: blocked,
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    key: const ValueKey('ta-assignment-scroll'),
                                    // Rows are single-line. Known extents avoid
                                    // measuring preceding rows during scrolling.
                                    // Grow with accessibility text, not row data.
                                    itemExtent:
                                        48 *
                                        (MediaQuery.textScalerOf(
                                                  context,
                                                ).scale(14) /
                                                14)
                                            .clamp(1.0, double.infinity),
                                    itemCount: visible.length,
                                    itemBuilder: (_, i) => _studentTableRow(
                                      visible[i],
                                      visible,
                                      blocked: blocked,
                                    ),
                                  ),
                                ),
                              ],
                            );
                            if (bounds.maxWidth >= 640) {
                              return table;
                            }
                            return Scrollbar(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: 640,
                                  height: bounds.maxHeight,
                                  child: table,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '显示 ${visible.length} 人',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: p.muted),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _changeSelection(VoidCallback change) {
    setState(() {
      change();
      _downloadMatchesSelection = false;
      if (_building) _packSelectionChanged = true;
    });
  }

  Widget _studentToolbar(bool blocked) {
    final search = SizedBox(
      width: 230,
      child: AppSearchField(
        hintText: '搜索姓名或学号',
        onChanged: (v) => setState(() => _search = v),
      ),
    );
    final filter = AppShellSelect<int>(
      key: const ValueKey('ta-submission-filter'),
      semanticLabel: '筛选提交状态',
      value: _submissionFilter,
      items: const [0, 1, 2],
      labelOf: (v) => ['全部学生', '已提交', '未提交'][v],
      width: 112,
      menuWidth: 160,
      compact: true,
      onChanged: (v) => setState(() => _submissionFilter = v),
    );
    final select = AppButton(
      kind: AppButtonKind.quiet,
      label: '选择已提交学生',
      onPressed: blocked
          ? null
          : () => _changeSelection(
              () => _selected.addAll(
                _students
                    .where(
                      (s) =>
                          s.submitted &&
                          '${s.number} ${s.name}'.contains(_search) &&
                          _submissionFilter != 2,
                    )
                    .map((s) => s.id),
              ),
            ),
    );
    final actions = <Widget>[
      AppButton(
        label: '导入成绩',
        icon: AppIcons.upload,
        onPressed: _detail?.canGrade != true || _batch.running
            ? null
            : _openCsvReview,
      ),
      if (_zip?.download != null && !_building) ...[
        OutlinedButton.icon(
          onPressed: () async {
            try {
              if (!await launchUrl(
                _zip!.download!,
                mode: LaunchMode.externalApplication,
              )) {
                _message('无法打开下载链接');
              }
            } catch (_) {
              _message('无法打开下载链接');
            }
          },
          icon: const Icon(Icons.download_outlined, size: 18),
          label: Text(_downloadMatchesSelection ? '下载打包' : '下载上次打包'),
        ),
        AppActionMenu<String>(
          tooltip: '下载选项',
          framed: false,
          actions: const [AppMenuAction('copy', '复制下载链接', icon: AppIcons.copy)],
          onSelected: (_) async {
            await Clipboard.setData(
              ClipboardData(text: _zip!.download.toString()),
            );
            _message('下载链接已复制');
          },
        ),
      ],
    ];
    final normal = LayoutBuilder(
      builder: (context, bounds) {
        if (bounds.maxWidth >=
            840 *
                (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
                  1,
                  1.5,
                )) {
          return Row(
            children: [
              search,
              const SizedBox(width: 12),
              filter,
              const SizedBox(width: 8),
              select,
              const Spacer(),
              for (final action in actions)
                Padding(padding: const EdgeInsets.only(left: 8), child: action),
            ],
          );
        }
        return Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [search, filter, select, ...actions],
        );
      },
    );
    // Both modes participate in layout so selecting never shifts the table.
    return IndexedStack(
      index: _selected.isEmpty ? 0 : 1,
      alignment: Alignment.centerLeft,
      children: [
        normal,
        Wrap(
          spacing: AppSpace.md,
          runSpacing: AppSpace.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '已选 ${_selected.length} 人',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            TextButton(
              onPressed: blocked
                  ? null
                  : () => _changeSelection(() => _selected.clear()),
              child: const Text('取消选择'),
            ),
            FilledButton.icon(
              onPressed: blocked || _building ? null : _pack,
              icon: const Icon(Icons.archive_outlined, size: 18),
              label: const Text('打包所选'),
            ),
            actions.first,
            if (_downloadMatchesSelection) ...actions.skip(1),
          ],
        ),
      ],
    );
  }

  Widget _studentTableRow(
    TaStudent? student,
    List<TaStudent> visible, {
    bool heading = false,
    bool blocked = false,
  }) {
    final p = AppPalette.of(context);
    // Only the header needs roster-wide selection state. Student rows are
    // constructed while scrolling and must only read their own selection.
    final all =
        heading &&
        visible.isNotEmpty &&
        visible.every((s) => _selected.contains(s.id));
    final some =
        heading && (all || visible.any((s) => _selected.contains(s.id)));
    final score = student?.score?.toString().replaceFirst(RegExp(r'\.0$'), '');
    final grade =
        score ??
        (student?.scoreChecked == true || _summary.graded == 0 ? '未批改' : '待核对');
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: heading
            ? p.content
            : _selected.contains(student?.id)
            ? p.primary.withValues(alpha: .06)
            : null,
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: AppCheckbox(
              key: ValueKey('ta-select-${student?.id ?? 'all'}'),
              label: heading
                  ? (all ? '取消全选当前列表' : '全选当前列表')
                  : '选择 ${student!.name}',
              value: heading
                  ? all
                        ? true
                        : some
                        ? null
                        : false
                  : _selected.contains(student!.id),
              onChanged: blocked
                  ? null
                  : (v) => _changeSelection(() {
                      if (heading) {
                        if (all) {
                          _selected.removeAll(visible.map((s) => s.id));
                        } else {
                          _selected.addAll(visible.map((s) => s.id));
                        }
                      } else {
                        v == true
                            ? _selected.add(student!.id)
                            : _selected.remove(student!.id);
                      }
                    }),
            ),
          ),
          Expanded(
            flex: 3,
            child: AppTruncatedText(
              heading ? '姓名' : student!.name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: heading ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              heading ? '学号' : student!.number,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: p.muted),
            ),
          ),
          SizedBox(
            width: 84,
            child: Text(
              heading
                  ? '提交状态'
                  : student!.submitted
                  ? '已提交'
                  : '未提交',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: heading
                    ? p.muted
                    : student!.submitted
                    ? p.success
                    : p.muted,
              ),
            ),
          ),
          SizedBox(
            width: 96,
            child: heading
                ? Text(
                    '成绩',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: p.muted),
                  )
                : AppTableAction(
                    tooltip: '核对${student!.name}的成绩',
                    label: _checkingScores.contains(student.id) ? '核对中' : grade,
                    onPressed: blocked || _checkingScores.contains(student.id)
                        ? null
                        : () => _checkStudent(student),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.error, required this.retry});
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          error is StateError && (error as StateError).message == '请先登录'
              ? '请先登录后查看助教课程'
              : error is FormatException
              ? (error as FormatException).message
              : requestFailureMessage(error),
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: retry, child: const Text('重试')),
      ],
    ),
  );
}
