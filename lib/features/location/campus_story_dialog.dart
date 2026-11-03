import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'campus_stories.dart';
import 'teaching_catalog.dart';

/// Offline reading surface, with individual evidence separate from area context.
class CampusStoryDialog extends StatelessWidget {
  const CampusStoryDialog({super.key, this.building, this.group, this.region});

  final TeachingBuilding? building;
  final TeachingGroup? group;
  final TeachingRegion? region;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final b = building;
    final g = b == null
        ? group
        : teachingGroups.where((g) => g.id == b.groupId).firstOrNull;
    final own = b == null
        ? campusGroupStories[g?.id]
        : campusBuildingStories[b.id];
    final area = b == null ? null : campusGroupStories[g?.id];
    final members = b == null
        ? teachingBuildings.where((b) => b.groupId == g?.id).toList()
        : <TeachingBuilding>[];
    final sources = {
      if (own != null) ...own.sourceUrls,
      if (area != null) ...area.sourceUrls,
    };
    final title = b?.name ?? g!.name;

    Widget section(String title, String text) => Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: p.ink,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(color: p.muted, fontSize: 13, height: 1.7),
          ),
        ],
      ),
    );

    return Dialog(
      key: const ValueKey('atlas-story-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: p.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.dialog),
        side: BorderSide(color: p.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '建筑档案',
                      style: TextStyle(color: p.muted, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭介绍',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: p.border),
            Flexible(
              child: SingleChildScrollView(
                key: const ValueKey('atlas-story-scroll'),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: p.ink,
                        fontSize: 24,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final label in [
                          '${b?.campus ?? g!.campus}校区',
                          b == null ? '楼群与片区' : '楼宇',
                          if (b != null &&
                              g != null &&
                              !g.id.startsWith('independent-'))
                            g.name,
                        ])
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: p.primary.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(color: p.primary, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                    if (region != null)
                      section(
                        '当前分区',
                        '${region!.aliases.firstOrNull ?? region!.code}。以下介绍属于${b!.name}，不代表该分区独立的建筑沿革。',
                      ),
                    if (own != null) ...[
                      section('概览', own.summary),
                      if (own.sections.isEmpty &&
                          own.text.length > own.summary.length)
                        section('沿革与命名', own.text.substring(own.summary.length))
                      else
                        for (final detail in own.sections)
                          section(detail.title, detail.text),
                    ] else
                      section(
                        '资料状态',
                        b == null
                            ? '该片区尚无已核实的专题介绍，可先查看下方目录。'
                            : '尚未查得这座楼独立的营建与命名资料。已确认的目录信息和片区背景列于下方。',
                      ),
                    if (area != null) ...[
                      section('所在片区背景', area.text),
                      for (final detail in area.sections)
                        section(detail.title, detail.text),
                    ],
                    if (members.isNotEmpty) ...[
                      section('楼群成员', '按当前地图目录列出 ${members.length} 处楼宇。'),
                      const SizedBox(height: 8),
                      for (final member in members)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: AppTruncatedText(
                            member.name,
                            style: TextStyle(color: p.ink, fontSize: 13),
                          ),
                        ),
                    ],
                    if (b != null && b.regions.isNotEmpty)
                      section(
                        '分区目录',
                        b.regions
                            .map(
                              (r) => RegExp(r'[区楼栋座]$').hasMatch(r.code)
                                  ? r.code
                                  : '${r.code}区',
                            )
                            .join('　'),
                      ),
                    if (sources.isNotEmpty)
                      section(
                        '参考资料',
                        [
                          for (final url in sources) campusStorySources[url]!,
                        ].join('\n\n'),
                      ),
                    section(
                      '资料说明',
                      sources.isEmpty
                          ? '目录随应用保存，建筑史料待补充。'
                          : '根据公开资料整理，核对日期为2026年11月3日。历史用途按报道当时表述，不作为当前开放时间、房间用途或进入权限的依据。',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
