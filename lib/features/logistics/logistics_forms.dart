import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/app_hierarchy_choice_page.dart';
import 'package:xmu_rollcall/app/app_checkbox.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'logistics_client.dart';
import 'logistics_form_models.dart';
import 'logistics_form_widgets.dart';
import 'logistics_provider.dart';

class LogisticsRepairForm extends ConsumerStatefulWidget {
  const LogisticsRepairForm({super.key});
  @override
  ConsumerState<LogisticsRepairForm> createState() =>
      _LogisticsRepairFormState();
}

class _LogisticsRepairFormState extends ConsumerState<LogisticsRepairForm>
    with LogisticsIdentityPage<LogisticsRepairForm> {
  final formKey = GlobalKey<FormState>();
  final address = TextEditingController(),
      name = TextEditingController(),
      phone = TextEditingController(),
      content = TextEditingController();
  List<LogisticsChoice>? areas;
  List<LogisticsChoice> projects = [];
  LogisticsChoice? area, project;
  LogisticsRepairLocation? lastLocation;
  LogisticsChoice? lastArea;
  Map<String, String> settings = {};
  Map<String, dynamic>? recipient;
  List<LogisticsAttachment> files = [];
  int quantity = 1;
  bool publish = true, unattended = false, uncertain = false, uploading = false;
  bool editingContact = false;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  @override
  void dispose() {
    for (final c in [address, name, phone, content]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() => perform(() async {
    final data = await ref
        .read(logisticsProvider.notifier)
        .run(
          (c) async => (
            areas: logisticsChoices(await c.areas()),
            settings: logisticsSettings(await c.repairSettings()),
            name: c.userName,
            phone: c.phone,
          ),
        );
    if (!current) return;
    final previous = await ref
        .read(logisticsProvider.notifier)
        .lastRepairLocation();
    if (!current) return;
    areas = data.areas;
    lastLocation = previous;
    lastArea = areas!
        .where((option) => option.id == previous?.areaId)
        .firstOrNull;
    settings = data.settings;
    name.text = data.name ?? '';
    phone.text = data.phone ?? '';
    editingContact =
        name.text.isEmpty || logisticsPhone(phone.text, repair: true) != null;
  });
  Future<void> selectArea() async {
    final chosen = await AppPageRoutes.push<LogisticsChoice>(
      context,
      AppHierarchyChoicePage(
        title: '故障区域',
        items: areas!,
        pathOf: (v) => v.path,
        selected: area,
      ),
    );
    if (!current || chosen == null) return;
    await useArea(chosen);
  }

  Future<void> useArea(LogisticsChoice chosen) async {
    setState(() {
      area = chosen;
      project = null;
      recipient = null;
      projects = [];
    });
    await perform(() async {
      final next = await ref
          .read(logisticsProvider.notifier)
          .run((c) async => logisticsChoices(await c.projects(chosen.id)));
      if (current) projects = next;
    });
  }

  Future<void> selectProject() async {
    if (area == null) {
      setState(() => error = '请先选择故障区域');
      return;
    }
    final chosen = await AppPageRoutes.push<LogisticsChoice>(
      context,
      AppHierarchyChoicePage(
        title: '维修项目',
        items: projects,
        pathOf: (v) => v.path,
        selected: project,
      ),
    );
    if (!current || chosen == null) return;
    setState(() {
      project = chosen;
      recipient = null;
    });
    await perform(() async {
      final next = await ref
          .read(logisticsProvider.notifier)
          .run((c) => c.repairRecipient(area!.id, chosen.id));
      if (current) recipient = next;
    });
  }

  Future<void> submit() async {
    if (uploading) {
      setState(() => error = '附件正在上传，请稍候');
      return;
    }
    if (!formKey.currentState!.validate()) return;
    if (area == null || project == null || recipient == null) {
      setState(() => error = '请选择故障区域和维修项目，核对服务单位后再提交');
      return;
    }
    final imagesRequired = (jsonDecode(settings['011'] ?? '[]') as List)
        .contains('6');
    if (imagesRequired && files.isEmpty) {
      setState(() => error = '该服务要求上传报修图片');
      return;
    }
    final confirmed = await showAppConfirmDialog(
      context,
      title: '提交报修？',
      confirmLabel: '提交报修',
      message:
          '${area!.displayPath}\n${address.text.trim()}\n${project!.displayPath}\n数量 $quantity\n收费类型 ${recipient!['dept']['payName'] ?? '待受理单位核对'}\n${publish ? '将在报修平台公开展示' : '不在报修平台公开展示'}',
    );
    if (!current || !confirmed) return;
    await perform(() async {
      try {
        await ref.read(logisticsProvider.notifier).submitRepair({
          'type': '0',
          'ifShielding': '1',
          'areaId': area!.id,
          'areaName': area!.label,
          'address': address.text.trim(),
          'addressDetail': address.text.trim(),
          'projectId': project!.id,
          'projectName': project!.label,
          'bookTime': '',
          'repairUserName': name.text.trim(),
          'repairUserMobile': phone.text.trim(),
          'repairDeptName': '',
          'ifOnduty': unattended ? '1' : '0',
          'repairNum': quantity,
          'content': content.text.trim(),
          'ifPublish': publish ? '1' : '0',
          'ifUrgent': '0',
          'id': '',
          'resourcesVOS': files.map((f) => f.toRepairJson()).toList(),
          'source': '1',
          'ifRecord': 0,
        });
        if (mounted && current) Navigator.of(context).pop(true);
      } on LogisticsWriteUncertain {
        uncertain = true;
        rethrow;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    watchIdentity();
    return SubpageScaffold(
      title: '我要报修',
      isBusy: () => busy || uploading,
      hasUnsavedChanges: () =>
          content.text.isNotEmpty || address.text.isNotEmpty,
      body: AppPageViewport(
        maxWidth: AppLayout.readingMaxWidth,
        builder: (context, insets) => ListView(
          padding: insets + EdgeInsets.all(AppSpace.pageXOf(context)),
          children: [
            if (areas == null) ...[
              if (busy) const Center(child: CircularProgressIndicator()),
              if (error != null) Text(error!),
              if (!busy) AppButton(label: '重新读取报修选项', onPressed: load),
            ] else
              Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SettingsSection(
                      padTop: false,
                      hasLeading: false,
                      children: [
                        SettingsRow(
                          title: '故障区域',
                          subtitle: area?.displayPath ?? '选择校区与楼栋',
                          trailing: const Icon(AppIcons.right, size: 14),
                          onTap: busy ? null : selectArea,
                        ),
                        if (lastLocation != null &&
                            (area?.id != lastLocation!.areaId ||
                                address.text.trim() != lastLocation!.address))
                          SettingsRow(
                            title: '上次报修地点',
                            subtitle:
                                '${lastArea?.displayPath ?? lastLocation!.areaName}\n${lastLocation!.address}',
                            trailing: lastArea == null
                                ? const Text('已停用')
                                : const Icon(AppIcons.right, size: 14),
                            enabled: !busy && lastArea != null,
                            onTap: () async {
                              address.text = lastLocation!.address;
                              await useArea(lastArea!);
                            },
                          ),
                        SettingsRow(
                          title: '维修项目',
                          subtitle: project?.displayPath ?? '选择维修项目',
                          trailing: const Icon(AppIcons.right, size: 14),
                          onTap: busy ? null : selectProject,
                        ),
                        if (recipient != null)
                          SettingsRow(
                            title: '服务单位',
                            subtitle: '${recipient!['dept']['deptName'] ?? ''}',
                          ),
                        if (recipient != null)
                          SettingsRow(
                            title: '收费类型',
                            subtitle:
                                '${recipient!['dept']['payName'] ?? '待核对'}',
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.lg),
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.md),
                      child: TextFormField(
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        controller: address,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: '详细地址',
                          alignLabelWithHint: true,
                        ),
                        validator: logisticsRequired,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.md),
                      child: TextFormField(
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        controller: content,
                        decoration: const InputDecoration(
                          labelText: '故障描述',
                          alignLabelWithHint: true,
                        ),
                        minLines: 4,
                        maxLines: 6,
                        keyboardType: TextInputType.multiline,
                        maxLength: 200,
                        validator: logisticsRequired,
                      ),
                    ),
                    SettingsSection(
                      padTop: false,
                      hasLeading: false,
                      children: [
                        if (!editingContact)
                          SettingsRow(
                            title: '联系信息',
                            subtitle: '${name.text}  ${phone.text}',
                            trailing: const Icon(AppIcons.right, size: 14),
                            onTap: busy
                                ? null
                                : () => setState(() => editingContact = true),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.all(AppSpace.md),
                            child: Column(
                              children: [
                                TextFormField(
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                  controller: name,
                                  decoration: const InputDecoration(
                                    labelText: '报修人',
                                  ),
                                  validator: logisticsRequired,
                                ),
                                const SizedBox(height: AppSpace.md),
                                TextFormField(
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                  controller: phone,
                                  decoration: const InputDecoration(
                                    labelText: '联系电话',
                                  ),
                                  keyboardType: TextInputType.phone,
                                  validator: (value) =>
                                      logisticsPhone(value, repair: true),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.md),
                    SettingsRow(
                      title: '故障数量',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppIconButton(
                            tooltip: '减少数量',
                            icon: const Icon(AppIcons.subtract),
                            onPressed: !busy && quantity > 1
                                ? () => setState(() => quantity--)
                                : null,
                          ),
                          Text('$quantity'),
                          AppIconButton(
                            tooltip: '增加数量',
                            icon: const Icon(AppIcons.add),
                            onPressed: busy
                                ? null
                                : () => setState(() => quantity++),
                          ),
                        ],
                      ),
                    ),
                    AppCheckboxRow(
                      value: publish,
                      label: '公开展示这条报修',
                      onChanged: busy
                          ? null
                          : (v) => setState(() => publish = v),
                    ),
                    if (settings['014'] == '1')
                      AppCheckboxRow(
                        value: unattended,
                        label: '允许故障地点无人时维修',
                        onChanged: busy
                            ? null
                            : (v) => setState(() => unattended = v),
                      ),
                    const SizedBox(height: AppSpace.md),
                    LogisticsAttachments(
                      files: files,
                      onBusyChanged: (v) => setState(() => uploading = v),
                      enabled: !busy,
                      onChanged: (v) => setState(() => files = v),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.md),
                        child: Text(error!),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppButton(
                        label: uncertain ? '核对我的报修' : '提交报修',
                        busy: busy || uploading,
                        onPressed: uncertain
                            ? () => Navigator.of(context).pop(true)
                            : submit,
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

class LogisticsFeedbackForm extends ConsumerStatefulWidget {
  const LogisticsFeedbackForm({super.key});
  @override
  ConsumerState<LogisticsFeedbackForm> createState() =>
      _LogisticsFeedbackFormState();
}

class _LogisticsFeedbackFormState extends ConsumerState<LogisticsFeedbackForm>
    with LogisticsIdentityPage<LogisticsFeedbackForm> {
  final formKey = GlobalKey<FormState>();
  final title = TextEditingController(),
      content = TextEditingController(),
      phone = TextEditingController();
  List<LogisticsChoice>? scopes;
  List<LogisticsChoice> types = [];
  LogisticsChoice? scope, type;
  List<LogisticsAttachment> files = [];
  bool accept = true, uncertain = false, uploading = false;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  @override
  void dispose() {
    for (final c in [title, content, phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() => perform(() async {
    final data = await ref
        .read(logisticsProvider.notifier)
        .run(
          (c) async => (
            scopes: logisticsChoices(await c.feedbackScopes()),
            types: logisticsChoices(await c.feedbackTypes()),
            phone: c.phone,
          ),
        );
    if (!current) return;
    scopes = data.scopes;
    types = data.types;
    type = types.firstOrNull;
    phone.text = data.phone ?? '';
  });
  Future<void> submit() async {
    if (uploading) {
      setState(() => error = '附件正在上传，请稍候');
      return;
    }
    if (!formKey.currentState!.validate()) return;
    if (type == null || scope == null) {
      setState(() => error = '请选择反馈类别和服务类型');
      return;
    }
    if (scope!.imageRequired && files.isEmpty) {
      setState(() => error = '该服务要求上传图片');
      return;
    }
    final ok = await showAppConfirmDialog(
      context,
      title: '提交${type!.label}？',
      confirmLabel: '提交${type!.label}',
      message:
          '${scope!.displayPath}\n${title.text.trim()}\n反馈将发送至服务部门，并可能在服务监督平台展示。',
    );
    if (!current || !ok) return;
    await perform(() async {
      try {
        await ref
            .read(logisticsProvider.notifier)
            .run(
              (c) => c.submitFeedback({
                'postTitle': title.text.trim(),
                'content': content.text.trim(),
                'phone': phone.text.trim(),
                'projectName': scope!.ids,
                'ifAccept': accept ? '1' : '0',
                'serviceScopeId': scope!.id,
                'serviceScopeName': scope!.leafName,
                'id': '',
                'serverType': int.parse(type!.id),
                'images': files.map((f) => f.path).join(','),
                'source': 'pc',
                'keyWords': <String>[],
              }),
            );
        if (mounted && current) Navigator.of(context).pop(true);
      } on LogisticsWriteUncertain {
        uncertain = true;
        rethrow;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    watchIdentity();
    return SubpageScaffold(
      title: '意见反馈',
      isBusy: () => busy || uploading,
      hasUnsavedChanges: () => title.text.isNotEmpty || content.text.isNotEmpty,
      body: AppPageViewport(
        maxWidth: AppLayout.readingMaxWidth,
        builder: (context, insets) => ListView(
          padding: insets + EdgeInsets.all(AppSpace.pageXOf(context)),
          children: [
            if (scopes == null) ...[
              if (busy) const Center(child: CircularProgressIndicator()),
              if (error != null) Text(error!),
              if (!busy) AppButton(label: '重新读取反馈选项', onPressed: load),
            ] else
              Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSegmentedControl<LogisticsChoice>(
                      segments: [
                        for (final option in types)
                          AppSegment(value: option, label: option.leafName),
                      ],
                      value: type!,
                      enabled: !busy,
                      expanded: true,
                      onChanged: (value) => setState(() => type = value),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    SettingsSection(
                      padTop: false,
                      hasLeading: false,
                      children: [
                        SettingsRow(
                          title: '服务类型',
                          subtitle: scope?.displayPath ?? '选择服务部门与事项',
                          trailing: const Icon(AppIcons.right, size: 14),
                          onTap: busy
                              ? null
                              : () async {
                                  final v =
                                      await AppPageRoutes.push<LogisticsChoice>(
                                        context,
                                        AppHierarchyChoicePage(
                                          title: '服务类型',
                                          items: scopes!,
                                          pathOf: (v) => v.path,
                                          selected: scope,
                                        ),
                                      );
                                  if (current && v != null) {
                                    setState(() => scope = v);
                                  }
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.lg),
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.md),
                      child: TextFormField(
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        controller: title,
                        decoration: const InputDecoration(
                          labelText: '标题',
                          alignLabelWithHint: true,
                        ),
                        maxLength: 50,
                        validator: logisticsRequired,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.md),
                      child: TextFormField(
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        controller: content,
                        decoration: const InputDecoration(
                          labelText: '详细说明',
                          alignLabelWithHint: true,
                        ),
                        minLines: 5,
                        maxLines: 7,
                        keyboardType: TextInputType.multiline,
                        maxLength: 800,
                        validator: logisticsRequired,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.md),
                      child: TextFormField(
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        controller: phone,
                        decoration: const InputDecoration(
                          labelText: '联系方式',
                          alignLabelWithHint: true,
                        ),
                        keyboardType: TextInputType.phone,
                        validator: logisticsPhone,
                      ),
                    ),
                    AppCheckboxRow(
                      value: accept,
                      label: '接受电话沟通',
                      onChanged: busy
                          ? null
                          : (v) => setState(() => accept = v),
                    ),
                    const SizedBox(height: AppSpace.md),
                    LogisticsAttachments(
                      files: files,
                      imagesOnly: true,
                      onBusyChanged: (v) => setState(() => uploading = v),
                      enabled: !busy,
                      onChanged: (v) => setState(() => files = v),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.md),
                        child: Text(error!),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppButton(
                        label: uncertain ? '核对我的反馈' : '提交反馈',
                        busy: busy || uploading,
                        onPressed: uncertain
                            ? () => Navigator.of(context).pop(true)
                            : submit,
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

class LogisticsEvaluationPage extends ConsumerStatefulWidget {
  const LogisticsEvaluationPage({super.key, required this.repairId});
  final String repairId;
  @override
  ConsumerState<LogisticsEvaluationPage> createState() =>
      _LogisticsEvaluationPageState();
}

class _LogisticsEvaluationPageState
    extends ConsumerState<LogisticsEvaluationPage>
    with LogisticsIdentityPage<LogisticsEvaluationPage> {
  List<Map<String, dynamic>>? fields;
  List<LogisticsChoice> labels = [];
  final selected = <String>{};
  final content = TextEditingController();
  bool lowScoreRework = false, uncertain = false;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  @override
  void dispose() {
    content.dispose();
    super.dispose();
  }

  Future<void> load() => perform(() async {
    final data = await ref
        .read(logisticsProvider.notifier)
        .run(
          (c) async => (
            fields: await c.evaluationFields(),
            labels: await c.evaluationLabels(),
            settings: logisticsSettings(await c.repairSettings()),
          ),
        );
    if (!current) return;
    fields = (data.fields as List)
        .map((e) => Map<String, dynamic>.from(e as Map)..['star'] = 0)
        .toList();
    labels = logisticsChoices(data.labels);
    lowScoreRework = data.settings['521'] == '1';
  });
  Future<void> submit() async {
    if (fields!.any((f) => f['star'] == 0)) {
      setState(() => error = '请为每个项目选择评分');
      return;
    }
    final score = fields!.fold<double>(
      0,
      (sum, f) =>
          sum + (f['weight'] as num).toDouble() * (f['star'] as int) / 5,
    );
    final ok = await showAppConfirmDialog(
      context,
      title: '提交维修评价？',
      confirmLabel: '提交评价',
      message: lowScoreRework && score < 60
          ? '总评分 ${score.round()}分，提交后可能触发返修。'
          : '总评分 ${score.round()}分',
    );
    if (!current || !ok) return;
    await perform(() async {
      try {
        await ref
            .read(logisticsProvider.notifier)
            .run(
              (c) => c.evaluate(
                widget.repairId,
                fields!,
                content.text.trim(),
                selected.toList(),
              ),
            );
        if (mounted && current) Navigator.of(context).pop(true);
      } on LogisticsWriteUncertain {
        uncertain = true;
        rethrow;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    watchIdentity();
    return SubpageScaffold(
      title: '维修评价',
      isBusy: () => busy,
      body: AppPageViewport(
        maxWidth: AppLayout.readingMaxWidth,
        builder: (context, insets) => ListView(
          padding: insets + EdgeInsets.all(AppSpace.pageXOf(context)),
          children: [
            if (fields == null) ...[
              if (busy) const Center(child: CircularProgressIndicator()),
              if (error != null) Text(error!),
              if (!busy) AppButton(label: '重新读取评价选项', onPressed: load),
            ] else ...[
              for (final field in fields!)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${field['name']}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Wrap(
                        children: [
                          for (var star = 1; star <= 5; star++)
                            AppIconButton(
                              tooltip: '${field['name']} $star星',
                              active: (field['star'] as int) >= star,
                              icon: Icon(
                                (field['star'] as int) >= star
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                              ),
                              onPressed: busy
                                  ? null
                                  : () => setState(() => field['star'] = star),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.md),
                child: TextFormField(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: content,
                  decoration: const InputDecoration(
                    labelText: '其他建议与意见',
                    alignLabelWithHint: true,
                  ),
                  minLines: 3,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  maxLength: 200,
                ),
              ),
              for (final label in labels)
                AppCheckboxRow(
                  value: selected.contains(label.label),
                  label: label.label,
                  onChanged: busy
                      ? null
                      : (v) => setState(
                          () => v == true
                              ? selected.add(label.label)
                              : selected.remove(label.label),
                        ),
                ),
              if (error != null) Text(error!),
              const SizedBox(height: AppSpace.md),
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton(
                  label: uncertain ? '核对报修状态' : '提交评价',
                  busy: busy,
                  onPressed: uncertain
                      ? () => Navigator.of(context).pop(true)
                      : submit,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
