import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'campus_stories.dart';
import 'campus_story_photos.dart';
import 'teaching_catalog.dart';

/// A readable building profile. Group history stays secondary to this building.
class CampusStoryDialog extends StatelessWidget {
  const CampusStoryDialog({super.key, this.building, this.group, this.region});

  final TeachingBuilding? building;
  final TeachingGroup? group;
  final TeachingRegion? region;

  @override
  Widget build(BuildContext context) {
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
    final title = b?.name ?? g!.name;
    final photo = campusStoryPhotoFor(building: b, group: g);
    final location = {
      '${b?.campus ?? g!.campus}校区',
      if (b != null && g != null && !g.id.startsWith('independent-')) g.name,
      if (region != null) region!.aliases.firstOrNull ?? region!.code,
    }.join('　');
    final sources = {
      if (own != null) ...own.sourceUrls,
      if (area != null) ...area.sourceUrls,
      if (photo != null) photo.sourceUrl,
    };
    final p = AppPalette.of(context);

    return AppDialogFrame(
      key: const ValueKey('atlas-story-dialog'),
      maxWidth: 720,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .88,
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              key: const ValueKey('atlas-story-scroll'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StoryHeader(
                    title: title,
                    subtitle: own?.subtitle,
                    location: location,
                    photo: photo,
                  ),
                  Container(
                    color: p.surface,
                    padding: const EdgeInsets.fromLTRB(28, 10, 28, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (own != null) ...[
                          Text(
                            own.summary,
                            key: const ValueKey('atlas-story-lead'),
                            style: AppTypography.body.copyWith(
                              color: p.ink,
                              fontSize: 16,
                              height: 1.8,
                            ),
                          ),
                          if (own.sections.isEmpty &&
                              own.text.length > own.summary.length)
                            _StorySection(
                              title: '沿革与命名',
                              text: own.text.substring(own.summary.length),
                            )
                          else
                            for (final detail in own.sections)
                              _StorySection(
                                title: detail.title,
                                text: detail.text,
                              ),
                        ],
                        if (members.isNotEmpty) ...[
                          const _StorySectionTitle('楼群成员'),
                          const SizedBox(height: 8),
                          for (final member in members)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              child: Text(
                                member.name,
                                style: AppTypography.body.copyWith(
                                  color: p.ink,
                                ),
                              ),
                            ),
                        ],
                        if (b != null && b.regions.isNotEmpty)
                          _StorySection(
                            title: '空间分区',
                            text: b.regions
                                .map(
                                  (r) => RegExp(r'[区楼栋座]$').hasMatch(r.code)
                                      ? r.code
                                      : '${r.code}区',
                                )
                                .join('　'),
                          ),
                        if (area != null && g != null)
                          _StoryDisclosure(
                            title: '了解${g.name}',
                            children: [
                              Text(
                                area.text,
                                style: AppTypography.body.copyWith(
                                  color: p.ink,
                                  height: 1.85,
                                ),
                              ),
                              for (final detail in area.sections)
                                _StorySection(
                                  title: detail.title,
                                  text: detail.text,
                                ),
                            ],
                          ),
                        if (sources.isNotEmpty)
                          _StoryDisclosure(
                            title: '参考资料',
                            children: [
                              for (final entry in sources.indexed)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        child: Text(
                                          '${entry.$1 + 1}',
                                          style: AppTypography.caption.copyWith(
                                            color: p.muted,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: SelectableText(
                                          campusStorySources[entry.$2] ??
                                              (photo == null
                                                  ? '厦门大学公开资料'
                                                  : '${photo.credit}《${photo.caption}》'),
                                          style: AppTypography.caption.copyWith(
                                            color: p.muted,
                                            height: 1.7,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: p.surface.withValues(alpha: .94),
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
                child: AppSheetCloseButton(tooltip: '关闭介绍'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryHeader extends StatefulWidget {
  const _StoryHeader({
    required this.title,
    required this.location,
    this.subtitle,
    this.photo,
  });
  final String title, location;
  final String? subtitle;
  final CampusStoryPhoto? photo;
  @override
  State<_StoryHeader> createState() => _StoryHeaderState();
}

class _StoryHeaderState extends State<_StoryHeader> {
  bool _failed = false;

  @override
  void didUpdateWidget(_StoryHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.photo?.url != oldWidget.photo?.url) _failed = false;
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final photo = _failed ? null : widget.photo;
    final heading = Padding(
      padding: EdgeInsets.fromLTRB(28, photo == null ? 40 : 0, 58, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            key: const ValueKey('atlas-story-title'),
            style: AppTypography.pageTitle.copyWith(color: p.ink),
          ),
          if (widget.subtitle?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              widget.subtitle!,
              style: AppTypography.body.copyWith(color: p.muted),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            widget.location,
            style: AppTypography.caption.copyWith(color: p.muted),
          ),
        ],
      ),
    );
    if (photo == null) return heading;
    final image = ResizeImage(
      NetworkImage(photo.url),
      width: 1440,
      allowUpscaling: false,
    );
    final compact = MediaQuery.sizeOf(context).width < 600;
    final height = compact ? 270.0 : 300.0;
    Widget picture({bool reportError = false}) => Image(
      image: image,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) {
        if (reportError && !_failed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_failed) setState(() => _failed = true);
          });
        }
        return ColoredBox(color: p.surfaceHigh);
      },
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : ColoredBox(color: p.surfaceHigh),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Semantics(
                  image: true,
                  label: photo.caption,
                  child: picture(reportError: true),
                ),
                if (!MediaQuery.highContrastOf(context))
                  ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (bounds) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black,
                      ],
                      stops: [0, .45, 1],
                    ).createShader(bounds),
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                      child: picture(),
                    ),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        p.surface.withValues(alpha: 0),
                        p.surface.withValues(alpha: .3),
                        p.surface,
                        p.surface,
                      ],
                      stops: const [0, .4, .78, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 2,
                  child: ColoredBox(color: p.surface),
                ),
                Align(alignment: Alignment.bottomLeft, child: heading),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StorySectionTitle extends StatelessWidget {
  const _StorySectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Row(
      children: [
        Container(
          width: 3,
          height: 15,
          decoration: BoxDecoration(
            color: AppPalette.of(context).primary.withValues(alpha: .55),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: AppTypography.sectionTitle.copyWith(
              color: AppPalette.of(context).ink,
              fontSize: 14,
            ),
          ),
        ),
      ],
    ),
  );
}

class _StorySection extends StatelessWidget {
  const _StorySection({required this.title, required this.text});
  final String title, text;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _StorySectionTitle(title),
      const SizedBox(height: 9),
      Text(
        text,
        style: AppTypography.body.copyWith(
          color: AppPalette.of(context).ink.withValues(alpha: .85),
          height: 1.85,
        ),
      ),
    ],
  );
}

class _StoryDisclosure extends StatefulWidget {
  const _StoryDisclosure({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  State<_StoryDisclosure> createState() => _StoryDisclosureState();
}

class _StoryDisclosureState extends State<_StoryDisclosure> {
  var _expanded = false;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(color: p.border, height: 1),
          Semantics(
            expanded: _expanded,
            button: true,
            child: AppHoverSurface(
              outlined: false,
              backgroundColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 12),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppTypography.control.copyWith(color: p.muted),
                    ),
                  ),
                  RotatedBox(
                    quarterTurns: _expanded ? 2 : 0,
                    child: Icon(AppIcons.down, size: 14, color: p.muted),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 4),
            ...widget.children,
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
