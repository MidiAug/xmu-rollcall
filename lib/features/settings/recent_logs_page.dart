import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/core/logging/log_record.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// Recent diagnostic events (short fields). Search by opId / rollcallId.
///
/// Listens to [AppLog.revision] so new events appear without leaving the page.
class RecentLogsPage extends ConsumerStatefulWidget {
  const RecentLogsPage({super.key});

  @override
  ConsumerState<RecentLogsPage> createState() => _RecentLogsPageState();
}

class _RecentLogsPageState extends ConsumerState<RecentLogsPage> {
  final _queryCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  List<LogRecord> get _filtered {
    final q = _query.trim();
    if (q.isEmpty) return AppLog.index.recent;
    final asInt = int.tryParse(q);
    return AppLog.index.search(
      query: q,
      rollcallId: asInt,
      opId: asInt == null ? q : null,
    );
  }

  String _shortTime(DateTime ts) {
    final t = ts.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return SubpageScaffold(
      title: '最近日志',
      actions: [
        IconButton(
          tooltip: '刷新',
          icon: const Icon(Icons.refresh, size: 20),
          onPressed: () => setState(() {}),
        ),
      ],
      body: AppContentColumn(
        child: ValueListenableBuilder<int>(
          valueListenable: AppLog.revision,
          builder: (context, _, _) {
            final unhealthy =
                !AppLog.sinkHealthy || AppLog.droppedCount > 0;
            final items = _filtered;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (unhealthy)
                  Material(
                    color: p.danger.withValues(alpha: 0.12),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpace.pageXOf(context),
                        vertical: AppSpace.sm,
                      ),
                      child: Text(
                        '部分日志未持久化，导出可能不完整',
                        style: TextStyle(color: p.danger, fontSize: 13),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpace.pageXOf(context),
                    AppSpace.md,
                    AppSpace.pageXOf(context),
                    AppSpace.sm,
                  ),
                  child: TextField(
                    controller: _queryCtrl,
                    decoration: const InputDecoration(
                      hintText: '搜索 opId / rollcallId',
                      prefixIcon: Icon(Icons.search, size: 20),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Text(
                            '暂无日志\n登录 / 签到 / 轮询后会出现',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: p.muted),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            AppSpace.pageXOf(context),
                            0,
                            AppSpace.pageXOf(context),
                            AppSpace.xl,
                          ),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            color: p.border,
                          ),
                          itemBuilder: (context, i) {
                            final r = items[i];
                            final bits = <String>[
                              r.level,
                              r.event,
                              if (r.opId != null)
                                'op=${r.opId!.length > 8 ? '${r.opId!.substring(0, 8)}…' : r.opId}',
                              if (r.rollcallId != null) 'rc=${r.rollcallId}',
                              if (r.ok != null) (r.ok! ? 'ok' : 'fail'),
                              if (r.status != null) 'HTTP ${r.status}',
                              if (r.latencyMs != null) '${r.latencyMs}ms',
                            ];
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                bits.join(' · '),
                                style:
                                    const TextStyle(fontSize: 13, height: 1.35),
                              ),
                              subtitle: Text(
                                _shortTime(r.ts),
                                style:
                                    TextStyle(color: p.muted, fontSize: 11),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
