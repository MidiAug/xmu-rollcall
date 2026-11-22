import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xmu_rollcall/app/app_checkbox.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/app/shell_tab_scope.dart';
import 'package:xmu_rollcall/core/network/request_failure.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'ta_batch.dart';
import 'ta_csv.dart';
import 'ta_csv_review_dialog.dart';
import 'ta_models.dart';
import 'ta_providers.dart';
import 'ta_repository.dart';
import 'ta_score_field.dart';
import 'ta_score_history_dialog.dart';
import 'ta_widgets.dart';

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
  final _searchController = TextEditingController();
  String _search = '';
  int _submissionFilter = 0;
  final _scoreDrafts = <int, String>{};
  final _localScores = <int, double>{};
  int? _savingStudent;
  bool _rosterReady = false, _refreshingRoster = false;
  TaZip? _zip, _oldZip;
  Set<int>? _requestedStudentIds, _packedStudentIds;
  bool _building = false, _zipBusy = false, _importing = false;
  String? _zipMessage;
  Timer? _poll;
  int _checks = 0;
  bool _zipCoolingDown = false;
  Timer? _zipCooldown;
  List<TaGradeRow> _rows = [];
  final _csvChanges = ValueNotifier<int>(0);
  String? _csvError;
  bool _overwrite = false, _allowUnsubmitted = false;
  final _batch = TaGradeBatch();

  List<int> get _packTargets => [
    for (final student in _students)
      if (student.submitted &&
          (_selected.isEmpty || _selected.contains(student.id)))
        student.id,
  ];

  bool get _downloadMatchesScope =>
      _zip?.download != null &&
      !_building &&
      _packedStudentIds != null &&
      setEquals(_packedStudentIds, _packTargets.toSet());
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _summary = widget.assignment;
    _repository = widget.repository.fork();
    _loading = _load();
  }

  Future<void> _load({bool refreshSummary = false}) async {
    _refreshingRoster = true;
    _localScores.clear();
    try {
      final cached = await _repository.restoreStudents(
        widget.courseId,
        widget.assignment.id,
      );
      if (!mounted || !_repository.active) return;
      if (cached != null && !_rosterReady) {
        _students = cached.students;
        _rosterReady = true;
        _changed();
      }
      final detail = await _repository.detail(
        widget.courseId,
        widget.assignment.id,
      );
      if (!mounted || !_repository.active) return;
      _detail = detail;
      // Activity detail has no count fields in the captured response. Counts
      // come from the course assignment list, never the parser's zero defaults.
      final assignments = await _repository.assignments(
        widget.courseId,
        refresh: refreshSummary,
      );
      if (!mounted || !_repository.active) return;
      _summary = assignments.firstWhere(
        (a) => a.id == widget.assignment.id,
        orElse: () => _summary,
      );
      _changed();
      final students = await _repository.students(
        widget.courseId,
        widget.assignment.id,
      );
      if (!mounted || !_repository.active) return;
      setState(() {
        _students = [
          for (final s in students)
            if (_localScores.containsKey(s.id))
              s.withScore(_localScores[s.id])
            else
              s,
        ];
        _rosterReady = true;
        _selected.removeWhere((id) => !_students.any((s) => s.id == id));
      });
      await _repository.cacheStudents(
        widget.courseId,
        widget.assignment.id,
        _students,
      );
      unawaited(_checkZip());
    } catch (_) {
      if (!mounted || !_repository.active) return;
      if (!_rosterReady) rethrow;
      _message('更新失败，保留已加载的名单和成绩');
    } finally {
      _refreshingRoster = false;
      _changed();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _zipCooldown?.cancel();
    _batch.stop();
    _csvChanges.dispose();
    _searchController.dispose();
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
    _csvChanges.value++;
  }

  void _message(String text) {
    if (mounted) {
      AppToast.show(context, text);
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
        if (!_building && (_zip?.id != zip.id || _zip?.key != zip.key)) {
          _packedStudentIds = null;
        }
        _zip = zip;
        if (_building && zip.download != null) {
          _packedStudentIds = _requestedStudentIds;
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
    if (_zipBusy || _building || _batch.running || !_repository.active) {
      return;
    }
    // Search and submission filters are only a view. Capture the complete
    // assignment scope before awaiting the previous package status.
    final targets = _packTargets;
    final all = _students.map((s) => s.id).toList();
    if (targets.isEmpty) {
      _message('当前范围没有已提交的学生');
      return;
    }
    _poll?.cancel();
    setState(() {
      _zipBusy = true;
      _zipMessage = null;
      _requestedStudentIds = targets.toSet();
      _packedStudentIds = null;
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
      await _repository.startZip(widget.assignment.id, targets, all);
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
    _csvChanges.value++;
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
    if (_batch.running || _savingStudent != null || !_repository.active) {
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
            student.withScore(saved[student.id])
          else
            student,
      ],
    );
    _localScores.addAll(saved);
    _scoreDrafts.removeWhere((id, _) => saved.containsKey(id));
    try {
      await _repository.cacheStudentScores(
        widget.courseId,
        widget.assignment.id,
        saved,
      );
    } catch (_) {
      if (!mounted || !_repository.active) return;
      rethrow;
    }
    if (!mounted || !_repository.active) return;
    await _refreshSummary();
  }

  Future<void> _refreshSummary() async {
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
      if (mounted && _repository.active) {
        _message('作业进度未更新，请稍后刷新');
      }
    }
  }

  Future<void> _saveInline(TaStudent student, String text) async {
    if (_batch.running ||
        _importing ||
        !_repository.active ||
        _detail?.canGrade != true ||
        _savingStudent != null) {
      return;
    }
    if (!student.submitted) {
      _message('未提交作业不能直接评分');
      return;
    }
    final score = text.trim();
    final issue = taPercentageScoreIssue(score);
    if (issue != null) {
      AppToast.show(context, issue, error: true);
      return;
    }
    _savingStudent = student.id;
    final row = TaGradeRow(
      line: 1,
      number: student.number,
      score: score,
      student: student,
    );
    widget.repository.markAssignmentsStale(widget.courseId);
    try {
      await _batch.run(
        repository: _repository,
        activityId: widget.assignment.id,
        rows: [row],
        overwrite: true,
        allowUnsubmitted: false,
        onChanged: _changed,
      );
      if (!mounted || !_repository.active) return;
      // A lost acknowledgement is resolved by a read, never by retrying a PUT.
      if (row.status == TaRowStatus.uncertain) {
        try {
          if (await _repository.currentScore(
                widget.assignment.id,
                student.id,
              ) ==
              double.parse(score)) {
            row.status = TaRowStatus.saved;
          }
        } catch (_) {
          /* Keep the draft when the server is still unavailable. */
        }
      }
      if (!mounted || !_repository.active) return;
      if (row.status == TaRowStatus.saved ||
          row.status == TaRowStatus.skipped) {
        final value = double.parse(score);
        setState(() {
          _localScores[student.id] = value;
          _scoreDrafts.remove(student.id);
          _students = [
            for (final s in _students)
              if (s.id == student.id) s.withScore(value) else s,
          ];
        });
        _message(
          row.status == TaRowStatus.saved ? '${student.name}的成绩已保存' : '成绩未变化',
        );
        await _repository.cacheStudentScores(
          widget.courseId,
          widget.assignment.id,
          {student.id: value},
        );
        await _refreshSummary();
      } else {
        AppToast.show(
          context,
          row.status == TaRowStatus.uncertain
              ? '成绩同步失败，输入已保留，请稍后刷新'
              : '保存失败，输入已保留',
          error: true,
        );
      }
    } catch (_) {
      if (mounted && _repository.active) {
        AppToast.show(context, '成绩同步失败，输入已保留', error: true);
      }
    } finally {
      _savingStudent = null;
      _changed();
    }
  }

  Future<void> _openScoreHistory(TaStudent student) async {
    if (!_repository.active) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          if (!identical(
                ref.watch(taRepositoryProvider).valueOrNull,
                widget.repository,
              ) ||
              !_repository.active) {
            return AppNoticeDialog(
              title: '当前页面已失效',
              message: '请返回后重新打开作业',
              onClose: () => Navigator.pop(context),
            );
          }
          return TaScoreHistoryDialog(
            repository: _repository,
            activityId: widget.assignment.id,
            student: student,
          );
        },
      ),
    );
  }

  Future<void> _openCsvReview() async {
    if (!_repository.active) {
      return;
    }
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
            return TaCsvReviewDialog(
              changes: _csvChanges,
              readRows: () => _rows,
              readError: () => _csvError,
              isImporting: () => _importing,
              isBatchRunning: () => _batch.running,
              readOverwrite: () => _overwrite,
              readAllowUnsubmitted: () => _allowUnsubmitted,
              onOverwriteChanged: (v) {
                _overwrite = v;
                _changed();
              },
              onAllowUnsubmittedChanged: (v) {
                _allowUnsubmitted = v;
                _changed();
              },
              onImport: _import,
              onSubmit: _submit,
              onStopBatch: () {
                _batch.stop();
                _changed();
              },
            );
          },
        ),
      );
    } finally {
      if (mounted) setState(() {});
    }
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
              if (snapshot.hasError && !_rosterReady) {
                return TaFailureView(
                  error: snapshot.error!,
                  retry: () => setState(() {
                    _loading = _load();
                  }),
                );
              }
              if (!_rosterReady) {
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
              final blocked =
                  _batch.running ||
                  _importing ||
                  _zipBusy ||
                  _savingStudent != null;
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 6, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                        key: const ValueKey('ta-roster-workspace'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: _studentToolbar(blocked),
                            ),
                            Divider(height: 1, color: p.border),
                            Expanded(
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
                                          key: const ValueKey(
                                            'ta-assignment-scroll',
                                          ),
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
                                          itemBuilder: (_, i) =>
                                              _studentTableRow(
                                                visible[i],
                                                visible,
                                                blocked: blocked,
                                              ),
                                        ),
                                      ),
                                    ],
                                  );
                                  if (bounds.maxWidth >= 760) {
                                    return table;
                                  }
                                  // Desktop ScrollView already provides a themed scrollbar
                                  // attached to its own horizontal position.
                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: 760,
                                      height: bounds.maxHeight,
                                      child: table,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
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
    });
  }

  Future<void> _downloadPackage() async {
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
  }

  Widget _studentToolbar(bool blocked) {
    final p = AppPalette.of(context);
    final selected = _selected.isNotEmpty;
    final targets = _packTargets;
    final style =
        Theme.of(context).textTheme.labelLarge ?? AppTypography.control;
    final digits = List.filled(_students.length.toString().length, '8').join();
    double labelWidth(String label) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final width = painter.width.ceilToDouble();
      painter.dispose();
      return width;
    }

    // Reserve the largest count in this roster so selecting, clearing and
    // changing the eligible subset do not move the table header.
    final packLabelWidth = labelWidth('打包全部已提交 $digits');
    final downloadLabelWidth = labelWidth('下载打包');
    final packWidth =
        (packLabelWidth > downloadLabelWidth
            ? packLabelWidth
            : downloadLabelWidth) +
        48;
    final importWidth = labelWidth('导入成绩') + 48;
    final selectionWidth = labelWidth('已选 $digits 人') + AppSpace.xs + 32;
    final extent = AppDensity.controlHeight(context);
    final hasDownload = _zip?.download != null && !_building;
    final pack = AppButton(
      key: const ValueKey('ta-pack'),
      compact: true,
      kind: selected ? AppButtonKind.primary : AppButtonKind.secondary,
      label: _downloadMatchesScope
          ? '下载打包'
          : '${selected ? '打包所选已提交' : '打包全部已提交'} ${targets.length}',
      icon: _downloadMatchesScope ? AppIcons.download : AppIcons.archive,
      onPressed: _downloadMatchesScope
          ? _downloadPackage
          : blocked || _building || targets.isEmpty
          ? null
          : _pack,
    );
    final importAction = AppButton(
      compact: true,
      label: '导入成绩',
      kind: selected ? AppButtonKind.secondary : AppButtonKind.primary,
      icon: AppIcons.upload,
      onPressed:
          _detail?.canGrade != true || _batch.running || _savingStudent != null
          ? null
          : _openCsvReview,
    );
    final selection = SizedBox(
      width: selectionWidth,
      height: extent,
      child: selected
          ? Row(
              children: [
                Expanded(
                  child: Text(
                    '已选 ${_selected.length} 人',
                    style: style.copyWith(color: p.ink),
                  ),
                ),
                const SizedBox(width: AppSpace.xs),
                AppIconButton(
                  tooltip: '取消选择',
                  extent: 32,
                  icon: const Icon(AppIcons.close, size: 15),
                  onPressed: blocked
                      ? null
                      : () => _changeSelection(() => _selected.clear()),
                ),
              ],
            )
          : null,
    );
    final menu = SizedBox(
      width: extent,
      child: hasDownload
          ? AppActionMenu<String>(
              tooltip: '下载选项',
              enabled: !blocked && !_building,
              actions: [
                if (_downloadMatchesScope)
                  const AppMenuAction(
                    'repack',
                    '重新打包当前范围',
                    icon: AppIcons.archive,
                  ),
                if (!_downloadMatchesScope)
                  const AppMenuAction(
                    'download',
                    '下载上次打包',
                    icon: AppIcons.download,
                  ),
                const AppMenuAction('copy', '复制下载链接', icon: AppIcons.copy),
              ],
              onSelected: (action) async {
                if (action == 'repack') {
                  if (!blocked && !_building && targets.isNotEmpty) {
                    await _pack();
                  }
                } else if (action == 'download') {
                  await _downloadPackage();
                } else {
                  await Clipboard.setData(
                    ClipboardData(text: _zip!.download.toString()),
                  );
                  _message('下载链接已复制');
                }
              },
            )
          : null,
    );
    return LayoutBuilder(
      builder: (context, bounds) {
        final filterWidth = (112 * MediaQuery.textScalerOf(context).scale(1))
            .clamp(0.0, bounds.maxWidth);
        final controlsWidth = 230 + filterWidth + extent * 2 + AppSpace.xs * 3;
        final operationsWidth =
            packWidth + importWidth + selectionWidth + AppSpace.xs * 2;
        return Wrap(
          key: const ValueKey('ta-roster-toolbar'),
          spacing: AppSpace.md,
          runSpacing: AppSpace.xs,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: controlsWidth.clamp(0.0, bounds.maxWidth),
              child: Wrap(
                spacing: AppSpace.xs,
                runSpacing: AppSpace.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: bounds.maxWidth.clamp(0.0, 230.0),
                    child: AppSearchField(
                      controller: _searchController,
                      compact: true,
                      hintText: '搜索姓名或学号',
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  AppShellSelect<int>(
                    key: const ValueKey('ta-submission-filter'),
                    semanticLabel: '筛选提交状态',
                    value: _submissionFilter,
                    items: const [0, 1, 2],
                    labelOf: (v) => ['全部学生', '已提交', '未提交'][v],
                    width: filterWidth,
                    menuWidth: 160,
                    compact: false,
                    onChanged: (v) => setState(() => _submissionFilter = v),
                  ),
                  AppRefreshButton(
                    extent: extent,
                    tooltip: '更新名单和成绩',
                    busy: _refreshingRoster || _savingStudent != null,
                    onRefresh: () async {
                      if (_batch.running ||
                          _refreshingRoster ||
                          _savingStudent != null) {
                        return;
                      }
                      final pending = _load(refreshSummary: true);
                      setState(() {
                        _loading = pending;
                      });
                      await pending;
                    },
                  ),
                  menu,
                ],
              ),
            ),
            SizedBox(
              width:
                  controlsWidth + operationsWidth + AppSpace.md >
                      bounds.maxWidth
                  ? bounds.maxWidth
                  : operationsWidth,
              child: Wrap(
                spacing: AppSpace.xs,
                runSpacing: AppSpace.xs,
                alignment: operationsWidth <= bounds.maxWidth
                    ? WrapAlignment.end
                    : WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (operationsWidth <= bounds.maxWidth) selection,
                  SizedBox(
                    width: packWidth.clamp(0.0, bounds.maxWidth),
                    child: pack,
                  ),
                  SizedBox(
                    width: importWidth.clamp(0.0, bounds.maxWidth),
                    child: importAction,
                  ),
                  if (operationsWidth > bounds.maxWidth) selection,
                ],
              ),
            ),
          ],
        );
      },
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
    final score =
        student?.score?.toString().replaceFirst(RegExp(r'\.0$'), '') ?? '';
    return Container(
      key: ValueKey('ta-row-${student?.id ?? 'header'}'),
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
          SizedBox(
            width: 148,
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
            width: 96,
            child: heading
                ? Text('状态', style: TextStyle(color: p.muted, fontSize: 12))
                : Row(
                    children: [
                      Text(
                        student!.submitted ? '已交' : '未交',
                        style: TextStyle(
                          fontSize: 12,
                          color: student.submitted ? p.success : p.muted,
                        ),
                      ),
                      if (student.hasAttachments) ...[
                        const SizedBox(width: 6),
                        AppTooltipAnchor(
                          child: Tooltip(
                            message: '有附件',
                            child: Icon(
                              AppIcons.attachment,
                              size: 14,
                              color: p.muted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          SizedBox(
            width: 96,
            child: Text(
              heading ? '附件大小' : taAttachmentSize(student!.attachmentBytes),
              style: TextStyle(color: p.muted, fontSize: 12),
            ),
          ),
          SizedBox(
            width: 108,
            child: heading
                ? Text('成绩', style: TextStyle(color: p.muted, fontSize: 12))
                : Padding(
                    padding: const EdgeInsets.only(right: 4, top: 5, bottom: 5),
                    child: TaScoreField(
                      key: ValueKey('ta-score-${student!.id}'),
                      name: student.name,
                      showDisabledField: !student.submitted,
                      value: _scoreDrafts[student.id] ?? score,
                      hint: !student.submitted
                          ? '未提交'
                          : student.scoreChecked
                          ? '未评分'
                          : '—',
                      enabled:
                          !blocked &&
                          _detail?.canGrade == true &&
                          student.submitted,
                      saving: _savingStudent == student.id,
                      readOnlyReason: !student.submitted
                          ? '未提交'
                          : _detail == null
                          ? '正在核对评分权限'
                          : !_detail!.canGrade
                          ? '本作业只读'
                          : null,
                      onChanged: (v) => _scoreDrafts[student.id] = v,
                      onSubmitted: (v) => _saveInline(student, v),
                    ),
                  ),
          ),
          SizedBox(
            width: 40,
            child: heading
                ? Text('操作', style: TextStyle(color: p.muted, fontSize: 12))
                : Align(
                    alignment: Alignment.centerLeft,
                    child: AppIconButton(
                      key: ValueKey('ta-score-history-${student!.id}'),
                      tooltip: '查看评分记录',
                      extent: 32,
                      icon: const Icon(AppIcons.history, size: 18),
                      onPressed: _savingStudent != null || _batch.running
                          ? null
                          : () => _openScoreHistory(student),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
