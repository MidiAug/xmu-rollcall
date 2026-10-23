import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _choice,
            isExpanded: true,
            borderRadius: BorderRadius.circular(12),
            dropdownColor: p.surface,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 13, color: p.ink),
            icon: const Icon(Icons.expand_more_rounded, size: 18),
            items: [
              const DropdownMenuItem(
                value: 'official',
                child: Text('GitHub 官方'),
              ),
              for (final route in UpdateDownloadRoute.suggested)
                DropdownMenuItem(
                  value: route,
                  child: Text(
                    Uri.parse(route).host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (customSaved)
                DropdownMenuItem(
                  value: _saved.toString(),
                  child: Text(_saved!.host, overflow: TextOverflow.ellipsis),
                ),
              const DropdownMenuItem(value: 'custom', child: Text('自定义线路…')),
            ],
            onChanged: !_ready || _saving || !widget.enabled
                ? null
                : (value) {
                    if (value == 'custom') {
                      setState(() {
                        _choice = value!;
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
        if (_saved != null)
          Text('第三方线路仅用于下载安装包', style: TextStyle(fontSize: 11, color: p.muted)),
      ],
    );
  }
}
