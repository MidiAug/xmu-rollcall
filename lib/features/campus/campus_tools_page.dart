import 'package:flutter/material.dart';
import 'package:xmu_rollcall/features/browser/campus_website.dart';
import 'package:xmu_rollcall/app/app_service_tile.dart';
import 'campus_calendar_page.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/app/shell_tab_scope.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/grades/gpa_page.dart';
import 'package:xmu_rollcall/features/exams/exam_page.dart';
import 'package:xmu_rollcall/features/location/campus_atlas_page.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_grading_page.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_widgets.dart';

/// Built-in tool descriptors are the extension seam. No phantom future services.
class CampusTool {
  const CampusTool({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.page,
  });
  final String id, title, description;
  final IconData icon;
  final WidgetBuilder page;
}

// A getter lets hot reload pick up newly added built-in tools as well.
List<CampusTool> get campusTools => <CampusTool>[
  CampusTool(
    id: 'campus-map',
    title: '校园地图',
    description: '三校区楼宇与地点',
    icon: AppIcons.serviceMap,
    page: (_) => const CampusAtlasPage(),
  ),
  CampusTool(
    id: 'exams',
    title: '考试安排',
    description: '本科考试时间与地点',
    icon: AppIcons.serviceExams,
    page: (_) => const ExamPage(),
  ),
  CampusTool(
    id: 'gpa',
    title: 'GPA 计算器',
    description: '成绩查询与绩点计算',
    icon: AppIcons.serviceGpa,
    page: (_) => const GpaPage(),
  ),
  CampusTool(
    id: 'calendar',
    title: '学年校历',
    description: '学期安排与教学周',
    icon: AppIcons.serviceCalendar,
    page: (_) => const CampusCalendarPage(),
  ),
  CampusTool(
    id: 'ta-grading',
    title: '修改作业',
    description: '助教查看作业进度、打包下载与 CSV 批量评分',
    icon: AppIcons.serviceGrading,
    page: (_) => const TaGradingPage(),
  ),
];

class CampusToolsPage extends StatefulWidget {
  const CampusToolsPage({super.key});
  @override
  State<CampusToolsPage> createState() => _CampusToolsPageState();
}

class _CampusToolsPageState extends State<CampusToolsPage>
    with ShellTabAware<CampusToolsPage> {
  final _scroll = ScrollController();
  @override
  AppDestination get shellTab => AppDestination.campusTools;
  @override
  ScrollController get shellScrollController => _scroll;
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final tools = campusTools;
    return PageScaffold(
      title: '工具',
      child: ColoredBox(
        color: p.pageBackground(context),
        child: AppContentColumn(
          maxWidth: 1040,
          child: LayoutBuilder(
            builder: (context, viewport) => SingleChildScrollView(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(
                AppSpace.pageXOf(context),
                20,
                AppSpace.pageXOf(context),
                32,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (viewport.maxHeight - 52).clamp(
                    0.0,
                    double.infinity,
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, bounds) {
                    final compact = bounds.maxWidth < 580;
                    final gap = compact ? 12.0 : 16.0;
                    final columns = compact ? 1 : 2;
                    final tileWidth =
                        (bounds.maxWidth - gap * (columns - 1)) / columns;
                    Widget group(String title, Iterable<CampusTool> entries) =>
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Text(
                                title,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: p.muted,
                                    ),
                              ),
                            ),
                            Wrap(
                              spacing: gap,
                              runSpacing: gap,
                              children: [
                                for (final tool in entries)
                                  SizedBox(
                                    width: tileWidth,
                                    child: AppServiceTile(
                                      key: ValueKey('tool-${tool.id}'),
                                      title:
                                          tool.id == 'ta-grading' &&
                                              taIsMobile(context)
                                          ? '助教作业'
                                          : tool.title,
                                      description: tool.id == 'ta-grading'
                                          ? taIsMobile(context)
                                                ? '提交情况与批改进度'
                                                : '作业打包下载与批量评分'
                                          : tool.description,
                                      icon: tool.icon,
                                      compact: compact,
                                      onPressed: () => AppPageRoutes.push(
                                        context,
                                        tool.page(context),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            group(
                              '常用工具',
                              tools.where((t) => t.id != 'ta-grading'),
                            ),
                            const SizedBox(height: 28),
                            group(
                              '研究生',
                              tools.where((t) => t.id == 'ta-grading'),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Divider(color: p.borderStrong, height: 1),
                              const SizedBox(height: 12),
                              SingleChildScrollView(
                                key: const ValueKey('campus-websites-row'),
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    Text(
                                      '常用网站',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: p.muted),
                                    ),
                                    for (final link in const [
                                      ('信息门户', 'https://i.xmu.edu.cn/'),
                                      ('教务', 'https://jw.xmu.edu.cn/'),
                                      ('学工', 'https://xmuxg.xmu.edu.cn/login'),
                                      ('图书馆', 'https://library.xmu.edu.cn/'),
                                      ('邮箱', 'https://mail.stu.xmu.edu.cn/'),
                                    ]) ...[
                                      const SizedBox(width: 24),
                                      AppTextLink(
                                        link.$1,
                                        icon: null,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        textStyle: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(fontSize: 13),
                                        onPressed: () => openCampusWebsite(
                                          context,
                                          title: link.$1,
                                          url: Uri.parse(link.$2),
                                        ),
                                      ),
                                    ],
                                  ],
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
            ),
          ),
        ),
      ),
    );
  }
}
