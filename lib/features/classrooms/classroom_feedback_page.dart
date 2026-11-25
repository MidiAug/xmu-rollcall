import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/app_hierarchy_choice_page.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'classroom_providers.dart';
import 'classroom_page_session.dart';

class ClassroomFeedbackPage extends ConsumerStatefulWidget {
  const ClassroomFeedbackPage({super.key});
  @override
  ConsumerState<ClassroomFeedbackPage> createState() => _FeedbackState();
}

class _FeedbackState extends ConsumerState<ClassroomFeedbackPage>
    with ClassroomPageSession<ClassroomFeedbackPage> {
  List<ClassroomFeedback>? rows;
  List<ClassroomFeedbackChoice> categories = [], types = [];
  List<ClassroomInfo> rooms = [];
  ClassroomHome? home;
  ClassroomInfo? room;
  ClassroomFeedbackChoice? category, type;
  final form = GlobalKey<FormState>(),
      phone = TextEditingController(),
      content = TextEditingController();
  bool editing = false, uncertain = false;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  @override
  void dispose() {
    phone.dispose();
    content.dispose();
    super.dispose();
  }

  Future<void> load() => perform(() async {
    final v = await ref
        .read(classroomProvider.notifier)
        .run((c) => c.feedback());
    if (current) rows = v;
  });
  Future<void> compose() => perform(() async {
    home = await ref.read(classroomProvider.future);
    final v = await ref
        .read(classroomProvider.notifier)
        .run(
          (c) async => (
            categories: await c.feedbackCategories(),
            types: await c.feedbackTypes(),
            rooms: await c.rooms(),
          ),
        );
    if (!current) return;
    categories = v.categories;
    types = v.types;
    rooms = v.rooms;
    category = categories.firstOrNull;
    type = types.firstOrNull;
    editing = true;
  });
  Future<void> chooseRoom() async {
    final v = await AppPageRoutes.push<ClassroomInfo>(
      context,
      AppHierarchyChoicePage<ClassroomInfo>(
        title: '选择教室',
        items: rooms,
        pathOf: (r) => [
          home!.buildings
                  .where((b) => b.id == r.buildingId)
                  .firstOrNull
                  ?.name ??
              r.building,
          r.name,
        ],
        selected: room,
      ),
    );
    if (current && v != null) setState(() => room = v);
  }

  Future<void> submit() async {
    if (!form.currentState!.validate() ||
        room == null ||
        category == null ||
        type == null ||
        uncertain) {
      return;
    }
    final building = home!.buildings
        .where((v) => v.id == room!.buildingId)
        .firstOrNull;
    if (building?.campusId == null) {
      setState(() => error = '该教室的校区信息未完整取得，请重新选择');
      return;
    }
    final ok = await showAppConfirmDialog(
      context,
      title: '提交反馈？',
      message:
          '${building!.name} ${room!.name}\n${category!.name} ${type!.name}\n${content.text.trim()}\n学校会收到填写的联系电话。',
      confirmLabel: '提交反馈',
    );
    if (!mounted || !current || !ok) return;
    await perform(() async {
      try {
        await ref
            .read(classroomProvider.notifier)
            .run(
              (c) => c.sendFeedback(
                room: room!,
                campus: building.campusId!,
                building: building.id,
                category: category!.id,
                type: type!.id,
                phone: phone.text.trim(),
                content: content.text.trim(),
              ),
            );
        final v = await ref
            .read(classroomProvider.notifier)
            .run((c) => c.feedback());
        if (current) {
          rows = v;
          editing = false;
          content.clear();
        }
      } on ClassroomWriteUncertain {
        uncertain = true;
        rethrow;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    watchSession();
    return SubpageScaffold(
      title: '意见与建议',
      isBusy: () => busy,
      hasUnsavedChanges: () => editing && content.text.isNotEmpty && !uncertain,
      actions: [if (!editing) AppRefreshButton(busy: busy, onRefresh: load)],
      body: AppPageViewport(
        maxWidth: AppLayout.readingMaxWidth,
        builder: (context, insets) => ListView(
          padding: insets + EdgeInsets.all(AppSpace.pageXOf(context)),
          children: [
            if (error != null) Text(error!),
            if (busy) const Center(child: CircularProgressIndicator()),
            if (!editing) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton(
                  label: '新建反馈',
                  icon: AppIcons.add,
                  busy: busy,
                  onPressed: compose,
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              if (rows != null && rows!.isEmpty)
                const EmptyHint(icon: AppIcons.document, title: '暂无反馈记录'),
              if (rows != null && rows!.isNotEmpty)
                SettingsSection(
                  hasLeading: false,
                  children: [
                    for (final row in rows!)
                      SettingsRow(
                        title: row.content,
                        subtitle: '${row.status}\n${row.time}',
                      ),
                  ],
                ),
            ] else
              Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SettingsSection(
                      padTop: false,
                      hasLeading: false,
                      children: [
                        SettingsRow(
                          title: '教室',
                          subtitle: room?.name ?? '请选择教室',
                          trailing: const Icon(AppIcons.right, size: 14),
                          onTap: busy || uncertain ? null : chooseRoom,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.md),
                    Wrap(
                      spacing: AppSpace.sm,
                      runSpacing: AppSpace.sm,
                      children: [
                        if (category != null)
                          AppShellSelect<ClassroomFeedbackChoice>(
                            semanticLabel: '反馈类别',
                            value: category!,
                            items: categories,
                            labelOf: (v) => v.name,
                            onChanged: busy || uncertain
                                ? null
                                : (v) => setState(() => category = v),
                          ),
                        if (type != null)
                          AppShellSelect<ClassroomFeedbackChoice>(
                            semanticLabel: '反馈类型',
                            value: type!,
                            items: types,
                            labelOf: (v) => v.name,
                            onChanged: busy || uncertain
                                ? null
                                : (v) => setState(() => type = v),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.md),
                    TextFormField(
                      controller: phone,
                      enabled: !busy && !uncertain,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: '联系电话'),
                      validator: (v) =>
                          RegExp(r'^1[3-9]\d{9}$').hasMatch(v?.trim() ?? '')
                          ? null
                          : '请填写手机号',
                    ),
                    const SizedBox(height: AppSpace.md),
                    TextFormField(
                      controller: content,
                      enabled: !busy && !uncertain,
                      minLines: 4,
                      maxLines: 8,
                      decoration: const InputDecoration(labelText: '反馈内容'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? '请填写反馈内容' : null,
                    ),
                    const SizedBox(height: AppSpace.lg),
                    AppButton(
                      label: uncertain ? '查看反馈记录' : '提交反馈',
                      busy: busy,
                      onPressed: uncertain
                          ? () {
                              setState(() => editing = false);
                              unawaited(load());
                            }
                          : room == null
                          ? null
                          : submit,
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
