import 'package:file_selector/file_selector.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/browser/browser_session.dart';
import 'logistics_form_models.dart';
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

class LogisticsChoicePage extends StatefulWidget {
  const LogisticsChoicePage({
    super.key,
    required this.title,
    required this.choices,
  });
  final String title;
  final List<LogisticsChoice> choices;
  @override
  State<LogisticsChoicePage> createState() => _LogisticsChoicePageState();
}

class _LogisticsChoicePageState extends State<LogisticsChoicePage> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final choices = widget.choices
        .where(
          (x) => x.label.toLowerCase().contains(query.trim().toLowerCase()),
        )
        .toList();
    return SubpageScaffold(
      title: widget.title,
      body: AppPageViewport(
        maxWidth: AppLayout.workspaceMaxWidth,
        builder: (context, insets) => Column(
          children: [
            Padding(
              padding: insets + const EdgeInsets.all(AppSpace.md),
              child: AppSearchField(
                hintText: '搜索${widget.title}',
                onChanged: (v) => setState(() => query = v),
              ),
            ),
            Expanded(
              child: choices.isEmpty
                  ? const Center(child: Text('没有匹配的选项'))
                  : ListView.builder(
                      padding:
                          insets +
                          const EdgeInsets.symmetric(horizontal: AppSpace.md),
                      itemCount: choices.length,
                      itemBuilder: (context, i) => SettingsRow(
                        title: choices[i].label,
                        onTap: () => Navigator.of(context).pop(choices[i]),
                        trailing: const Icon(AppIcons.right, size: 14),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<LogisticsChoice?> chooseLogistics(
  BuildContext context,
  String title,
  List<LogisticsChoice> choices,
) => AppPageRoutes.push<LogisticsChoice>(
  context,
  LogisticsChoicePage(title: title, choices: choices),
);

class LogisticsFormField extends StatelessWidget {
  const LogisticsFormField({
    super.key,
    required this.label,
    required this.controller,
    this.lines = 1,
    this.limit,
    this.phone = false,
    this.optional = false,
    this.repairPhone = false,
  });
  final String label;
  final TextEditingController controller;
  final int lines;
  final int? limit;
  final bool phone, optional;
  final bool repairPhone;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.md),
    child: TextFormField(
      controller: controller,
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 2,
      maxLength: limit,
      keyboardType: phone
          ? TextInputType.phone
          : lines > 1
          ? TextInputType.multiline
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: lines > 1,
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (!optional && text.isEmpty) return '请填写$label';
        if (phone && text.isNotEmpty) {
          final valid = repairPhone
              ? RegExp(r'^(0|[1-9]\d{5,10})$').hasMatch(text)
              : text.length >= 5 &&
                    (text.length <= 10 ||
                        RegExp(
                          r'^(1[3-9]\d{9}|0[1-9]\d{6,13})$',
                        ).hasMatch(text));
          if (!valid) return '请填写正确的联系电话';
        }
        return null;
      },
    ),
  );
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
