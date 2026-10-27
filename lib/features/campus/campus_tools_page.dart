import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/app/shell_tab_scope.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/location/saved_locations_page.dart';
import 'package:xmu_rollcall/features/settings/settings_assist_page.dart';
import 'package:xmu_rollcall/features/settings/settings_data_page.dart';

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
    id: 'locations',
    title: '常用地点',
    description: '管理课堂与签到位置',
    icon: AppIcons.location,
    page: (_) => const SavedLocationsPage(),
  ),
  CampusTool(
    id: 'assist',
    title: '协助同学',
    description: '管理已授权的协助身份',
    icon: Icons.handshake_outlined,
    page: (_) => const SettingsAssistPage(),
  ),
  CampusTool(
    id: 'data',
    title: '数据与诊断',
    description: '查看日志与管理本地缓存',
    icon: AppIcons.data,
    page: (_) => const SettingsDataPage(),
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
    return PageScaffold(
      title: '校园工具',
      subtitle: '常用入口，集中在这里',
      child: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(28, 4, 28, 28),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                for (final tool in campusTools)
                  SizedBox(
                    width: 260,
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        onTap: () =>
                            AppPageRoutes.push(context, tool.page(context)),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(tool.icon, color: p.primary, size: 26),
                              const SizedBox(height: 24),
                              Text(
                                tool.title,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: p.ink,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                tool.description,
                                style: TextStyle(color: p.muted, height: 1.5),
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
