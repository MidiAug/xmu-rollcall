import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/browser/browser_session.dart';
import 'package:xmu_rollcall/features/browser/campus_web_page.dart';
import 'lecture_provider.dart';
import 'lecture_requirement_provider.dart';

String _when(String source) {
  final normalized = source.replaceFirstMapped(
    RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})(?=[ T])'),
    (m) => '${m[1]}-${m[2]!.padLeft(2, '0')}-${m[3]!.padLeft(2, '0')}',
  );
  final v = DateTime.tryParse(normalized);
  if (v == null) return source;
  return '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')} ${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';
}

class LecturesPage extends ConsumerStatefulWidget {
  const LecturesPage({super.key});
  @override
  ConsumerState<LecturesPage> createState() => _LecturesPageState();
}

class _LecturesPageState extends ConsumerState<LecturesPage> {
  final _extra = <LectureEntry>[];
  int? _next;
  bool _hasLoadedMore = false, _loadingMore = false;
  String? _error;
  Future<void> _connect() async {
    final identity = ref.read(browserIdentityProvider);
    await AppPageRoutes.push<bool>(
      context,
      CampusWebPage(
        title: '连接讲座账号',
        url: LectureClient.authorizationEntry,
        completeAuthorization: (uri, manager) async {
          if (uri.host != LectureClient.origin.host ||
              !uri.path.startsWith('/mob')) {
            return null;
          }
          if (ref.read(browserIdentityProvider) != identity) {
            throw StateError('账号已切换');
          }
          final cookie = await manager.getCookie(
            url: WebUri(LectureClient.origin.toString()),
            name: 'deviceKey',
          );
          if (cookie == null) throw const LectureLoginRequired();
          await ref
              .read(lectureProvider.notifier)
              .acceptAuthorization(cookie.value);
          return true;
        },
      ),
    );
  }

  Future<void> _more(LecturePage page) async {
    if (_loadingMore) return;
    final identity = ref.read(browserIdentityProvider);
    final next = _hasLoadedMore ? _next : page.nextPage;
    if (next == null) return;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(lectureProvider.notifier)
          .run((c) => c.attended(page: next));
      if (!mounted || ref.read(browserIdentityProvider) != identity) return;
      final keys = {
        ...page.rows.map((r) => r.key),
        ..._extra.map((r) => r.key),
      };
      _extra.addAll(result.rows.where((r) => keys.add(r.key)));
      _next = result.nextPage;
      _hasLoadedMore = true;
    } catch (e) {
      if (mounted && ref.read(browserIdentityProvider) == identity) {
        _error = e is FormatException ? e.message : '未能加载更多讲座';
      }
    } finally {
      if (mounted && ref.read(browserIdentityProvider) == identity) {
        setState(() => _loadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(browserIdentityProvider, (_, _) {
      setState(() {
        _extra.clear();
        _hasLoadedMore = false;
        _loadingMore = false;
        _error = null;
      });
    });
    final requirement = ref.watch(lectureRequirementProvider);
    final plan = requirement.isReloading ? null : requirement.valueOrNull;
    final state = ref.watch(lectureProvider),
        notifier = ref.read(lectureProvider.notifier);
    return SubpageScaffold(
      title: '学术讲座',
      actions: [
        AppRefreshButton(
          busy: notifier.updating,
          onRefresh: () async {
            await Future.wait([
              notifier.refresh(),
              ref.read(lectureRequirementProvider.notifier).refresh(),
            ]);
            if (mounted) {
              setState(() {
                _extra.clear();
                _hasLoadedMore = false;
              });
            }
          },
        ),
      ],
      body: AppPageViewport(
        maxWidth: AppLayout.readingMaxWidth,
        builder: (context, insets) => ListView(
          padding: insets + EdgeInsets.all(AppSpace.pageXOf(context)),
          children: [
            state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e is FormatException ? e.message : '暂时无法读取讲座记录'),
                    const SizedBox(height: AppSpace.md),
                    if (e is LectureLoginRequired) ...[
                      const Text('学院平台使用企业微信授权，连接后在此查看讲座记录。'),
                      const SizedBox(height: AppSpace.md),
                      AppButton(label: '连接讲座', onPressed: _connect),
                    ] else
                      AppButton(label: '重试', onPressed: notifier.refresh),
                  ],
                ),
              ),
              data: (page) {
                final rows = [...page.rows, ..._extra];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (page.successCount != null) ...[
                      AppMetric(
                        label: '已参加',
                        value: plan?.minimum == null
                            ? '${page.successCount}场'
                            : '${page.successCount}/${plan!.minimum}',
                      ),
                      const SizedBox(height: AppSpace.lg),
                    ],
                    if (plan != null) ...[
                      SettingsSection(
                        padTop: false,
                        hasLeading: false,
                        children: [
                          SettingsRow(
                            title: '培养方案要求',
                            subtitle: plan.minimum == null
                                ? plan.title
                                : '至少 ${plan.minimum}场',
                            trailing: const Icon(AppIcons.right, size: 14),
                            onTap: () => showDialog<void>(
                              context: context,
                              builder: (ctx) => AppNoticeDialog(
                                title: plan.title,
                                message: plan.description,
                                onClose: () => Navigator.of(ctx).pop(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.lg),
                    ],
                    if (rows.isEmpty)
                      const EmptyHint(icon: AppIcons.calendar, title: '暂无讲座记录')
                    else
                      SettingsSection(
                        padTop: false,
                        hasLeading: false,
                        children: [
                          for (final row in rows)
                            SettingsRow(
                              title: row.title,
                              truncateTitle: true,
                              subtitle: [
                                _when(row.start),
                                row.address,
                                if (row.state.isNotEmpty && row.state != '成功')
                                  row.state,
                              ].where((s) => s.isNotEmpty).join('\n'),
                            ),
                        ],
                      ),
                    if ((_hasLoadedMore ? _next : page.nextPage) != null)
                      AppButton(
                        kind: AppButtonKind.secondary,
                        label: _loadingMore ? '加载中' : '加载更多',
                        onPressed: _loadingMore ? null : () => _more(page),
                      ),
                  ],
                );
              },
            ),
            if (_error ?? notifier.warning case final String message)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.md),
                child: Text(message),
              ),
          ],
        ),
      ),
    );
  }
}
