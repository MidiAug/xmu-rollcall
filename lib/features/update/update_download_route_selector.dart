import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/update/update_download_route.dart';

/// Saves a selection in place; custom nodes use an inline editor.
class UpdateDownloadRouteSelector extends StatefulWidget {
  const UpdateDownloadRouteSelector({
    super.key,
    this.onChanged,
    this.enabled = true,
  });
  final Future<void> Function()? onChanged;
  final bool enabled;

  @override
  State<UpdateDownloadRouteSelector> createState() => _RouteSelectorState();
}

class _RouteSelectorState extends State<UpdateDownloadRouteSelector> {
  final _custom = TextEditingController();
  String _choice = 'official';
  Uri? _saved;
  bool _ready = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final route = await UpdateDownloadRoute.read();
    if (!mounted) return;
    setState(() {
      _saved = route;
      _choice = route?.toString() ?? 'official';
      _custom.text = route?.toString() ?? '';
      _ready = true;
    });
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
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
    final customSaved =
        _saved != null &&
        !UpdateDownloadRoute.suggested.contains(_saved.toString());
    return Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 164),
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
                width: bounds.maxWidth.clamp(0.0, 164.0),
                menuWidth: 260,
                onChanged: !_ready || _saving || !widget.enabled
                    ? null
                    : (value) {
                        if (value == 'custom') {
                          setState(() {
                            _choice = value;
                            _error = null;
                          });
                        } else {
                          _save(value == 'official' ? null : value);
                        }
                      },
              ),
            ),
            if (_choice == 'custom')
              TextField(
                controller: _custom,
                enabled: !_saving && widget.enabled,
                keyboardType: TextInputType.url,
                onSubmitted: _save,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'https://mirror.example/',
                  errorText: _error,
                  errorMaxLines: 3,
                  suffixIcon: IconButton(
                    tooltip: '应用线路',
                    onPressed: _saving ? null : () => _save(_custom.text),
                    icon: const Icon(Icons.check_rounded, size: 18),
                  ),
                ),
              )
            else if (_error != null)
              Text(_error!, style: TextStyle(fontSize: 12, color: p.danger)),
          ],
        ),
      ),
    );
  }
}
