import 'package:flutter/material.dart';
import 'chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// Browse paths one level at a time, or search all leaves. The returned value
/// is the caller's original item, independent of its presentation path.
class AppHierarchyChoicePage<T> extends StatefulWidget {
  const AppHierarchyChoicePage({
    super.key,
    required this.title,
    required this.items,
    required this.pathOf,
    this.selected,
  });
  final String title;
  final List<T> items;
  final List<String> Function(T) pathOf;
  final T? selected;

  @override
  State<AppHierarchyChoicePage<T>> createState() =>
      _AppHierarchyChoicePageState<T>();
}

class _AppHierarchyChoicePageState<T> extends State<AppHierarchyChoicePage<T>> {
  final _search = TextEditingController();
  final _selectedRow = GlobalKey();
  final _scroll = ScrollController();
  List<String> path = [];
  String query = '';

  @override
  void initState() {
    super.initState();
    if (widget.selected != null) {
      final selectedPath = widget.pathOf(widget.selected as T);
      path = selectedPath.take(selectedPath.length - 1).toList();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final selectedContext = _selectedRow.currentContext;
        if (selectedContext != null) {
          Scrollable.ensureVisible(selectedContext, alignment: .3);
        }
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void navigate(List<String> next) {
    setState(() {
      path = next;
      query = '';
      _search.clear();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final searching = query.trim().isNotEmpty;
    final matches = widget.items.where((item) {
      final parts = widget.pathOf(item);
      if (searching) {
        return query
            .trim()
            .toLowerCase()
            .split(RegExp(r'\s+'))
            .every((term) => parts.join(' ').toLowerCase().contains(term));
      }
      return parts.length > path.length &&
          List.generate(
            path.length,
            (i) => parts[i] == path[i],
          ).every((same) => same);
    }).toList();
    final groups = <String, List<T>>{};
    if (!searching) {
      for (final item in matches) {
        groups
            .putIfAbsent(widget.pathOf(item)[path.length], () => [])
            .add(item);
      }
    }
    final rows = searching
        ? matches.map((item) {
            final parts = widget.pathOf(item);
            return SettingsRow(
              title: parts.last,
              subtitle: parts.length > 1
                  ? parts.take(parts.length - 1).join(' / ')
                  : null,
              trailing: item == widget.selected
                  ? const Icon(AppIcons.check)
                  : null,
              onTap: () => Navigator.of(context).pop(item),
            );
          }).toList()
        : groups.entries.map((group) {
            final item = group.value.first;
            final leaf = widget.pathOf(item).length == path.length + 1;
            return SettingsRow(
              key: leaf && item == widget.selected ? _selectedRow : null,
              title: group.key,
              trailing: leaf
                  ? item == widget.selected
                        ? const Icon(AppIcons.check)
                        : null
                  : const Icon(AppIcons.right, size: 14),
              onTap: () => leaf
                  ? Navigator.of(context).pop(item)
                  : navigate([...path, group.key]),
            );
          }).toList();
    return SubpageScaffold(
      title: widget.title,
      body: AppPageViewport(
        maxWidth: AppLayout.readingMaxWidth,
        builder: (context, insets) => Column(
          children: [
            Padding(
              padding:
                  insets +
                  EdgeInsets.fromLTRB(
                    AppSpace.pageXOf(context),
                    AppSpace.pageXOf(context),
                    AppSpace.pageXOf(context),
                    AppSpace.md,
                  ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSearchField(
                    controller: _search,
                    hintText: '搜索${widget.title}',
                    onChanged: (value) => setState(() => query = value),
                  ),
                  if (path.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.sm),
                    Wrap(
                      spacing: AppSpace.xs,
                      children: [
                        AppButton(
                          label: '全部',
                          compact: true,
                          kind: AppButtonKind.quiet,
                          onPressed: () => navigate([]),
                        ),
                        for (var i = 0; i < path.length; i++)
                          AppButton(
                            label: path[i],
                            compact: true,
                            kind: AppButtonKind.quiet,
                            onPressed: () =>
                                navigate(path.take(i + 1).toList()),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding:
                    insets +
                    EdgeInsets.fromLTRB(
                      AppSpace.pageXOf(context),
                      0,
                      AppSpace.pageXOf(context),
                      AppSpace.pageXOf(context),
                    ),
                children: [
                  if (rows.isEmpty)
                    const EmptyHint(icon: AppIcons.search, title: '没有匹配的选项')
                  else
                    SettingsSection(
                      padTop: false,
                      hasLeading: false,
                      children: rows,
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
