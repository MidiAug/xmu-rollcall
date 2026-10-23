import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/update/update_download_route.dart';

/// Shared, preset-only download route selector for About and release notes.
class UpdateDownloadRouteSelector extends StatefulWidget {
  const UpdateDownloadRouteSelector({
    super.key,
    this.onChanged,
    this.enabled = true,
    this.width = 164,
  });
  final Future<void> Function()? onChanged;
  final bool enabled;
  final double width;

  @override
  State<UpdateDownloadRouteSelector> createState() => _RouteSelectorState();
}

class _RouteSelectorState extends State<UpdateDownloadRouteSelector> {
  // About and release notes can both show a selector at the same time.
  static final _routeRevision = ValueNotifier<int>(0);
  String _choice = 'official';
  Uri? _saved;
  bool _ready = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _routeRevision.addListener(_load);
    _load();
  }

  Future<void> _load() async {
    final route = await UpdateDownloadRoute.read();
    if (!mounted) return;
    setState(() {
      _saved = route;
      _choice = route?.toString() ?? 'official';
      _ready = true;
    });
  }

  @override
  void dispose() {
    _routeRevision.removeListener(_load);
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();
    _routeRevision.removeListener(_load);
    _routeRevision.addListener(_load);
    _load();
  }

  Future<void> _save(String? value) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final route = value == null ? null : UpdateDownloadRoute.parse(value);
      if (route != _saved) {
        await UpdateDownloadRoute.save(route?.toString());
        if (!mounted) return;
        setState(() {
          _saved = route;
          _choice = route?.toString() ?? 'official';
        });
        _routeRevision.value++;
        await widget.onChanged?.call();
        if (mounted) AppToast.show(context, '下载线路已切换');
      } else {
        setState(() => _choice = route?.toString() ?? 'official');
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = '保存失败，请重试');
        AppToast.show(context, '下载线路保存失败', error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Align(
      alignment: Alignment.centerRight,
      widthFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.width),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, bounds) => AppShellSelect<String>(
                key: const ValueKey('update-route-select'),
                value: _choice,
                items: ['official', ...UpdateDownloadRoute.suggested],
                labelOf: (value) =>
                    value == 'official' ? 'GitHub 官方' : Uri.parse(value).host,
                menuTrailingOf: (value) => value == 'official' ? '直连' : '加速',
                semanticLabel: '更新下载线路',
                compact: true,
                leading: bounds.maxWidth < 164
                    ? null
                    : Icon(Icons.alt_route_rounded, size: 16, color: p.muted),
                width: bounds.maxWidth.clamp(0.0, widget.width),
                menuWidth: 260,
                onChanged: !_ready || _saving || !widget.enabled
                    ? null
                    : (value) {
                        _save(value == 'official' ? null : value);
                      },
              ),
            ),
            if (_error != null)
              Text(_error!, style: TextStyle(fontSize: 12, color: p.danger)),
          ],
        ),
      ),
    );
  }
}
