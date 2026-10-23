import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/update/update_download_route.dart';

/// Saves preset choices directly; custom nodes use a validated text prompt.
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
  bool _editing = false;
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

  Future<void> _editCustom() async {
    if (_editing || _saving) return;
    setState(() => _editing = true);
    try {
      final value = await showAppPromptDialog(
        context,
        title: '自定义下载线路',
        message: '输入 HTTPS 加速节点首页',
        initialValue:
            _saved != null &&
                !UpdateDownloadRoute.suggested.contains(_saved.toString())
            ? _saved.toString()
            : '',
        labelText: '节点地址',
        hintText: 'https://mirror.example/',
        keyboardType: TextInputType.url,
        validator: (value) {
          try {
            UpdateDownloadRoute.parse(value);
            return null;
          } on FormatException catch (error) {
            return error.message;
          }
        },
      );
      if (mounted && value != null) await _save(value);
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final customSaved =
        _saved != null &&
        !UpdateDownloadRoute.suggested.contains(_saved.toString());
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
                items: [
                  'official',
                  ...UpdateDownloadRoute.suggested,
                  if (customSaved) _saved.toString(),
                  'custom',
                ],
                labelOf: (value) => value == 'official'
                    ? 'GitHub 官方'
                    : value == 'custom'
                    ? '自定义线路…'
                    : Uri.parse(value).host,
                menuTrailingOf: (value) => value == 'official'
                    ? '直连'
                    : value == 'custom'
                    ? ''
                    : '加速',
                semanticLabel: '更新下载线路',
                compact: true,
                leading: bounds.maxWidth < 164
                    ? null
                    : Icon(Icons.alt_route_rounded, size: 16, color: p.muted),
                width: bounds.maxWidth.clamp(0.0, widget.width),
                menuWidth: 260,
                onChanged: !_ready || _saving || _editing || !widget.enabled
                    ? null
                    : (value) {
                        if (value == 'custom') {
                          _editCustom();
                        } else {
                          _save(value == 'official' ? null : value);
                        }
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
