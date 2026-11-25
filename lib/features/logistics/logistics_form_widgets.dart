import 'package:file_selector/file_selector.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/browser/browser_session.dart';
import 'logistics_provider.dart';

/// Forms and nested records share the same identity lifetime as their requests.
mixin LogisticsIdentityPage<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  bool busy = false;
  String? error;
  late final BrowserIdentity identity;
  @override
  void initState() {
    super.initState();
    identity = ref.read(browserIdentityProvider);
  }

  bool get current => mounted && ref.read(browserIdentityProvider) == identity;
  void watchIdentity() {
    // Keep the shared session alive even when this native subpage is mounted
    // directly, without the module overview underneath it.
    ref.watch(logisticsProvider);
    ref.listen(browserIdentityProvider, (_, next) {
      if (next == identity) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final route = ModalRoute.of(context);
        if (route != null && route.isActive) {
          Navigator.of(context).removeRoute(route);
        }
      });
    });
  }

  Future<void> perform(Future<void> Function() action) async {
    if (busy || !current) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (current) {
        setState(
          () => error = e is FormatException ? e.message : '操作未完成，请检查网络后重试',
        );
      }
    } finally {
      if (current) setState(() => busy = false);
    }
  }
}

class LogisticsAttachment {
  const LogisticsAttachment(this.name, this.path, this.image);
  final String name, path;
  final bool image;
  Map<String, dynamic> toRepairJson() => {
    'fileUrl': path,
    'fileType': image ? '1' : '3',
    'statusType': '1',
  };
}

class LogisticsAttachments extends ConsumerStatefulWidget {
  const LogisticsAttachments({
    super.key,
    required this.files,
    required this.onChanged,
    this.enabled = true,
    this.imagesOnly = false,
    this.onBusyChanged,
  });
  final List<LogisticsAttachment> files;
  final ValueChanged<List<LogisticsAttachment>> onChanged;
  final bool enabled;
  final bool imagesOnly;
  final ValueChanged<bool>? onBusyChanged;
  @override
  ConsumerState<LogisticsAttachments> createState() =>
      _LogisticsAttachmentsState();
}

class _LogisticsAttachmentsState extends ConsumerState<LogisticsAttachments>
    with LogisticsIdentityPage<LogisticsAttachments> {
  Future<void> pick() async {
    widget.onBusyChanged?.call(true);
    try {
      await perform(() async {
        final picked = await openFiles(
          acceptedTypeGroups: [
            XTypeGroup(
              label: widget.imagesOnly ? '图片' : '图片或视频',
              extensions: widget.imagesOnly
                  ? ['jpg', 'jpeg', 'png', 'gif']
                  : [
                      'jpg',
                      'jpeg',
                      'png',
                      'gif',
                      'mp4',
                      'mov',
                      'avi',
                      'ts',
                      'rmvb',
                    ],
            ),
          ],
        );
        if (!current || picked.isEmpty) return;
        if (picked.length + widget.files.length > 3) {
          throw const FormatException('最多添加3个附件');
        }
        final files = [...widget.files];
        for (final file in picked) {
          final length = await file.length();
          if (!current) return;
          final path = await ref
              .read(logisticsProvider.notifier)
              .run(
                (client) => client.upload(
                  openRead: file.openRead,
                  length: length,
                  name: file.name,
                ),
              );
          if (!current) return;
          files.add(
            LogisticsAttachment(
              file.name,
              path,
              RegExp(
                r'\.(jpg|jpeg|png|gif)$',
                caseSensitive: false,
              ).hasMatch(file.name),
            ),
          );
          widget.onChanged(List.of(files));
        }
      });
    } finally {
      if (current) widget.onBusyChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    watchIdentity();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final file in widget.files)
          SettingsRow(
            title: file.name,
            truncateTitle: true,
            trailing: AppIconButton(
              tooltip: '移除附件',
              icon: const Icon(AppIcons.close),
              onPressed: widget.enabled && !busy
                  ? () => widget.onChanged(
                      widget.files.where((x) => x != file).toList(),
                    )
                  : null,
            ),
          ),
        if (widget.files.length < 3)
          AppButton(
            label: widget.imagesOnly ? '添加图片' : '添加图片或视频',
            kind: AppButtonKind.secondary,
            busy: busy,
            onPressed: widget.enabled ? pick : null,
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.sm),
            child: Text(error!),
          ),
      ],
    );
  }
}

Uri? logisticsMediaUrl(String path) {
  final uri = Uri.tryParse(
    path.startsWith('https://')
        ? path
        : 'https://xdhq.xmu.edu.cn/fileupload/${path.replaceFirst(RegExp(r'^/'), '')}',
  );
  return uri != null &&
          uri.scheme == 'https' &&
          uri.host == 'xdhq.xmu.edu.cn' &&
          uri.path.startsWith('/fileupload/')
      ? uri
      : null;
}

class LogisticsImages extends ConsumerWidget {
  const LogisticsImages({super.key, required this.paths});
  final List<String> paths;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Wrap(
    spacing: AppSpace.sm,
    runSpacing: AppSpace.sm,
    children: [
      for (final path in paths)
        if (logisticsMediaUrl(path) case final uri?)
          if (RegExp(
            r'\.(png|jpe?g|gif)$',
            caseSensitive: false,
          ).hasMatch(uri.path))
            AppHoverSurface(
              onTap: () => showDialog<void>(
                context: context,
                builder: (context) => AppDialogFrame(
                  child: SizedBox(
                    height: MediaQuery.sizeOf(context).height * .7,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: InteractiveViewer(
                            child: Image.network(
                              uri.toString(),
                              errorBuilder: (_, _, _) => const Text('图片未能加载'),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: AppSheetCloseButton(
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.input),
                child: Image.network(
                  uri.toString(),
                  width: 120,
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(
                    width: 120,
                    height: 90,
                    child: Center(child: Text('图片未能加载')),
                  ),
                ),
              ),
            )
          else
            AppButton(
              label: '保存附件',
              kind: AppButtonKind.secondary,
              onPressed: () async {
                try {
                  final location = await getSaveLocation(
                    suggestedName: uri.pathSegments.last,
                  );
                  if (!context.mounted || location == null) return;
                  final bytes = await ref
                      .read(logisticsProvider.notifier)
                      .run((c) => c.attachment(uri));
                  if (!context.mounted) return;
                  await XFile.fromData(
                    Uint8List.fromList(bytes),
                    name: uri.pathSegments.last,
                  ).saveTo(location.path);
                  if (context.mounted) AppToast.show(context, '附件已保存');
                } catch (_) {
                  if (context.mounted) AppToast.show(context, '附件未能保存，请稍后重试');
                }
              },
            ),
    ],
  );
}
