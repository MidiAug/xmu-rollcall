import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/features/schedule/academic_calendar.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/schedule/semester_preferences.dart';

String shortScheduleDate(DateTime value) => '${value.month}月${value.day}日';

class SemesterSettingsPage extends ConsumerStatefulWidget {
  const SemesterSettingsPage({
    super.key,
    required this.userId,
    required this.ownerId,
  });
  final int userId, ownerId;
  @override
  ConsumerState<SemesterSettingsPage> createState() =>
      _SemesterSettingsPageState();
}

class _SemesterSettingsPageState extends ConsumerState<SemesterSettingsPage> {
  String? _term;
  DateTime? _manual, _default;
  bool _busy = true;
  String? _error;
  int _loadId = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([String? term]) async {
    final generation = ++_loadId;
    final raw = await AcademicScheduleStore.read(
      widget.userId,
      useUserStart: false,
    );
    final selected = term ?? raw?.term ?? currentSemester(DateTime.now());
    final manual = await SemesterPreferences.read(widget.userId, selected);
    if (!mounted || generation != _loadId) return;
    setState(() {
      _term = selected;
      _manual = manual;
      _default =
          academicMondays[selected] ??
          (raw?.term == selected && raw?.anchorFromUser != true
              ? raw?.monday
              : null);
      _busy = false;
    });
  }

  Future<void> _save(DateTime? value) async {
    final term = _term;
    if (term == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SemesterPreferences.save(
        widget.userId,
        term,
        value,
        requireCurrent: () {
          if (!mounted) throw StateError('页面已关闭');
          final auth = ref.read(authControllerProvider);
          if (!auth.isSignedIn ||
              auth.profile?.id != widget.ownerId ||
              (widget.userId != widget.ownerId &&
                  !ref
                      .read(assistControllerProvider)
                      .identities
                      .any((i) => i.userId == widget.userId))) {
            throw StateError('账号已变化，请重新打开');
          }
        },
      );
      if (!mounted) return;
      ref.read(academicRevisionProvider.notifier).state++;
      setState(() {
        _manual = value;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '日期未保存，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose() async {
    final initial =
        _manual ??
        _default ??
        DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
    final chosen = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 2),
      lastDate: DateTime(initial.year + 2, 12, 31),
      selectableDayPredicate: (day) => day.weekday == 1,
      helpText: '选择第1周的周一',
      cancelText: '取消',
      confirmText: '确定',
      fieldLabelText: '日期',
      errorFormatText: '请输入有效日期',
      errorInvalidText: '请选择周一',
      builder: (context, child) => Localizations.override(
        context: context,
        locale: const Locale('zh', 'CN'),
        delegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        child: child!,
      ),
    );
    if (chosen != null && mounted) await _save(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    final terms = <String>{
      ?_term,
      for (var y = year - 1; y <= year + 1; y++)
        for (var s = 1; s <= 3; s++) '$y$s',
    }.toList()..sort();
    final value = _manual ?? _default;
    final now = semesterDate(DateTime.now());
    final week = value == null ? null : now.difference(value).inDays ~/ 7 + 1;
    return SubpageScaffold(
      title: '学期设置',
      isBusy: () => _busy,
      body: AppPageViewport(
        maxWidth: 600,
        builder: (context, contentInsets) => ListView(
          padding: contentInsets + const EdgeInsets.all(20),
          children: [
            const Text('学期'),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) => AppShellSelect<String>(
                key: ValueKey('semester-$_term'),
                value: _term ?? terms.first,
                width: constraints.maxWidth,
                items: terms,
                labelOf: semesterLabel,
                semanticLabel: '选择学期',
                onChanged: _busy ? null : _load,
              ),
            ),
            const SizedBox(height: 20),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '第一周起始日',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text('第1周的周一', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const ValueKey('choose-first-monday'),
                    onPressed: _busy ? null : _choose,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(
                      value == null
                          ? '选择日期'
                          : '${value.year}年${shortScheduleDate(value)}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _manual != null
                        ? '手动设置'
                        : _default == null
                        ? '默认校历尚未更新'
                        : academicMondays.containsKey(_term)
                        ? '默认校历'
                        : '教务周次',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_term != null)
                    Text(
                      '本学期${semesterWeeks(_term!)}周${academicTerms.containsKey(_term) ? '' : '（估算）'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (week != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        now.isBefore(value!)
                            ? '尚未开课'
                            : week > semesterWeeks(_term!)
                            ? '学期已结束'
                            : '当前第$week周',
                      ),
                    ),
                  if (_manual != null && _default != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _busy ? null : () => _save(null),
                        child: const Text('恢复默认'),
                      ),
                    ),
                ],
              ),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!),
              ),
          ],
        ),
      ),
    );
  }
}
