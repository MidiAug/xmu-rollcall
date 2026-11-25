import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/app_service_tile.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'classroom_providers.dart';
import 'classroom_catalog_page.dart';
import 'classroom_booking_pages.dart';
import 'classroom_feedback_page.dart';
import 'classroom_scan_page.dart';

class ClassroomsPage extends ConsumerWidget {
  const ClassroomsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(classroomProvider),
        notifier = ref.read(classroomProvider.notifier);
    void open(Widget page) => AppPageRoutes.push<void>(context, page);
    final entries =
        <({String title, String description, IconData icon, Widget page})>[
          (
            title: '座位预约',
            description: '选择教室、时段和座位',
            icon: AppIcons.people,
            page: const ClassroomCatalogPage(feature: ClassroomFeature.seats),
          ),
          (
            title: '研讨室预约',
            description: '可预约空间与使用时段',
            icon: AppIcons.calendar,
            page: const ClassroomCatalogPage(
              feature: ClassroomFeature.seminars,
            ),
          ),
          (
            title: '自习教室',
            description: '按楼栋查看自习时段',
            icon: AppIcons.document,
            page: const ClassroomCatalogPage(feature: ClassroomFeature.study),
          ),
          (
            title: '讲座活动',
            description: '时间、地点与主讲人',
            icon: AppIcons.person,
            page: const ClassroomCatalogPage(
              feature: ClassroomFeature.lectures,
            ),
          ),
          (
            title: '教室介绍',
            description: '容量、设施与教室照片',
            icon: AppIcons.building,
            page: const ClassroomCatalogPage(feature: ClassroomFeature.rooms),
          ),
          (
            title: '楼层索引',
            description: '楼层分布与当前使用情况',
            icon: AppIcons.map,
            page: const ClassroomCatalogPage(feature: ClassroomFeature.floors),
          ),
          (
            title: '失物招领',
            description: '查找物品与发现地点',
            icon: AppIcons.search,
            page: const ClassroomCatalogPage(feature: ClassroomFeature.lost),
          ),
          (
            title: '扫一扫',
            description: '识别教室码并查看教室',
            icon: AppIcons.qr,
            page: const ClassroomScanPage(),
          ),
          (
            title: '意见与建议',
            description: '提交反馈、查看处理记录',
            icon: AppIcons.document,
            page: const ClassroomFeedbackPage(),
          ),
        ];
    return SubpageScaffold(
      title: '厦大教室',
      actions: [
        AppRefreshButton(busy: notifier.updating, onRefresh: notifier.refresh),
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
                    Text(e is FormatException ? e.message : '暂时无法连接厦大教室'),
                    const SizedBox(height: AppSpace.md),
                    AppButton(label: '重试', onPressed: notifier.refresh),
                  ],
                ),
              ),
              data: (home) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingsSection(
                    padTop: false,
                    hasLeading: false,
                    children: [
                      SettingsRow(
                        title: '我的预约',
                        subtitle: home.agendas.isEmpty ? '预约记录与使用状态' : null,
                        trailing: const Icon(AppIcons.right, size: 14),
                        onTap: () => open(const ClassroomBookingsPage()),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.lg),
                  LayoutBuilder(
                    builder: (context, bounds) {
                      final columns =
                          bounds.maxWidth < 340 &&
                              MediaQuery.textScalerOf(context).scale(1) > 1.2
                          ? 1
                          : bounds.maxWidth >= 600
                          ? 3
                          : 2;
                      final gap = AppSpace.md;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final entry in entries)
                            SizedBox(
                              width:
                                  (bounds.maxWidth - gap * (columns - 1)) /
                                  columns,
                              child: AppServiceTile(
                                title: entry.title,
                                compact: columns == 1,
                                description: entry.description,
                                icon: entry.icon,
                                onPressed: () => open(entry.page),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  if (home.agendas.isNotEmpty)
                    SettingsSection(
                      header: '我的日程',
                      hasLeading: false,
                      children: [
                        for (final item in home.agendas)
                          SettingsRow(
                            title: item.title,
                            subtitle: '${item.start}\n${item.end}',
                          ),
                      ],
                    ),
                ],
              ),
            ),
            if (notifier.warning != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.md),
                child: Text(notifier.warning!),
              ),
          ],
        ),
      ),
    );
  }
}
