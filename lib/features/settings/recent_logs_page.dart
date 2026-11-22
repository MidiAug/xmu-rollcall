import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/app_sliver_group.dart';
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
        AppIconButton(
          tooltip: '刷新',
          icon: const Icon(Icons.refresh, size: 20),
          onPressed: () => setState(() {}),
        ),
      ],
      body: AppPageViewport(
        builder: (context, contentInsets) => ValueListenableBuilder<int>(
          valueListenable: AppLog.revision,
          builder: (context, _, _) {
            final unhealthy = !AppLog.sinkHealthy || AppLog.droppedCount > 0;
            final items = _filtered;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (unhealthy)
                  Material(
                    color: p.danger.withValues(alpha: 0.12),
                    child: Padding(
                      padding:
                          contentInsets +
                          EdgeInsets.symmetric(
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
                  padding:
                      contentInsets +
                      EdgeInsets.fromLTRB(
                        AppSpace.pageXOf(context),
                        AppSpace.md,
                        AppSpace.pageXOf(context),
                        AppSpace.sm,
                      ),
                  child: AppSearchField(
                    controller: _queryCtrl,
                    hintText: '搜索 opId / rollcallId',
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Expanded(
                  child: items.isEmpty
                      ? EmptyHint(
                          icon: AppIcons.document,
                          title: _query.trim().isEmpty ? '暂无日志' : '未找到相关日志',
                        )
                      : CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding:
                                  contentInsets +
                                  EdgeInsets.fromLTRB(
                                    AppSpace.pageXOf(context),
                                    8,
                                    AppSpace.pageXOf(context),
                                    AppSpace.xl,
                                  ),
                              sliver: AppSliverGroup(
                                sliver: SliverList.separated(
                                  itemCount: items.length,
                                  separatorBuilder: (_, _) => Divider(
                                    height: 1,
                                    color: p.divider,
                                    indent: 20,
                                    endIndent: 20,
                                  ),
                                  itemBuilder: (context, i) {
                                    final r = items[i];
                                    final metadata = [
                                      r.level,
                                      if (r.opId != null)
                                        'op=${r.opId!.length > 8 ? '${r.opId!.substring(0, 8)}…' : r.opId}',
                                      if (r.rollcallId != null)
                                        'rc=${r.rollcallId}',
                                      if (r.ok != null) r.ok! ? 'ok' : 'fail',
                                      if (r.status != null) 'HTTP ${r.status}',
                                      if (r.latencyMs != null)
                                        '${r.latencyMs}ms',
                                    ];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 16,
                                      ),
                                      child: LayoutBuilder(
                                        builder: (context, bounds) {
                                          final narrow =
                                              bounds.maxWidth <
                                              300 *
                                                  MediaQuery.textScalerOf(
                                                    context,
                                                  ).scale(1);
                                          final time = Text(
                                            _shortTime(r.ts),
                                            style: AppTypography.body.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: i == 0
                                                  ? p.primary
                                                  : p.muted,
                                            ),
                                          );
                                          final entry = Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              SelectableText(
                                                r.event,
                                                style: AppTypography.body
                                                    .copyWith(
                                                      color: p.ink,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                              ),
                                              const SizedBox(height: 6),
                                              Wrap(
                                                spacing: 12,
                                                runSpacing: 4,
                                                children: [
                                                  for (final bit in metadata)
                                                    Text(
                                                      bit,
                                                      style: AppTypography
                                                          .caption
                                                          .copyWith(
                                                            color: p.muted,
                                                          ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          );
                                          if (narrow) {
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                time,
                                                const SizedBox(height: 8),
                                                entry,
                                              ],
                                            );
                                          }
                                          return Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              SizedBox(
                                                width:
                                                    76 *
                                                    MediaQuery.textScalerOf(
                                                      context,
                                                    ).scale(1),
                                                child: time,
                                              ),
                                              Container(
                                                width: 1,
                                                height: 30,
                                                color: p.controlRim,
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(child: entry),
                                            ],
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
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
