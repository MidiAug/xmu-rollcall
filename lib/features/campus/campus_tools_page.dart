import 'package:flutter/material.dart';
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
    description: '浏览三个校区的楼群、楼宇与分区',
    icon: AppIcons.map,
    page: (_) => const CampusAtlasPage(),
  ),
  CampusTool(
    id: 'exams',
    title: '考试安排',
    description: '本学期未安排、未考试与已考试',
    icon: AppIcons.calendar,
    page: (_) => const ExamPage(),
  ),
  CampusTool(
    id: 'gpa',
    title: 'GPA 计算器',
    description: '查看成绩，计算学分加权绩点',
    icon: AppIcons.calculator,
    page: (_) => const GpaPage(),
  ),
  CampusTool(
    id: 'ta-grading',
    title: '修改作业',
    description: '助教查看作业进度、打包下载与 CSV 批量评分',
    icon: AppIcons.homework,
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
    final touch = AppDensity.isTouch(context);
    return PageScaffold(
      title: '工具',
      subtitle: '校园地图、考试安排、成绩计算与助教工具',
      child: AppContentColumn(
        maxWidth: 900,
        child: SingleChildScrollView(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(
            AppSpace.pageXOf(context),
            4,
            AppSpace.pageXOf(context),
            24,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                for (final tool in campusTools) ...[
                  if (tool.id == 'ta-grading')
                    SizedBox(
                      width: constraints.maxWidth,
                      child: Text(
                        '研究生',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  SizedBox(
                    width: touch || constraints.maxWidth < 640
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 20) / 2,
                    child: Material(
                      key: ValueKey('tool-${tool.id}'),
                      color: p.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: touch ? p.mobileOutline : p.borderStrong,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        hoverColor: p.cardHover,
                        onTap: () =>
                            AppPageRoutes.push(context, tool.page(context)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: p.accentSurface,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Icon(
                                  tool.icon,
                                  color: p.primary,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      tool.id == 'ta-grading' &&
                                              taIsMobile(context)
                                          ? '助教作业'
                                          : tool.title,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: p.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      tool.id == 'ta-grading' &&
                                              taIsMobile(context)
                                          ? '查看课程作业、提交情况与批改进度'
                                          : tool.description,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: p.muted,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(AppIcons.right, color: p.muted, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
