import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
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

class TaGradingPage extends ConsumerWidget {
  const TaGradingPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(taRepositoryProvider);
    final courses = ref.watch(currentTeachingCoursesProvider);
    return PageScaffold(
      title: '修改作业',
      subtitle: '研究生助教',
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
  DateTime? _lastRefresh;
  void _select(int id) {
    setState(() {
      _course = id;
      _lastRefresh = DateTime.now();
      _assignments = widget.repository.assignments(id);
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.courses.isNotEmpty) {
      _course = int.tryParse(widget.courses.first.id);
      if (_course != null) {
        _lastRefresh = DateTime.now();
        _assignments = widget.repository.assignments(_course!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.courses.isEmpty) {
      return const Center(child: Text('当前身份没有教师或助教课程'));
    }
    return AppContentColumn(
      maxWidth: 1040,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('助教课程', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final course in widget.courses)
                      SizedBox(
                        width: 230,
                        child: Material(
                          color: '${_course ?? ''}' == course.id
                              ? Theme.of(context).colorScheme.secondaryContainer
                              : Theme.of(context).colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              final id = int.tryParse(course.id);
                              if (id != null) _select(id);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Icon(
                                    '${_course ?? ''}' == course.id
                                        ? Icons.check_circle_outline
                                        : Icons.school_outlined,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: AppTruncatedText(course.title),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(child: Text('查看提交与批改进度，选择作业开始处理')),
                    IconButton(
                      tooltip: '更新作业',
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        if (_course != null &&
                            DateTime.now().difference(
                                  _lastRefresh ?? DateTime(2000),
                                ) >=
                                const Duration(seconds: 5)) {
                          _select(_course!);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<TaAssignment>>(
              key: ValueKey((_course, _assignments)),
              future: _assignments,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _Failure(
                    error: snapshot.error!,
                    retry: () => _select(_course!),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final assignments = snapshot.requireData;
                if (assignments.isEmpty) {
                  return const Center(child: Text('这门课还没有作业'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: assignments.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final item = assignments[i];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () async {
                          final course = _course!;
                          await AppPageRoutes.push(
                            context,
                            TaAssignmentPage(
                              repository: widget.repository,
                              courseId: course,
                              assignment: item,
                            ),
                          );
                          if (mounted &&
                              widget.repository.active &&
                              _course == course) {
                            _select(course);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: AppTruncatedText(
                                      item.title,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 18,
                                runSpacing: 8,
                                children: [
                                  Text('应交 ${item.expected}'),
                                  Text('已提交 ${item.submitted}'),
                                  Text(
                                    '未提交 ${(item.expected - item.submitted).clamp(0, item.expected)}',
                                  ),
                                  Text('已批改 ${item.graded}'),
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
          ),
        ],
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
  final _checkingScores = <int>{};
  TaZip? _zip, _oldZip;
  bool _building = false, _zipBusy = false, _importing = false;
  String? _zipMessage;
  Timer? _poll;
  int _checks = 0;
  bool _zipCoolingDown = false;
  Timer? _zipCooldown;
  List<TaGradeRow> _rows = [];
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
    if (!mounted) return;
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
    if (_zipCoolingDown) return;
    _zipCoolingDown = true;
    _zipCooldown?.cancel();
    _zipCooldown = Timer(const Duration(seconds: 5), () {
      _zipCoolingDown = false;
      _changed();
    });
    _zipBusy = true;
    try {
      final zip = await _repository.zipStatus(widget.assignment.id);
      if (!mounted) return;
      final fresh =
          _oldZip == null || zip.id != _oldZip!.id || zip.key != _oldZip!.key;
      if (!_building || fresh && zip.download != null) {
        _zip = zip;
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
    if (_zipBusy || _batch.running || !_repository.active) return;
    _poll?.cancel();
    setState(() {
      _zipBusy = true;
      _zipMessage = null;
    });
    try {
      // Obtain a baseline immediately before re-packaging; stale ready packages
      // remain hidden until the server returns a different package identity.
      _oldZip = await _repository.zipStatus(widget.assignment.id);
      if (!mounted) return;
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
    if (_batch.running || _importing || !_repository.active) return;
    setState(() => _importing = true);
    try {
      final text = await ref.read(taCsvReaderProvider)();
      if (text == null || !mounted || !_repository.active) return;
      final rows = parseTaCsv(text, _students);
      setState(() {
        _rows = rows;
        _overwrite = false;
        _allowUnsubmitted = false;
      });
    } on FormatException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('无法读取 CSV，请检查文件编码与访问权限');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _submit() async {
    if (_batch.running || !_repository.active) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认提交成绩'),
        content: Text(
          '作业：${widget.assignment.title}\n将逐条处理 ${_rows.where((r) => r.status == TaRowStatus.ready).length} 行成绩。'
          '\n${_overwrite ? '允许覆盖已有成绩' : '已有成绩将跳过'}'
          '\n${_allowUnsubmitted ? '允许为未提交学生评分' : '未提交学生将跳过'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认提交'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted || !_repository.active) return;
    await _batch.run(
      repository: _repository,
      activityId: widget.assignment.id,
      rows: _rows,
      overwrite: _overwrite,
      allowUnsubmitted: _allowUnsubmitted,
      onChanged: _changed,
    );
    if (!mounted || !_repository.active) return;
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
      final assignments = await _repository.assignments(widget.courseId);
      if (!mounted) return;
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
      if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    if (!identical(
      ref.watch(taRepositoryProvider).valueOrNull,
      widget.repository,
    )) {
      return const PageScaffold(
        title: '修改作业',
        child: Center(child: Text('账号已变更，请返回重新选择课程')),
      );
    }
    if (!_repository.active) {
      return const PageScaffold(
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
        title: '批改作业',
        subtitle: widget.assignment.title,
        child: FutureBuilder<void>(
          future: _loading,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _Failure(
                error: snapshot.error!,
                retry: () {
                  setState(() => _loading = _load());
                },
              );
            }
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final visible = _students
                .where((s) => '${s.number} ${s.name}'.contains(_search))
                .toList();
            final blocked = _batch.running || _importing || _zipBusy;
            return AppContentColumn(
              maxWidth: 1100,
              child: ListView(
                key: const ValueKey('ta-assignment-scroll'),
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    widget.assignment.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 18,
                    runSpacing: 8,
                    children: [
                      Text('学生 ${_students.length}'),
                      Text('已提交 ${_students.where((s) => s.submitted).length}'),
                      Text('已批改 ${_summary.graded}'),
                      Text(
                        '待批改 ${(_summary.submitted - _summary.graded).clamp(0, _summary.submitted)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _Panel(
                    title: '学生作业',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: '搜索学号或姓名',
                          ),
                          onChanged: (value) => setState(() => _search = value),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TextButton(
                              onPressed: blocked
                                  ? null
                                  : () => setState(
                                      () => _selected.addAll(
                                        visible
                                            .where((s) => s.submitted)
                                            .map((s) => s.id),
                                      ),
                                    ),
                              child: const Text('选择已提交学生'),
                            ),
                            TextButton(
                              onPressed: blocked
                                  ? null
                                  : () => setState(() => _selected.clear()),
                              child: const Text('清空选择'),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text('已选 ${_selected.length} 人'),
                            ),
                          ],
                        ),
                        const Divider(),
                        SizedBox(
                          height: (visible.length * 82.0).clamp(82, 500),
                          child: ListView.builder(
                            primary: false,
                            itemCount: visible.length,
                            itemBuilder: (context, index) {
                              final student = visible[index];
                              return CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                value: _selected.contains(student.id),
                                onChanged: blocked
                                    ? null
                                    : (value) => setState(() {
                                        value == true
                                            ? _selected.add(student.id)
                                            : _selected.remove(student.id);
                                      }),
                                title: Text(
                                  '${student.name}  ${student.number}',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                subtitle: Wrap(
                                  spacing: 10,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      '${student.submitted ? '已提交' : '未提交'}'
                                      '\n${student.score != null
                                          ? '已批改 ${student.score} 分'
                                          : student.scoreChecked || _summary.graded == 0
                                          ? '未批改'
                                          : '批改状态待核对'}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    TextButton(
                                      onPressed:
                                          blocked ||
                                              _checkingScores.contains(
                                                student.id,
                                              )
                                          ? null
                                          : () => _checkStudent(student),
                                      child: Text(
                                        _checkingScores.contains(student.id)
                                            ? '核对中'
                                            : '核对成绩',
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        if (visible.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('没有匹配的学生'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Panel(
                    title: '打包下载',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _zipMessage ??
                              (_building
                                  ? '服务器正在打包'
                                  : _zip?.download != null
                                  ? '打包已完成'
                                  : '选择学生后打包，可随时检查已有包状态'),
                        ),
                        const SizedBox(height: 6),
                        const Text('已有包对应上一次打包，改变学生选择后请重新打包。'),
                        if (_building)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: LinearProgressIndicator(),
                          ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              onPressed: blocked || _selected.isEmpty
                                  ? null
                                  : _pack,
                              icon: const Icon(Icons.archive_outlined),
                              label: Text(
                                _zip?.download != null || _building
                                    ? '重新打包'
                                    : '打包',
                              ),
                            ),
                            OutlinedButton(
                              onPressed:
                                  _zipBusy || _batch.running || _zipCoolingDown
                                  ? null
                                  : _checkZip,
                              child: const Text('检查打包状态'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _zip?.download == null || _building
                                  ? null
                                  : () async {
                                      final uri = _zip!.download!;
                                      try {
                                        if (!await launchUrl(
                                          uri,
                                          mode: LaunchMode.externalApplication,
                                        )) {
                                          _message('无法打开下载，请复制链接到浏览器');
                                        }
                                      } catch (_) {
                                        _message('无法打开下载，请复制链接到浏览器');
                                      }
                                    },
                              icon: const Icon(Icons.download),
                              label: const Text('下载打包'),
                            ),
                            TextButton(
                              onPressed: _zip?.download == null || _building
                                  ? null
                                  : () async {
                                      await Clipboard.setData(
                                        ClipboardData(
                                          text: _zip!.download.toString(),
                                        ),
                                      );
                                      _message('下载链接已复制');
                                    },
                              child: const Text('复制下载链接'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Panel(
                    title: 'CSV 批量评分',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '两列：user_no,score\n学号保持文本格式，分数为 0 至 100。先预览，再确认提交。',
                        ),
                        const SizedBox(height: 12),
                        if (_detail?.canGrade != true)
                          const Text('当前仅支持普通个人百分制作业，小组、量规和互评作业请在网页处理。'),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            OutlinedButton.icon(
                              onPressed: blocked || _detail?.canGrade != true
                                  ? null
                                  : _import,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('导入 CSV'),
                            ),
                            TextButton(
                              onPressed: () async {
                                await Clipboard.setData(
                                  const ClipboardData(
                                    text:
                                        'user_no,score\nDEMO0001,86\nDEMO0002,90\n',
                                  ),
                                );
                                _message('虚构 CSV 示例已复制，请替换为实际学号与成绩');
                              },
                              child: const Text('复制格式示例'),
                            ),
                          ],
                        ),
                        if (_rows.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '允许覆盖已有成绩',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            value: _overwrite,
                            onChanged: _batch.running
                                ? null
                                : (v) => setState(() => _overwrite = v!),
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '允许为未提交作业的学生评分',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            value: _allowUnsubmitted,
                            onChanged: _batch.running
                                ? null
                                : (v) => setState(() => _allowUnsubmitted = v!),
                          ),
                          Text(
                            '共 ${_rows.length} 行，错误 ${_rows.where((r) => r.issue != null).length} 行，已保存 ${_rows.where((r) => r.status == TaRowStatus.saved).length} 行',
                          ),
                          if (_batch.running) const LinearProgressIndicator(),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: (_rows.length * 62.0).clamp(62, 320),
                            child: ListView.builder(
                              primary: false,
                              itemCount: _rows.length,
                              itemBuilder: (context, index) {
                                final row = _rows[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 7,
                                  ),
                                  child: Text(
                                    '第 ${row.line} 行  ${row.number}  ${row.student?.name ?? ''}  ${row.score} 分\n'
                                    '${row.issue ?? row.result ?? '待提交'}',
                                    style: TextStyle(
                                      color:
                                          row.issue != null ||
                                              row.status ==
                                                  TaRowStatus.uncertain ||
                                              row.status == TaRowStatus.failed
                                          ? p.danger
                                          : p.ink,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton(
                                onPressed:
                                    blocked ||
                                        _building ||
                                        !_repository.active ||
                                        _rows.any(
                                          (r) =>
                                              r.issue != null ||
                                              r.status == TaRowStatus.failed ||
                                              r.status == TaRowStatus.uncertain,
                                        ) ||
                                        !_rows.any(
                                          (r) => r.status == TaRowStatus.ready,
                                        )
                                    ? null
                                    : _submit,
                                child: const Text('预览确认并提交'),
                              ),
                              if (_batch.running)
                                OutlinedButton(
                                  onPressed: () {
                                    _batch.stop();
                                    _message('将停止后续提交，正在处理的这一行会完成核对');
                                  },
                                  child: const Text('停止后续提交'),
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
          },
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
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
