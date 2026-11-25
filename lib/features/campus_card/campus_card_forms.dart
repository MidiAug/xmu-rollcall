import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'campus_card_providers.dart';
import 'campus_card_page_session.dart';
import 'campus_card_cashier.dart';

class CampusCardPaymentPage extends ConsumerStatefulWidget {
  const CampusCardPaymentPage({super.key, this.room});
  final CardElectricRoom? room;
  @override
  ConsumerState<CampusCardPaymentPage> createState() =>
      _CampusCardPaymentPageState();
}

class _CampusCardPaymentPageState extends ConsumerState<CampusCardPaymentPage>
    with CampusCardPageSession<CampusCardPaymentPage> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController();
  CardPaymentOrder? order;
  bool uncertain = false;
  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  Future<void> pay() async {
    int? cents;
    if (order == null) {
      if (!form.currentState!.validate()) return;
      cents = cardAmountCents(amount.text)!;
      CampusCardInfo? prepared;
      await perform(() async {
        prepared = await ref.read(campusCardInfoProvider.notifier).account();
      });
      if (!mounted || !current || prepared == null) return;
      final info = prepared!;
      final room = widget.room;
      final confirmed = await showAppConfirmDialog(
        context,
        title: room == null
            ? '充值 ¥${(cents / 100).toStringAsFixed(2)}？'
            : '缴纳电费 ¥${(cents / 100).toStringAsFixed(2)}？',
        message: room == null
            ? '校园卡 ${info.account}\n将在支付宝完成付款。'
            : '${room.area.name}\n${room.building.name}\n房间 ${room.name}\n将在支付宝完成付款。',
        confirmLabel: '前往支付宝',
      );
      if (!mounted || !current || !confirmed) return;
    }
    await perform(() async {
      try {
        if (order == null) {
          final room = widget.room;
          final created = await ref
              .read(campusCardInfoProvider.notifier)
              .run(
                (c) => room == null
                    ? c.recharge(cents!)
                    : c.payElectricity(room, cents!),
              );
          if (!mounted || !current) return;
          order = created;
        }
        final opened = await ref.read(campusCardCashierLauncherProvider)(
          order!.cashier,
        );
        if (!mounted || !current) return;
        if (opened) {
          AppToast.show(context, '已打开支付宝收银台');
        } else {
          error = '未能打开收银台，可点击继续支付';
        }
      } on CampusCardWriteUncertain {
        uncertain = true;
        rethrow;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    watchSession();
    final room = widget.room;
    return SubpageScaffold(
      title: room == null ? '校园卡充值' : '电费缴费',
      isBusy: () => busy,
      hasUnsavedChanges: () => amount.text.isNotEmpty && order == null,
      body: AppPageViewport(
        maxWidth: AppLayout.readingMaxWidth,
        builder: (context, insets) => ListView(
          padding: insets + EdgeInsets.all(AppSpace.pageXOf(context)),
          children: [
            if (room != null)
              SettingsSection(
                padTop: false,
                hasLeading: false,
                children: [
                  SettingsRow(
                    title: room.area.name,
                    subtitle: '${room.building.name}\n${room.name}',
                  ),
                ],
              ),
            const SizedBox(height: AppSpace.md),
            Form(
              key: form,
              child: TextFormField(
                controller: amount,
                enabled: !busy && order == null && !uncertain,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: '金额（元）',
                  prefixText: '¥ ',
                ),
                validator: (v) => cardAmountCents(v ?? '') == null
                    ? '请输入0.01至9999元，最多两位小数'
                    : null,
              ),
            ),
            const SizedBox(height: AppSpace.md),
            if (order == null && !uncertain)
              Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                children: [
                  for (final value in [20, 50, 100, 200])
                    AppButton(
                      label: '$value元',
                      kind: AppButtonKind.secondary,
                      compact: true,
                      onPressed: busy
                          ? null
                          : () => setState(() => amount.text = '$value'),
                    ),
                ],
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
                label: uncertain
                    ? '核对账户'
                    : order == null
                    ? '前往支付宝'
                    : '继续支付',
                busy: busy,
                onPressed: uncertain
                    ? () => perform(() async {
                        await ref
                            .read(campusCardInfoProvider.notifier)
                            .refresh(afterMutation: true);
                        if (mounted && context.mounted && current) {
                          Navigator.of(context).pop();
                        }
                      })
                    : pay,
              ),
            ),
            if (order != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.md),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AppButton(
                    label: '付款后核对余额',
                    kind: AppButtonKind.secondary,
                    busy: busy,
                    onPressed: () => perform(() async {
                      await ref
                          .read(campusCardInfoProvider.notifier)
                          .refresh(afterMutation: true);
                      if (context.mounted && current) {
                        Navigator.of(context).pop();
                      }
                    }),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CampusCardSecurityPage extends ConsumerStatefulWidget {
  const CampusCardSecurityPage({super.key, this.lost = false});
  final bool lost;
  @override
  ConsumerState<CampusCardSecurityPage> createState() =>
      _CampusCardSecurityPageState();
}

class _CampusCardSecurityPageState extends ConsumerState<CampusCardSecurityPage>
    with CampusCardPageSession<CampusCardSecurityPage> {
  final form = GlobalKey<FormState>();
  final password = TextEditingController(),
      confirmation = TextEditingController(),
      code = TextEditingController();
  Timer? timer;
  int remaining = 0;
  bool uncertain = false;
  @override
  void dispose() {
    timer?.cancel();
    password.dispose();
    confirmation.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> sendCode() => perform(() async {
    await ref
        .read(campusCardInfoProvider.notifier)
        .run((c) => c.sendPasswordCode());
    if (!mounted || !current) return;
    remaining = 120;
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!current || remaining <= 1) {
        t.cancel();
        if (current) setState(() => remaining = 0);
      } else {
        setState(() => remaining--);
      }
    });
    AppToast.show(context, '验证码已发送');
  });
  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    CampusCardInfo? prepared;
    await perform(() async {
      final info = await ref.read(campusCardInfoProvider.notifier).account();
      if (widget.lost && info.lost) throw const CampusCardException('这张校园卡已挂失');
      prepared = info;
    });
    if (!mounted || !current || prepared == null) return;
    final info = prepared!;
    final confirmed = await showAppConfirmDialog(
      context,
      title: widget.lost ? '挂失这张校园卡？' : '修改查询密码？',
      confirmLabel: widget.lost ? '挂失校园卡' : '修改密码',
      destructive: widget.lost,
      message: widget.lost
          ? '卡号 ${info.account}\n挂失后这张校园卡将停止使用。'
          : '新密码用于校园卡查询和相关操作。',
    );
    if (!mounted || !current || !confirmed) return;
    await perform(() async {
      try {
        await ref
            .read(campusCardInfoProvider.notifier)
            .run(
              (c) => widget.lost
                  ? c.lose(password.text)
                  : c.changePassword(password.text, code.text.trim()),
            );
        if (!mounted || !current) return;
        password.clear();
        confirmation.clear();
        code.clear();
        await ref
            .read(campusCardInfoProvider.notifier)
            .refresh(afterMutation: true);
        if (mounted && current) {
          AppToast.show(context, widget.lost ? '已提交挂失' : '查询密码已修改');
          Navigator.of(context).pop();
        }
      } on CampusCardWriteUncertain {
        uncertain = true;
        password.clear();
        confirmation.clear();
        rethrow;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    watchSession();
    final snapshot = ref.watch(campusCardInfoProvider);
    final info = snapshot.isReloading ? null : snapshot.valueOrNull;
    return SubpageScaffold(
      title: widget.lost ? '卡片挂失' : '修改查询密码',
      isBusy: () => busy,
      body: AppPageViewport(
        maxWidth: AppLayout.readingMaxWidth,
        builder: (context, insets) => ListView(
          padding: insets + EdgeInsets.all(AppSpace.pageXOf(context)),
          children: [
            if (widget.lost && info?.lost == true)
              const EmptyHint(icon: AppIcons.guard, title: '这张校园卡已挂失')
            else
              Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.lost && info != null) ...[
                      SettingsSection(
                        padTop: false,
                        hasLeading: false,
                        children: [
                          SettingsRow(title: '卡号', subtitle: info.account),
                        ],
                      ),
                      const SizedBox(height: AppSpace.lg),
                    ],
                    TextFormField(
                      controller: password,
                      enabled: !busy && !uncertain,
                      obscureText: true,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: widget.lost ? '校园卡查询密码' : '新查询密码',
                      ),
                      validator: cardPassword,
                    ),
                    if (!widget.lost) ...[
                      const SizedBox(height: AppSpace.md),
                      TextFormField(
                        controller: confirmation,
                        enabled: !busy && !uncertain,
                        obscureText: true,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '确认新密码'),
                        validator: (v) =>
                            v == password.text && cardPassword(v) == null
                            ? null
                            : '两次输入的密码不一致',
                      ),
                      const SizedBox(height: AppSpace.md),
                      TextFormField(
                        controller: code,
                        enabled: !busy && !uncertain,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        decoration: const InputDecoration(labelText: '短信验证码'),
                        validator: cardRequired,
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AppButton(
                          label: remaining > 0 ? '$remaining秒后重发' : '发送验证码',
                          kind: AppButtonKind.secondary,
                          compact: true,
                          busy: busy,
                          onPressed: remaining > 0 || uncertain
                              ? null
                              : sendCode,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpace.lg),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.md),
                        child: Text(error!),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppButton(
                        label: uncertain
                            ? '核对账户'
                            : widget.lost
                            ? '挂失校园卡'
                            : '修改密码',
                        busy: busy,
                        onPressed: uncertain
                            ? () => perform(() async {
                                await ref
                                    .read(campusCardInfoProvider.notifier)
                                    .refresh(afterMutation: true);
                                if (mounted && context.mounted && current) {
                                  Navigator.of(context).pop();
                                }
                              })
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
