import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'classroom_providers.dart';
import 'classroom_page_session.dart';
import 'classroom_booking_pages.dart';

enum ClassroomFeature {
  seats('座位预约'),
  seminars('研讨室预约'),
  study('自习教室'),
  lectures('讲座活动'),
  rooms('教室介绍'),
  floors('楼层索引'),
  lost('失物招领');

  const ClassroomFeature(this.title);
  final String title;
}

class ClassroomCatalogPage extends ConsumerStatefulWidget {
  const ClassroomCatalogPage({super.key, required this.feature});
  final ClassroomFeature feature;
  @override
  ConsumerState<ClassroomCatalogPage> createState() => _CatalogState();
}

class _CatalogState extends ConsumerState<ClassroomCatalogPage>
    with ClassroomPageSession<ClassroomCatalogPage> {
  ClassroomHome? home;
  ClassroomPlace? campus, building;
  List<ClassroomPlace>? floorOptions;
  List<ClassroomInfo> rooms = [];
  List<SeatRoom> seats = [];
  List<ClassroomSeminar> seminars = [];
  List<ClassroomLecture> lectures = [];
  List<ClassroomLostItem> lost = [];
  bool loaded = false;
  int? nextPage;
  String query = '', date = classroomDate(DateTime.now());
  bool get needsBuilding =>
      widget.feature == ClassroomFeature.study ||
      widget.feature == ClassroomFeature.floors;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load({bool more = false}) => perform(() async {
    home ??= await ref.read(classroomProvider.future);
    if (!current) return;
    campus ??=
        home!.campuses
            .where((v) => home!.user.campusIds.contains(v.id))
            .firstOrNull ??
        home!.campuses.firstOrNull;
    if (widget.feature == ClassroomFeature.floors) {
      floorOptions ??= await ref
          .read(classroomProvider.notifier)
          .run((c) => c.floorBuildings());
      if (!current) return;
      building ??=
          floorOptions!.where((v) => v.campusId == campus?.id).firstOrNull ??
          floorOptions!.firstOrNull;
      if (building != null) {
        campus =
            home!.campuses
                .where((v) => v.id == building!.campusId)
                .firstOrNull ??
            campus;
      }
    } else {
      building ??= home!.buildings
          .where((v) => v.campusId == campus?.id)
          .firstOrNull;
    }
    final page = more ? nextPage! : 1;
    await ref.read(classroomProvider.notifier).run((c) async {
      switch (widget.feature) {
        case ClassroomFeature.seats:
          final v = await c.seatRooms(campus: campus?.id, page: page);
          if (!current) return;
          if (!more) seats.clear();
          seats.addAll(v);
          nextPage = v.length >= 20 ? page + 1 : null;
        case ClassroomFeature.seminars:
          final v = await c.seminars(page, campus: campus?.id);
          if (!current) return;
          if (!more) seminars.clear();
          seminars.addAll(v.items);
          nextPage = v.nextPage;
        case ClassroomFeature.rooms:
          final v = await c.rooms(campus: campus?.id);
          if (current) rooms = v;
          nextPage = null;
        case ClassroomFeature.study:
          if (building != null) {
            final v = await c.selfStudy(building!.id, date);
            if (current) rooms = v;
          }
          nextPage = null;
        case ClassroomFeature.floors:
          if (building != null) {
            final v = await c.floors(building!.id);
            if (current) rooms = v;
          }
          nextPage = null;
        case ClassroomFeature.lectures:
          final v = await c.lectures(page);
          if (!current) return;
          if (!more) lectures.clear();
          lectures.addAll(v.items);
          nextPage = v.nextPage;
        case ClassroomFeature.lost:
          final v = await c.lostItems(page);
          if (!current) return;
          if (!more) lost.clear();
          lost.addAll(v.items);
          nextPage = v.nextPage;
      }
    });
    if (current) loaded = true;
  });
  void open(Widget page) => AppPageRoutes.push<void>(context, page);
  bool match(String v) =>
      query.trim().isEmpty ||
      v.toLowerCase().contains(query.trim().toLowerCase());
  @override
  Widget build(BuildContext context) {
    watchSession();
    final bs =
        (widget.feature == ClassroomFeature.floors
                ? floorOptions
                : home?.buildings)
            ?.where((v) => v.campusId == campus?.id)
            .toList() ??
        <ClassroomPlace>[];
    final children = <Widget>[];
    for (final room in seats.where((v) => match(v.name))) {
      children.add(
        SettingsRow(
          title: room.name,
          subtitle: '当前使用 ${room.occupied}/${room.total}',
          trailing: const Icon(AppIcons.right, size: 14),
          onTap: () => open(ClassroomSeatBookingPage(room: room)),
        ),
      );
    }
    for (final room in seminars.where(
      (v) => match('${v.name} ${v.location}'),
    )) {
      children.add(
        SettingsRow(
          title: room.name,
          subtitle: '${room.location}\n${room.capacity} 人',
          trailing: const Icon(AppIcons.right, size: 14),
          onTap: () => open(ClassroomSeminarBookingPage(room: room)),
        ),
      );
    }
    for (final room in rooms.where(
      (v) => match('${v.name} ${v.building} ${v.category}'),
    )) {
      final study = widget.feature == ClassroomFeature.study;
      final summary = study
          ? '可自习：${room.periods.where((p) => p.status == 1 && !p.expired).map((p) => '${p.index}节').join('、')}'
          : widget.feature == ClassroomFeature.floors
          ? '${room.floor} 层  ${room.category}  ${room.occupied ? '使用中' : '当前空闲'}'
          : '${room.building}  ${room.category}  ${room.capacity} 座';
      children.add(
        SettingsRow(
          title: room.name,
          subtitle: summary,
          trailing: const Icon(AppIcons.right, size: 14),
          onTap: () => open(
            study
                ? ClassroomTextDetailPage(
                    title: room.name,
                    body: room.periods
                        .map(
                          (p) =>
                              '${p.index}节  ${p.start}—${p.end}  ${p.expired
                                  ? '已结束'
                                  : p.status == 1
                                  ? '可自习'
                                  : p.status == 2
                                  ? '已预约'
                                  : '未开放'}',
                        )
                        .join('\n'),
                  )
                : ClassroomDetailPage(id: room.id),
          ),
        ),
      );
    }
    for (final v in lectures.where((v) => match('${v.title} ${v.speaker}'))) {
      children.add(
        SettingsRow(
          title: v.title,
          subtitle: '${v.date} ${v.time}\n${v.position}\n${v.speaker}',
          onTap: () => open(
            ClassroomTextDetailPage(
              title: v.title,
              body:
                  '${v.date} ${v.time}\n${v.position}\n${v.speaker}\n\n${v.content}',
            ),
          ),
        ),
      );
    }
    for (final v in lost.where((v) => match('${v.title} ${v.content}'))) {
      children.add(
        SettingsRow(
          title: v.title,
          subtitle: '${v.position}\n${v.time}',
          onTap: () => open(
            ClassroomTextDetailPage(
              title: v.title,
              body: '${v.position}\n${v.time}\n${v.content}',
            ),
          ),
        ),
      );
    }
    return SubpageScaffold(
      title: widget.feature.title,
      actions: [AppRefreshButton(busy: busy, onRefresh: load)],
      body: AppPageViewport(
        maxWidth: AppLayout.readingMaxWidth,
        builder: (context, insets) => ListView(
          padding: insets + EdgeInsets.all(AppSpace.pageXOf(context)),
          children: [
            if (home != null &&
                widget.feature != ClassroomFeature.lost &&
                widget.feature != ClassroomFeature.lectures)
              Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                children: [
                  if (campus != null)
                    AppShellSelect<ClassroomPlace>(
                      value: campus!,
                      items: home!.campuses,
                      labelOf: (v) => v.name,
                      onChanged: busy
                          ? null
                          : (v) {
                              setState(() {
                                campus = v;
                                building = null;
                              });
                              unawaited(load());
                            },
                    ),
                  if (needsBuilding && building != null && bs.isNotEmpty)
                    AppShellSelect<ClassroomPlace>(
                      value: building!,
                      items: bs,
                      labelOf: (v) => v.name,
                      onChanged: busy
                          ? null
                          : (v) {
                              setState(() => building = v);
                              unawaited(load());
                            },
                    ),
                  if (widget.feature == ClassroomFeature.study)
                    AppShellSelect<String>(
                      value: date,
                      items: [
                        for (var i = 0; i < 7; i++)
                          classroomDate(DateTime.now().add(Duration(days: i))),
                      ],
                      labelOf: (v) => v,
                      onChanged: busy
                          ? null
                          : (v) {
                              setState(() => date = v);
                              unawaited(load());
                            },
                    ),
                ],
              ),
            const SizedBox(height: AppSpace.md),
            TextField(
              decoration: const InputDecoration(
                hintText: '搜索',
                prefixIcon: Icon(AppIcons.search),
              ),
              onChanged: (v) => setState(() => query = v),
            ),
            const SizedBox(height: AppSpace.lg),
            if (error != null) Text(error!),
            if (busy) const Center(child: CircularProgressIndicator()),
            if (loaded && children.isEmpty)
              const EmptyHint(icon: AppIcons.search, title: '暂无相关信息'),
            if (children.isNotEmpty)
              SettingsSection(
                padTop: false,
                hasLeading: false,
                children: children,
              ),
            if (nextPage != null)
              AppButton(
                label: '加载更多',
                busy: busy,
                kind: AppButtonKind.secondary,
                onPressed: () => load(more: true),
              ),
          ],
        ),
      ),
    );
  }
}

class ClassroomTextDetailPage extends StatelessWidget {
  const ClassroomTextDetailPage({
    super.key,
    required this.title,
    required this.body,
  });
  final String title, body;
  @override
  Widget build(BuildContext context) => SubpageScaffold(
    title: title,
    body: AppPageViewport(
      maxWidth: AppLayout.readingMaxWidth,
      builder: (context, insets) => ListView(
        padding: insets + EdgeInsets.all(AppSpace.pageXOf(context)),
        children: [Panel(child: SelectableText(body))],
      ),
    ),
  );
}

class ClassroomDetailPage extends ConsumerStatefulWidget {
  const ClassroomDetailPage({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ClassroomDetailPage> createState() => _DetailState();
}

class _DetailState extends ConsumerState<ClassroomDetailPage>
    with ClassroomPageSession<ClassroomDetailPage> {
  ClassroomInfo? room;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() => perform(() async {
    final v = await ref
        .read(classroomProvider.notifier)
        .run((c) => c.room(widget.id));
    if (current) room = v;
  });
  @override
  Widget build(BuildContext context) {
    watchSession();
    final v = room;
    return SubpageScaffold(
      title: v?.name ?? '教室详情',
      body: AppPageViewport(
        maxWidth: AppLayout.readingMaxWidth,
        builder: (context, insets) => ListView(
          padding: insets + EdgeInsets.all(AppSpace.pageXOf(context)),
          children: [
            if (busy) const Center(child: CircularProgressIndicator()),
            if (error != null) ...[
              Text(error!),
              AppButton(label: '重试', onPressed: load),
            ],
            if (v != null) ...[
              SettingsSection(
                padTop: false,
                hasLeading: false,
                children: [
                  SettingsRow(title: '楼栋', subtitle: v.building),
                  SettingsRow(title: '类别', subtitle: v.category),
                  SettingsRow(title: '座位', subtitle: v.capacity),
                ],
              ),
              if (v.introduction.isNotEmpty)
                Panel(child: SelectableText(v.introduction)),
              for (final image in v.images)
                if (Uri.tryParse(image) case final Uri u
                    when u.scheme == 'https' && u.host == 'eclass.xmu.edu.cn')
                  Image.network(
                    image,
                    errorBuilder: (_, e, s) => const Text('照片暂未加载'),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}
