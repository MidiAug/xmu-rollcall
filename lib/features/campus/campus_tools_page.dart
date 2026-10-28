import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/app/shell_tab_scope.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/grades/gpa_page.dart';

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

final campusTools = <CampusTool>[
  CampusTool(
    id: 'gpa',
    title: 'GPA 计算器',
    description: '查看成绩，计算学分加权绩点',
    icon: AppIcons.calculator,
    page: (_) => const GpaPage(),
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
      subtitle: '成绩查询与绩点计算',
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
                for (final tool in campusTools)
                  SizedBox(
                    width: touch ? constraints.maxWidth : 280,
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
                        onTap: () =>
                            AppPageRoutes.push(context, tool.page(context)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: p.accentSurface,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      tool.icon,
                                      color: p.primary,
                                      size: 26,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    AppIcons.right,
                                    color: p.primary,
                                    size: 20,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Text(
                                tool.title,
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w600,
                                  color: p.ink,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                tool.description,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: p.muted,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
