import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'campus_card_providers.dart';
import 'campus_card_page_session.dart';

class CampusCardRecordsPage extends ConsumerStatefulWidget {
  const CampusCardRecordsPage({super.key, required this.kind});
  final CardRecordKind kind;
  @override
  ConsumerState<CampusCardRecordsPage> createState() =>
      _CampusCardRecordsPageState();
}

class _CampusCardRecordsPageState extends ConsumerState<CampusCardRecordsPage>
    with CampusCardPageSession<CampusCardRecordsPage> {
  final rows = <CardRecord>[];
  int? nextPage = 1;
  bool loaded = false;
  String get title => switch (widget.kind) {
    CardRecordKind.transactions => '使用记录',
    CardRecordKind.bills => '全部账单',
    CardRecordKind.rice => '免费米饭账单',
  };
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load({bool more = false}) => perform(() async {
    final result = await ref
        .read(campusCardInfoProvider.notifier)
        .run((client) => client.records(widget.kind, more ? nextPage! : 1));
    if (!current) return;
    if (!more) rows.clear();
    rows.addAll(result.rows);
    nextPage = result.nextPage;
    loaded = true;
  });
  @override
  Widget build(BuildContext context) {
    watchSession();
    final groups = <String, List<CardRecord>>{};
    for (final row in rows) {
      groups.putIfAbsent(row.day, () => []).add(row);
    }
    return SubpageScaffold(
      title: title,
      actions: [AppRefreshButton(busy: busy, onRefresh: load)],
      body: AppPageViewport(
        maxWidth: AppLayout.readingMaxWidth,
        builder: (context, insets) => ListView(
          padding: insets + EdgeInsets.all(AppSpace.pageXOf(context)),
          children: [
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.md),
                child: Text(error!),
              ),
            if (!loaded && busy)
              const Center(child: CircularProgressIndicator()),
            if (loaded && rows.isEmpty)
              const EmptyHint(icon: AppIcons.history, title: '暂无记录'),
            for (final group in groups.entries)
              SettingsSection(
                header: group.key,
                padTop: group.key != groups.keys.first,
                hasLeading: false,
                children: [
                  for (final row in group.value)
                    SettingsRow(
                      title: row.title.isEmpty ? row.kind : row.title,
                      truncateTitle: true,
                      subtitle: row.clock,
                      trailing: Text('¥${row.amount.toStringAsFixed(2)}'),
                      onTap: () => AppPageRoutes.push<void>(
                        context,
                        CampusCardRecordPage(record: row),
                      ),
                    ),
                ],
              ),
            if (loaded && nextPage != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.md),
                child: AppButton(
                  label: '加载更多',
                  kind: AppButtonKind.quiet,
                  busy: busy,
                  onPressed: () => load(more: true),
                ),
              ),
            if (!busy && error != null && rows.isEmpty)
              AppButton(label: '重试', onPressed: load),
          ],
        ),
      ),
    );
  }
}

class CampusCardRecordPage extends ConsumerStatefulWidget {
  const CampusCardRecordPage({super.key, required this.record});
  final CardRecord record;
  @override
  ConsumerState<CampusCardRecordPage> createState() =>
      _CampusCardRecordPageState();
}

class _CampusCardRecordPageState extends ConsumerState<CampusCardRecordPage>
    with CampusCardPageSession<CampusCardRecordPage> {
  @override
  Widget build(BuildContext context) {
    watchSession();
    final row = widget.record;
    return SubpageScaffold(
      title: '交易详情',
      body: AppPageViewport(
        maxWidth: AppLayout.readingMaxWidth,
        builder: (context, insets) => ListView(
          padding: insets + EdgeInsets.all(AppSpace.pageXOf(context)),
          children: [
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.title.isEmpty ? row.kind : row.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpace.md),
                  Text(
                    '¥${row.amount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    row.time,
                    style: TextStyle(color: AppPalette.of(context).muted),
                  ),
                ],
              ),
            ),
            SettingsSection(
              hasLeading: false,
              children: [
                if (row.kind.isNotEmpty)
                  SettingsRow(title: '交易类型', subtitle: row.kind),
                if (row.balance != null)
                  SettingsRow(
                    title: '交易后余额',
                    trailing: Text('¥${row.balance!.toStringAsFixed(2)}'),
                  ),
                if (row.note.isNotEmpty &&
                    row.note != row.title &&
                    row.note != row.kind)
                  SettingsRow(title: '备注', subtitle: row.note),
                if (row.number.isNotEmpty)
                  AppDisclosure(
                    title: '交易编号',
                    children: [SelectableText(row.number)],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CampusCardBillsPage extends ConsumerStatefulWidget {
  const CampusCardBillsPage({super.key});
  @override
  ConsumerState<CampusCardBillsPage> createState() =>
      _CampusCardBillsPageState();
}

class _CampusCardBillsPageState extends ConsumerState<CampusCardBillsPage>
    with CampusCardPageSession<CampusCardBillsPage> {
  late final months = List.generate(24, (i) {
    final d = DateTime(DateTime.now().year, DateTime.now().month - i);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  });
  late String month = months.first;
  List<CardBillCategory>? categories;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() => perform(() async {
    final selected = month;
    final result = await ref
        .read(campusCardInfoProvider.notifier)
        .run((c) => c.billCategories(selected));
    if (current && month == selected) categories = result;
  });
  @override
  Widget build(BuildContext context) {
    watchSession();
    return SubpageScaffold(
      title: '我的账单',
      actions: [AppRefreshButton(busy: busy, onRefresh: load)],
      body: AppPageViewport(
        maxWidth: AppLayout.readingMaxWidth,
        builder: (context, insets) => ListView(
          padding: insets + EdgeInsets.all(AppSpace.pageXOf(context)),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: AppShellSelect<String>(
                value: month,
                items: months,
                labelOf: (v) => v,
                onChanged: busy
                    ? null
                    : (v) {
                        setState(() {
                          month = v;
                          categories = null;
                        });
                        unawaited(load());
                      },
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            if (busy) const Center(child: CircularProgressIndicator()),
            if (error != null) Text(error!),
            if (categories != null && categories!.isEmpty)
              const EmptyHint(icon: AppIcons.document, title: '本月暂无账单'),
            if (categories?.isNotEmpty == true) ...[
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '本月合计',
                      style: TextStyle(color: AppPalette.of(context).muted),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      '¥${categories!.fold<double>(0, (sum, r) => sum + r.amount).toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
              ),
              SettingsSection(
                header: '分类',
                hasLeading: false,
                children: [
                  for (final category in categories!)
                    SettingsRow(
                      title: category.name,
                      trailing: Text('¥${category.amount.toStringAsFixed(2)}'),
                      onTap: () => AppPageRoutes.push<void>(
                        context,
                        CampusCardCategoryPage(
                          month: month,
                          category: category,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            SettingsSection(
              hasLeading: false,
              children: [
                SettingsRow(
                  title: '全部账单',
                  trailing: const Icon(AppIcons.right, size: 14),
                  onTap: () => AppPageRoutes.push<void>(
                    context,
                    const CampusCardRecordsPage(kind: CardRecordKind.bills),
                  ),
                ),
              ],
            ),
            if (error != null && !busy) AppButton(label: '重试', onPressed: load),
          ],
        ),
      ),
    );
  }
}

class CampusCardCategoryPage extends ConsumerStatefulWidget {
  const CampusCardCategoryPage({
    super.key,
    required this.month,
    required this.category,
  });
  final String month;
  final CardBillCategory category;
  @override
  ConsumerState<CampusCardCategoryPage> createState() =>
      _CampusCardCategoryPageState();
}

class _CampusCardCategoryPageState extends ConsumerState<CampusCardCategoryPage>
    with CampusCardPageSession<CampusCardCategoryPage> {
  List<CardRecord>? rows;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() => perform(() async {
    final result = await ref
        .read(campusCardInfoProvider.notifier)
        .run((c) => c.categoryRecords(widget.month, widget.category.code));
    if (current) rows = result;
  });
  @override
  Widget build(BuildContext context) {
    watchSession();
    return SubpageScaffold(
      title: widget.category.name,
      actions: [AppRefreshButton(busy: busy, onRefresh: load)],
      body: AppPageViewport(
        maxWidth: AppLayout.readingMaxWidth,
        builder: (context, insets) => ListView(
          padding: insets + EdgeInsets.all(AppSpace.pageXOf(context)),
          children: [
            Text(
              widget.month,
              style: TextStyle(color: AppPalette.of(context).muted),
            ),
            const SizedBox(height: AppSpace.md),
            if (busy) const Center(child: CircularProgressIndicator()),
            if (error != null) Text(error!),
            if (rows?.isEmpty == true)
              const EmptyHint(icon: AppIcons.document, title: '暂无记录'),
            if (rows?.isNotEmpty == true)
              SettingsSection(
                padTop: false,
                hasLeading: false,
                children: [
                  for (final row in rows!)
                    SettingsRow(
                      title: row.title.isEmpty ? row.kind : row.title,
                      subtitle: row.time,
                      trailing: Text('¥${row.amount.toStringAsFixed(2)}'),
                      onTap: () => AppPageRoutes.push<void>(
                        context,
                        CampusCardRecordPage(record: row),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
