import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/features/update/update_download_route.dart';

Future<bool> showUpdateDownloadRouteDialog(
  BuildContext context, {
  bool restarting = false,
}) async {
  final selected = await UpdateDownloadRoute.read();
  if (!context.mounted) return false;
  return await showDialog<bool>(
        context: context,
        builder: (_) => _RouteDialog(initial: selected, restarting: restarting),
      ) ??
      false;
}

class _RouteDialog extends StatefulWidget {
  const _RouteDialog({this.initial, this.restarting = false});
  final Uri? initial;
  final bool restarting;
  @override
  State<_RouteDialog> createState() => _RouteDialogState();
}

class _RouteDialogState extends State<_RouteDialog> {
  late String _choice = widget.initial == null
      ? 'official'
      : UpdateDownloadRoute.suggested.contains(widget.initial.toString())
      ? widget.initial.toString()
      : 'custom';
  late final _custom = TextEditingController(
    text: _choice == 'custom' ? widget.initial.toString() : '',
  );
  String? _error;
  bool _saving = false;
  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await UpdateDownloadRoute.save(
        _choice == 'official'
            ? null
            : _choice == 'custom'
            ? _custom.text
            : _choice,
      );
      if (mounted) Navigator.pop(context, true);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '保存失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('更新下载线路'),
    content: SizedBox(
      width: 380,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('仅加速安装包，版本与校验仍来自 GitHub。第三方只收到公开文件地址。'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _choice,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '下载线路'),
              items: [
                const DropdownMenuItem(
                  value: 'official',
                  child: Text('GitHub 官方'),
                ),
                for (final value in UpdateDownloadRoute.suggested)
                  DropdownMenuItem(
                    value: value,
                    child: Text(Uri.parse(value).host),
                  ),
                const DropdownMenuItem(
                  value: 'custom',
                  child: Text('其他 HTTPS 节点'),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                      _choice = value!;
                      _error = null;
                    }),
            ),
            if (_choice == 'custom') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _custom,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: '节点首页',
                  hintText: 'https://ghproxy.net/',
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            TextButton(
              onPressed: () async {
                try {
                  if (!await launchUrl(
                    Uri.parse('https://github.akams.cn/'),
                    mode: LaunchMode.externalApplication,
                  )) {
                    throw StateError('launch');
                  }
                } catch (_) {
                  if (context.mounted) {
                    AppToast.show(
                      context,
                      '无法打开节点目录，请在浏览器访问 github.akams.cn',
                      error: true,
                    );
                  }
                }
              },
              child: const Text('查看 GitHub Proxy 节点目录'),
            ),
            const Text('节点失败时尝试官方地址；安装前校验 SHA-256。'),
            if (widget.restarting) const Text('保存后从新线路重新下载，已完成的部分会清除。'),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _saving ? null : _save, child: const Text('保存')),
    ],
  );
}
