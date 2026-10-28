import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/campus/campus_summary_providers.dart';
import 'package:xmu_rollcall/features/grades/gpa_page.dart';
import 'package:xmu_rollcall/features/history/history_page.dart';
import 'package:xmu_rollcall/features/homework/homework_detail_page.dart';
import 'package:xmu_rollcall/features/homework/homework_hub_page.dart';
import 'package:xmu_rollcall/features/location/saved_locations_page.dart';
import 'package:xmu_rollcall/features/monitor/monitor_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/features/settings/courses_page.dart';
import 'package:xmu_rollcall/features/settings/notification_settings_page.dart';
import 'package:xmu_rollcall/features/settings/settings_assist_page.dart';

class _SearchEntry {
  const _SearchEntry(
    this.title,
    this.description,
    this.keywords,
    this.icon, {
    this.page,
    this.url,
    this.help = '',
  });
  final String title, description, keywords, help;
  final IconData icon;
  final WidgetBuilder? page;
  final String? url;
}

bool campusSearchMatches(String query, String content) {
  String clean(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[\s，。？！?、（）()]'), '');
  final q = clean(
    query,
  ).replaceAll(RegExp('怎么算|怎么用|怎么|如何|在哪|打开|查询|使用|我要|帮我|设置|说明|帮助'), '');
  return q.isEmpty || clean(content).contains(q);
}

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

  Future<void> _open(_SearchEntry entry, {bool help = false}) async {
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
    final features = [
      _SearchEntry(
        'GPA 计算器',
        '成绩、学年与学期绩点',
        '绩点怎么算 成绩学分 GPA计算器',
        AppIcons.calculator,
        page: (_) => const GpaPage(),
        help: '打开后读取当前账号的成绩。选择总绩点、学年或学期范围，并按需勾选课程。没有已发布成绩时会显示空态，计算规则可在页面底部查看。',
      ),
      _SearchEntry(
        '本学期课表',
        '查看课程时间与上课地点',
        '课程 课表 学期 开学时间',
        AppIcons.calendar,
        page: (_) => CoursesPage(assistUserId: scope),
        help: '在课表中切换本周和学期视图。点击课程查看时间、教师与教室；已定位的教室可继续查看地图。',
      ),
      _SearchEntry(
        '地点管理',
        '绑定、校正课程的上课位置',
        '地点 定位不准 地图 教室 校区',
        AppIcons.location,
        page: (_) => const SavedLocationsPage(),
        help: '选择待定位或待校正的课表地点，在地图上标记位置并保存。地点名称沿用课表，绑定按当前账号保存。',
      ),
      _SearchEntry(
        '自动检测设置',
        '设置检测范围与签到规则',
        '自动签到 签到 自动检测 位置签到',
        AppIcons.detect,
        page: (_) => const MonitorSettingsPage(),
        help: '先检查检测时段和当前账号的规则，再返回签到页启动检测。检测运行时可从顶区停止。自动签到规则需要另行配置，普通签到仍有确认步骤。',
      ),
      _SearchEntry(
        '作业',
        '查看进行中作业与作业详情',
        '作业 附件 截止时间',
        AppIcons.homework,
        page: (_) => const HomeworkHubPage(),
        help: '进入作业页切换进行中或已截止。点击具体作业查看说明、附件与提交状态。当前客户端不提供作业提交。',
      ),
      _SearchEntry(
        '签到记录',
        '查看当前账号的签到历史',
        '签到历史 签到记录 未签到',
        AppIcons.history,
        page: (_) => const HistoryPage(),
        help: '记录页提供课程、日期和签到状态筛选。下课不代表签到成功，请以平台记录中的状态为准。',
      ),
      _SearchEntry(
        '后台提醒',
        '检查锁屏提醒与通知权限',
        '通知 收不到提醒 后台提醒',
        AppIcons.notification,
        page: (_) => const NotificationSettingsPage(),
        help: '按页面提示检查通知与后台运行相关设置。不同安卓系统的入口不同，实际授权状态以系统显示为准。',
      ),
      _SearchEntry(
        '协助同学',
        '管理导入的协助身份',
        '切换账号 协助同学 身份 导入',
        AppIcons.assist,
        page: (_) => const SettingsAssistPage(),
        help: '在此导入或管理协助身份，再从签到页姓名入口切换。课程、作业和地点始终按当前账号读取。',
      ),
    ];
    final guides = [
      const _SearchEntry(
        '校园网与密码',
        '厦大信息与网络中心 · 官方指南',
        '校园网 WiFi XMUNET VPN 密码 统一认证',
        AppIcons.info,
        url: 'https://inc.xmu.edu.cn/info/1431/9562.htm',
      ),
      const _SearchEntry(
        '校园卡服务',
        '厦大信息与网络中心 · 官方入口',
        '校园卡 充值 补卡 数字校园卡',
        AppIcons.info,
        url: 'https://inc.xmu.edu.cn/fwzn2/xyk.htm',
      ),
      const _SearchEntry(
        '信息学院新生手册',
        '本科 / 研究生分册 · 适用范围见原文',
        '新生 学校 办事 研究生 本科 生活 交通',
        AppIcons.document,
        url: 'https://informatics.xmu.edu.cn/welcome/index.html',
      ),
      const _SearchEntry(
        '学校信息门户',
        '前往厦大官方服务入口办理',
        '办事 证明 门户 服务大厅',
        AppIcons.tools,
        url: 'https://i.xmu.edu.cn/',
      ),
    ];
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
    Widget entry(_SearchEntry e) => ListTile(
      leading: Icon(e.icon, color: p.primary, size: 22),
      title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(e.description, maxLines: 2),
      trailing: Icon(e.url != null ? AppIcons.right : AppIcons.right, size: 16),
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
                        onTap: () {
                          if (ref.read(authControllerProvider).profile?.id !=
                                  owner ||
                              ref.read(selectedRollcallAccountProvider) !=
                                  scope) {
                            return;
                          }
                          FocusScope.of(context).unfocus();
                          AppPageRoutes.push(
                            context,
                            HomeworkDetailPage(seed: item),
                          );
                        },
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
                        onTap: () {
                          if (ref.read(authControllerProvider).profile?.id !=
                                  owner ||
                              ref.read(selectedRollcallAccountProvider) !=
                                  scope) {
                            return;
                          }
                          FocusScope.of(context).unfocus();
                          AppPageRoutes.push(
                            context,
                            CoursesPage(assistUserId: scope),
                          );
                        },
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
  final _SearchEntry entry;
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
