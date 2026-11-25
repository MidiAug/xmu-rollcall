import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_hierarchy_choice_page.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'campus_card_providers.dart';
import 'campus_card_page_session.dart';
import 'campus_card_forms.dart';

class CampusCardPowerPage extends ConsumerStatefulWidget {
  const CampusCardPowerPage({super.key});
  @override
  ConsumerState<CampusCardPowerPage> createState() =>
      _CampusCardPowerPageState();
}

class _CampusCardPowerPageState extends ConsumerState<CampusCardPowerPage>
    with CampusCardPageSession<CampusCardPowerPage> {
  final form = GlobalKey<FormState>();
  final roomNumber = TextEditingController();
  List<CardChoice>? applications;
  List<CardChoice> areas = [], buildings = [];
  CardChoice? application, area, building;
  CardElectricRoom? resolved;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  @override
  void dispose() {
    roomNumber.dispose();
    super.dispose();
  }

  Future<void> load() => perform(() async {
    final result = await ref
        .read(campusCardInfoProvider.notifier)
        .run((c) => c.electricApplications());
    if (!current) return;
    applications = result;
    if (result.length == 1) {
      application = result.single;
      final values = await ref
          .read(campusCardInfoProvider.notifier)
          .run((c) => c.electricAreas(application!));
      if (current) areas = values;
    }
  });
  Future<CardChoice?> choose(
    String title,
    List<CardChoice> choices,
    CardChoice? selected, {
    bool hierarchy = false,
  }) => AppPageRoutes.push<CardChoice>(
    context,
    AppHierarchyChoicePage(
      title: title,
      items: choices,
      pathOf: (v) => hierarchy ? v.path : [v.name],
      selected: selected,
    ),
  );
  Future<void> selectApplication() async {
    final selected = await choose('电费服务', applications!, application);
    if (!current || selected == null) return;
    setState(() {
      application = selected;
      area = null;
      building = null;
      areas = [];
      buildings = [];
      resolved = null;
    });
    await perform(() async {
      final values = await ref
          .read(campusCardInfoProvider.notifier)
          .run((c) => c.electricAreas(selected));
      if (current) areas = values;
    });
  }

  Future<void> selectArea() async {
    final selected = await choose('园区', areas, area, hierarchy: true);
    if (!current || selected == null) return;
    setState(() {
      area = selected;
      building = null;
      buildings = [];
      resolved = null;
    });
    await perform(() async {
      final values = await ref
          .read(campusCardInfoProvider.notifier)
          .run((c) => c.electricBuildings(application!, selected));
      if (current) buildings = values;
    });
  }

  Future<void> selectBuilding() async {
    final selected = await choose('楼栋', buildings, building);
    if (!current || selected == null) return;
    setState(() {
      building = selected;
      resolved = null;
    });
  }

  Future<void> check() async {
    if (!form.currentState!.validate()) return;
    if (application == null || area == null || building == null) {
      setState(() => error = '请选择园区和楼栋');
      return;
    }
    await perform(() async {
      final result = await ref
          .read(campusCardInfoProvider.notifier)
          .run(
            (c) => c.electricRoom(
              application!,
              area!,
              building!,
              roomNumber.text.trim().padLeft(4, '0'),
            ),
          );
      if (current) resolved = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    watchSession();
    return SubpageScaffold(
      title: '宿舍电费',
      isBusy: () => busy,
      body: AppPageViewport(
        maxWidth: AppLayout.readingMaxWidth,
        builder: (context, insets) => ListView(
          padding: insets + EdgeInsets.all(AppSpace.pageXOf(context)),
          children: [
            if (applications == null) ...[
              if (busy) const Center(child: CircularProgressIndicator()),
              if (error != null) Text(error!),
              if (!busy) AppButton(label: '重试', onPressed: load),
            ] else if (applications!.isEmpty)
              const EmptyHint(icon: AppIcons.info, title: '暂无可用的电费服务')
            else ...[
              SettingsSection(
                padTop: false,
                hasLeading: false,
                children: [
                  if (applications!.length > 1)
                    SettingsRow(
                      title: '电费服务',
                      subtitle: application?.name ?? '请选择',
                      trailing: const Icon(AppIcons.right, size: 14),
                      onTap: busy ? null : selectApplication,
                    ),
                  SettingsRow(
                    title: '园区',
                    subtitle: area?.name ?? '选择校区与园区',
                    trailing: const Icon(AppIcons.right, size: 14),
                    enabled: application != null && !busy,
                    onTap: selectArea,
                  ),
                  SettingsRow(
                    title: '楼栋',
                    subtitle: building?.name ?? '选择楼栋',
                    trailing: const Icon(AppIcons.right, size: 14),
                    enabled: area != null && !busy,
                    onTap: selectBuilding,
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              Form(
                key: form,
                child: TextFormField(
                  controller: roomNumber,
                  enabled: !busy,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '房间号',
                    hintText: '例如0301',
                  ),
                  onChanged: (_) => setState(() => resolved = null),
                  validator: (v) =>
                      RegExp(r'^\d{1,4}$').hasMatch(v?.trim() ?? '')
                      ? null
                      : '请输入房间号，最多四位数字',
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: Text(error!),
                ),
              if (resolved != null) ...[
                Text(
                  '缴费房间 ${resolved!.name}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpace.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppButton(
                    label: '填写缴费金额',
                    onPressed: () => AppPageRoutes.push<void>(
                      context,
                      CampusCardPaymentPage(room: resolved),
                    ),
                  ),
                ),
              ] else
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppButton(label: '核对宿舍', busy: busy, onPressed: check),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
