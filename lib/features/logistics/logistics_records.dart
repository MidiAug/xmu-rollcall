import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'logistics_form_models.dart';
import 'logistics_form_widgets.dart';
import 'logistics_forms.dart';
import 'logistics_provider.dart';

class LogisticsMessagesPage extends ConsumerStatefulWidget {
  const LogisticsMessagesPage({super.key});
  @override
  ConsumerState<LogisticsMessagesPage> createState() =>
      _LogisticsMessagesPageState();
}

class _LogisticsMessagesPageState extends ConsumerState<LogisticsMessagesPage>
    with LogisticsIdentityPage<LogisticsMessagesPage> {
  final rows = <LogisticsMessage>[];
  int page = 0, total = 0;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load({bool more = false}) => perform(() async {
    final next = more ? page + 1 : 1;
    final result = await ref
        .read(logisticsProvider.notifier)
        .run((c) => c.messagePage(next));
    final parsed = (result['rows'] as List)
        .map((v) => LogisticsMessage(v as Map<String, dynamic>))
        .toList();
    if (!current) return;
    if (!more) rows.clear();
    rows.addAll(parsed);
    page = next;
    total = (result['total'] as num).toInt();
  });
  @override
  Widget build(BuildContext context) {
    watchIdentity();
    return SubpageScaffold(
      title: '后勤消息',
      actions: [AppRefreshButton(busy: busy, onRefresh: load)],
      body: AppPageViewport(
        maxWidth: AppLayout.readingMaxWidth,
        builder: (context, insets) => ListView(
          padding: insets + EdgeInsets.all(AppSpace.pageXOf(context)),
          children: [
            if (error != null) Text(error!),
            if (rows.isEmpty && busy)
              const Center(child: CircularProgressIndicator()),
            if (rows.isEmpty && !busy && error == null)
              const EmptyHint(icon: AppIcons.notification, title: '暂无后勤消息'),
            if (rows.isNotEmpty)
              SettingsSection(
                padTop: false,
                hasLeading: false,
                children: [
                  for (final row in rows)
                    SettingsRow(
                      title: row.title,
                      subtitle: row.time,
                      trailing: row.unread
                          ? const Text('未读')
                          : const Icon(AppIcons.right, size: 14),
                      onTap: () async {
                        await AppPageRoutes.push<void>(
                          context,
                          LogisticsMessagePage(message: row),
                        );
                        if (current) await load();
                      },
                    ),
                ],
              ),
            if (rows.length < total)
              AppButton(
                label: '加载更多消息',
                kind: AppButtonKind.quiet,
                busy: busy,
                onPressed: () => load(more: true),
              ),
          ],
        ),
      ),
    );
  }
}

class LogisticsMessagePage extends ConsumerStatefulWidget {
  const LogisticsMessagePage({super.key, required this.message});
  final LogisticsMessage message;
  @override
  ConsumerState<LogisticsMessagePage> createState() =>
      _LogisticsMessagePageState();
}

class _LogisticsMessagePageState extends ConsumerState<LogisticsMessagePage>
    with LogisticsIdentityPage<LogisticsMessagePage> {
  bool read = false;
  @override
  Widget build(BuildContext context) {
    watchIdentity();
    final m = widget.message;
    return SubpageScaffold(
      title: '消息详情',
      body: AppPageViewport(
        maxWidth: AppLayout.readingMaxWidth,
        builder: (context, insets) => ListView(
          padding: insets + EdgeInsets.all(AppSpace.pageXOf(context)),
          children: [
            Text(m.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpace.sm),
            Text(
              m.time,
              style: AppTypography.caption.copyWith(
                color: AppPalette.of(context).muted,
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            SelectableText(logisticsPlainText(m.content)),
            const SizedBox(height: AppSpace.lg),
            if (m.unread && !read && m.id.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton(
                  label: '标为已读',
                  busy: busy,
                  onPressed: () => perform(() async {
                    await ref
                        .read(logisticsProvider.notifier)
                        .run((c) => c.markMessageRead(m.id));
                    if (current) {
                      setState(() => read = true);
                      await ref
                          .read(logisticsProvider.notifier)
                          .afterMutation();
                    }
                  }),
                ),
              ),
            if (read) const Text('已读'),
            if (error != null) Text(error!),
          ],
        ),
      ),
    );
  }
}

class LogisticsFeedbackPage extends ConsumerStatefulWidget {
  const LogisticsFeedbackPage({super.key});
  @override
  ConsumerState<LogisticsFeedbackPage> createState() =>
      _LogisticsFeedbackPageState();
}

class _LogisticsFeedbackPageState extends ConsumerState<LogisticsFeedbackPage>
    with LogisticsIdentityPage<LogisticsFeedbackPage> {
  final rows = <LogisticsFeedback>[];
  int page = 0, total = 0;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load({bool more = false}) => perform(() async {
    final next = more ? page + 1 : 1;
    final result = await ref
        .read(logisticsProvider.notifier)
        .run((c) => c.feedbackPosts(next));
    final parsed = (result['rows'] as List)
        .map((v) => LogisticsFeedback(v as Map<String, dynamic>))
        .toList();
    if (!current) return;
    if (!more) rows.clear();
    rows.addAll(parsed);
    page = next;
    total = (result['total'] as num).toInt();
  });
  @override
  Widget build(BuildContext context) {
    watchIdentity();
    return SubpageScaffold(
      title: '我的反馈',
      actions: [AppRefreshButton(busy: busy, onRefresh: load)],
      body: AppPageViewport(
        maxWidth: AppLayout.readingMaxWidth,
        builder: (context, insets) => ListView(
          padding: insets + EdgeInsets.all(AppSpace.pageXOf(context)),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                label: '新建反馈',
                icon: AppIcons.add,
                onPressed: () async {
                  await AppPageRoutes.push<bool>(
                    context,
                    const LogisticsFeedbackForm(),
                  );
                  if (current) await load();
                },
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            if (error != null) Text(error!),
            if (rows.isEmpty && busy)
              const Center(child: CircularProgressIndicator()),
            if (rows.isEmpty && !busy && error == null)
              const EmptyHint(icon: AppIcons.document, title: '暂无反馈记录'),
            if (rows.isNotEmpty)
              SettingsSection(
                padTop: false,
                hasLeading: false,
                children: [
                  for (final row in rows)
                    SettingsRow(
                      title: row.title,
                      subtitle: '${row.type}\n${row.scope}',
                      trailing: row.deleted
                          ? const AppStatusBadge('已删除')
                          : row.replies > 0
                          ? AppStatusBadge('${row.replies}条回复')
                          : null,
                      onTap: () async {
                        await AppPageRoutes.push<void>(
                          context,
                          LogisticsFeedbackDetailPage(feedback: row),
                        );
                        if (current) await load();
                      },
                    ),
                ],
              ),
            if (rows.length < total)
              AppButton(
                label: '加载更多反馈',
                kind: AppButtonKind.quiet,
                busy: busy,
                onPressed: () => load(more: true),
              ),
          ],
        ),
      ),
    );
  }
}

class LogisticsFeedbackDetailPage extends ConsumerStatefulWidget {
  const LogisticsFeedbackDetailPage({super.key, required this.feedback});
  final LogisticsFeedback feedback;
  @override
  ConsumerState<LogisticsFeedbackDetailPage> createState() =>
      _LogisticsFeedbackDetailPageState();
}

class _LogisticsFeedbackDetailPageState
    extends ConsumerState<LogisticsFeedbackDetailPage>
    with LogisticsIdentityPage<LogisticsFeedbackDetailPage> {
  List<Map<String, dynamic>> replies = [];
  LogisticsFeedback? latest;
  bool deleteAllowed = true;
  @override
  void initState() {
    super.initState();
    if (!widget.feedback.deleted) unawaited(load());
  }

  Future<void> load() => perform(() async {
    final data = await ref
        .read(logisticsProvider.notifier)
        .run(
          (c) async => (
            detail: await c.feedbackDetail(widget.feedback.id),
            replies: await c.feedbackReplies(widget.feedback.id),
          ),
        );
    final result = data.replies;
    if (result is! Map || result['rows'] is! List) {
      throw const FormatException('回复数据格式异常');
    }
    if (current) {
      latest = LogisticsFeedback(data.detail);
      final deadline = DateTime.tryParse(
        '${data.detail['allowDeleteTime'] ?? ''}',
      );
      deleteAllowed = deadline == null || deadline.isAfter(DateTime.now());
      replies = (result['rows'] as List)
          .where((e) => e['ifOfficial'] == 1 && '${e['status']}' != '2')
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
  });
  Future<void> remove() async {
    final reason = await showAppPromptDialog(
      context,
      title: '删除这条反馈',
      labelText: '删除原因',
      confirmLabel: '删除反馈',
      validator: (value) => value.trim().isEmpty ? '请填写删除原因' : null,
    );
    if (!current || reason == null) return;
    await perform(() async {
      await ref
          .read(logisticsProvider.notifier)
          .run((c) => c.deleteFeedback(widget.feedback.id, reason));
      if (mounted && current) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    watchIdentity();
    final f = latest ?? widget.feedback;
    return SubpageScaffold(
      title: '反馈详情',
      isBusy: () => busy,
      body: AppPageViewport(
        maxWidth: AppLayout.readingMaxWidth,
        builder: (context, insets) => ListView(
          padding: insets + EdgeInsets.all(AppSpace.pageXOf(context)),
          children: [
            Text(f.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpace.sm),
            Text(
              f.deleted ? '已删除' : '${f.type}\n${f.scope}',
              style: TextStyle(color: AppPalette.of(context).muted),
            ),
            const SizedBox(height: AppSpace.lg),
            SelectableText(f.content),
            const SizedBox(height: AppSpace.md),
            LogisticsImages(paths: f.images),
            if (replies.isNotEmpty)
              SettingsSection(
                header: '部门回复',
                hasLeading: false,
                children: [
                  for (final r in replies)
                    SettingsRow(
                      title: logisticsPlainText(r['replyUserName'] ?? '服务部门'),
                      subtitle: logisticsPlainText(r['content']),
                      subtitleWidget: Text('${r['createTime'] ?? ''}'),
                    ),
                ],
              ),
            if (busy) const Center(child: CircularProgressIndicator()),
            if (error != null) Text(error!),
            if (!f.deleted)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.lg),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AppButton(
                    label: '删除反馈',
                    kind: AppButtonKind.secondary,
                    busy: busy,
                    onPressed: deleteAllowed ? remove : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
