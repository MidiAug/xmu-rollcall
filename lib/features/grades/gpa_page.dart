import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'grade_models.dart';
import 'grade_providers.dart';

class GpaPage extends ConsumerStatefulWidget {
  const GpaPage({super.key});
  @override
  ConsumerState<GpaPage> createState() => _GpaPageState();
}

class _GpaPageState extends ConsumerState<GpaPage> {
  final _excluded = <String>{};
  int? _uid;
  String? _term, _error;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final auth = ref.watch(authControllerProvider);
    final uid = ref.watch(selectedRollcallAccountProvider) ?? auth.profile?.id;
    if (_uid != uid) {
      _uid = uid;
      _term = null;
      _error = null;
      _excluded.clear();
    }
    final data = auth.isSignedIn ? ref.watch(gradeSnapshotProvider) : null;
    return SubpageScaffold(
      title: 'GPA 计算器',
      actions: [
        if (auth.isSignedIn)
          AppRefreshButton(
            tooltip: '更新成绩',
            onRefresh: () async {
              setState(() => _error = null);
              try {
                await ref.read(gradeSnapshotProvider.notifier).refresh();
              } catch (_) {
                if (mounted &&
                    (ref.read(selectedRollcallAccountProvider) ??
                            ref.read(authControllerProvider).profile?.id) ==
                        uid) {
                  setState(() => _error = '更新失败，请稍后重试；已有成绩仍保留');
                }
              }
            },
          ),
      ],
      body: !auth.isSignedIn
          ? const EmptyHint(
              icon: AppIcons.person,
              title: '请先登录',
              detail: '成绩使用当前选中账号的教务会话',
            )
          : data!.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => EmptyHint(
                icon: AppIcons.document,
                title: '暂时无法读取成绩',
                detail: error is FormatException
                    ? error.message
                    : '请稍后重试，或重新登录当前账号以连接教务',
                action: FilledButton(
                  onPressed: () => ref.invalidate(gradeSnapshotProvider),
                  child: const Text('重试'),
                ),
              ),
              data: (snapshot) {
                final terms =
                    snapshot.records
                        .map((r) => r.term)
                        .where((t) => t.isNotEmpty)
                        .toSet()
                        .toList()
                      ..sort((a, b) => b.compareTo(a));
                final visible = snapshot.records
                    .where((r) => _term == null || r.term == _term)
                    .toList();
                final included = visible
                    .where((r) => r.eligible && !_excluded.contains(r.id))
                    .toList();
                final summary = calculateGpa(included);
                return AppContentColumn(
                  maxWidth: 960,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '成绩保存在本机，按所选课程计算',
                              style: TextStyle(color: p.muted, fontSize: 12),
                            ),
                          ),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _term ?? '',
                              items: [
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('全部学期'),
                                ),
                                for (final term in terms)
                                  DropdownMenuItem(
                                    value: term,
                                    child: Text(_termLabel(term)),
                                  ),
                              ],
                              onChanged: (value) => setState(
                                () => _term = value == '' ? null : value,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, bounds) => Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final metric in [
                              (
                                '加权 GPA',
                                summary.gpa?.toStringAsFixed(3) ?? '—',
                              ),
                              (
                                '加权均分',
                                summary.average?.toStringAsFixed(2) ?? '—',
                              ),
                              ('计入学分', summary.credits.toStringAsFixed(1)),
                            ])
                              SizedBox(
                                width: bounds.maxWidth >= 600
                                    ? (bounds.maxWidth - 24) / 3
                                    : bounds.maxWidth,
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: p.surface,
                                    border: Border.all(color: p.border),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        metric.$1,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: p.muted,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        metric.$2,
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w600,
                                          color: p.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '更新于 ${snapshot.at.toLocal().toString().substring(0, 16)}',
                        style: TextStyle(fontSize: 12, color: p.muted),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _error ??
                            ref.read(gradeSnapshotProvider.notifier).warning ??
                            '按教务返回的有效成绩、绩点和学分加权；无绩点的课程不计入。可勾选课程调整，结果仅供参考。',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: _error == null ? p.muted : p.danger,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '课程 ${included.length}/${visible.length}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: p.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (visible.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              '暂无已公布成绩',
                              style: TextStyle(color: p.muted),
                            ),
                          ),
                        )
                      else
                        for (final row in visible)
                          Column(
                            children: [
                              CheckboxListTile(
                                key: ValueKey('grade-${row.id}'),
                                value:
                                    row.eligible && !_excluded.contains(row.id),
                                onChanged: row.eligible
                                    ? (value) => setState(
                                        () => value == true
                                            ? _excluded.remove(row.id)
                                            : _excluded.add(row.id),
                                      )
                                    : null,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  row.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                subtitle: Text(
                                  '${_termLabel(row.term)}  ${row.credits} 学分',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                secondary: SizedBox(
                                  width: 90,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        row.score,
                                        style: TextStyle(
                                          color: p.ink,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        row.points == null
                                            ? '无绩点'
                                            : '绩点 ${row.points!.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: p.muted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Divider(height: 1, color: p.border),
                            ],
                          ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _termLabel(String term) {
    final parts = term.split('-');
    if (parts.length != 3) return term;
    final year = int.tryParse(parts[0]);
    if (year == null) return term;
    return '${parts[2] == '1' ? year : year + 1}年${{'1': '秋季', '2': '春季', '3': '夏季'}[parts[2]] ?? ''}学期';
  }
}
