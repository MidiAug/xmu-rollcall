import 'campus_search_index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/campus/campus_summary_providers.dart';
import 'package:xmu_rollcall/features/homework/homework_detail_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/features/settings/courses_page.dart';

/// A real local index and official guide directory. No external AI requests.
class CampusSearchPage extends ConsumerStatefulWidget {
  const CampusSearchPage({super.key});
  @override
  ConsumerState<CampusSearchPage> createState() => _CampusSearchPageState();
}

class _CampusSearchPageState extends ConsumerState<CampusSearchPage> {
  final _query = TextEditingController();
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _open(CampusSearchEntry entry, {bool help = false}) async {
    FocusScope.of(context).unfocus();
    if (entry.url != null) {
      try {
        if (!await launchUrl(
              Uri.parse(entry.url!),
              mode: LaunchMode.externalApplication,
            ) &&
            mounted) {
          AppToast.show(context, '无法打开，请检查浏览器');
        }
      } catch (_) {
        if (mounted) AppToast.show(context, '无法打开官方页面');
      }
    } else if (entry.page != null) {
      AppPageRoutes.push(
        context,
        help ? _FeatureHelpPage(entry: entry) : entry.page!(context),
      );
    }
  }

  void _openPersonal(Widget page, int? owner, int? scope) {
    if (ref.read(authControllerProvider).profile?.id != owner ||
        ref.read(selectedRollcallAccountProvider) != scope) {
      return;
    }
    FocusScope.of(context).unfocus();
    AppPageRoutes.push(context, page);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final scope = ref.watch(selectedRollcallAccountProvider);
    final owner = ref.watch(authControllerProvider).profile?.id;
    ref.listen(selectedRollcallAccountProvider, (before, after) {
      if (before != after) {
        _query.clear();
        setState(() {});
      }
    });
    ref.listen(authControllerProvider.select((a) => a.profile?.id), (
      before,
      after,
    ) {
      if (before != after) {
        _query.clear();
        setState(() {});
      }
    });
    final cached = ref.watch(campusCachedDataProvider);
    final data = cached.isLoading ? null : cached.valueOrNull;
    final q = _query.text.trim();
    final wantsHelp = q.contains(RegExp('怎么|如何|说明|帮助'));
    final features = campusSearchFeatures(scope);
    const guides = campusSearchGuides;
    final matchedFeatures = features
        .where(
          (e) => campusSearchMatches(
            q,
            '${e.title} ${e.description} ${e.keywords}',
          ),
        )
        .toList();
    final matchedGuides = guides
        .where((e) => campusSearchMatches(q, '${e.title} ${e.keywords}'))
        .toList();
    final homework = q.isEmpty
        ? []
        : (data?.homework ?? [])
              .where(
                (e) => campusSearchMatches(q, '${e.title} ${e.courseName}'),
              )
              .toList();
    final courses = q.isEmpty
        ? <String>[]
        : {
            for (final row in data?.schedule?.rows ?? <Map<String, dynamic>>[])
              if (campusSearchMatches(
                q,
                '${row['KCMC'] ?? ''} ${row['JASMC'] ?? ''}',
              ))
                '${row['KCMC'] ?? ''}',
          }.where((s) => s.trim().isNotEmpty).toList();
    Widget section(String label, List<Widget> rows) => rows.isEmpty
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: p.muted,
                  ),
                ),
              ),
              Material(
                color: p.surface,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: Column(children: rows),
              ),
            ],
          );
    Widget entry(CampusSearchEntry e) => ListTile(
      leading: Icon(e.icon, color: p.primary, size: 22),
      title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(e.description, maxLines: 2),
      trailing: const Icon(AppIcons.right, size: 16),
      onTap: () => _open(e, help: wantsHelp && e.help.isNotEmpty),
    );
    return SubpageScaffold(
      title: '搜索',
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            TextField(
              key: const ValueKey('campus-search-field'),
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '搜索功能、课程与校园办事',
                prefixIcon: const Icon(AppIcons.search),
                suffixIcon: q.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空',
                        onPressed: () {
                          _query.clear();
                          setState(() {});
                        },
                        icon: const Icon(AppIcons.close),
                      ),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  section(
                    q.isEmpty
                        ? '常用功能'
                        : wantsHelp
                        ? '使用帮助'
                        : '功能',
                    (q.isEmpty ? matchedFeatures.take(4) : matchedFeatures)
                        .map(entry)
                        .toList(),
                  ),
                  section('当前账号的作业', [
                    for (final item in homework.take(20))
                      ListTile(
                        leading: Icon(AppIcons.homework, color: p.primary),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          item.courseName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _openPersonal(
                          HomeworkDetailPage(seed: item),
                          owner,
                          scope,
                        ),
                      ),
                  ]),
                  section('当前账号的课程', [
                    for (final name in courses.take(20))
                      ListTile(
                        leading: Icon(AppIcons.calendar, color: p.primary),
                        title: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: const Text('在课表中查看'),
                        onTap: () => _openPersonal(
                          CoursesPage(assistUserId: scope),
                          owner,
                          scope,
                        ),
                      ),
                  ]),
                  section('校园官方指南', matchedGuides.map(entry).toList()),
                  if (q.isNotEmpty &&
                      matchedFeatures.isEmpty &&
                      matchedGuides.isEmpty &&
                      homework.isEmpty &&
                      courses.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('没有找到结果，试试功能名称或关键词'),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      '个人内容按当前账号显示；校园办事以官方页面的适用范围和最新说明为准。',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: p.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureHelpPage extends StatelessWidget {
  const _FeatureHelpPage({required this.entry});
  final CampusSearchEntry entry;
  @override
  Widget build(BuildContext context) => SubpageScaffold(
    title: '${entry.title}使用说明',
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(entry.help, style: const TextStyle(fontSize: 15, height: 1.8)),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => AppPageRoutes.push(context, entry.page!(context)),
          child: const Text('打开功能'),
        ),
      ],
    ),
  );
}
