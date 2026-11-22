import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xmu_rollcall/app/app_checkbox.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/app_service_symbol.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'ta_models.dart';

class TaCsvReviewDialog extends StatefulWidget {
  const TaCsvReviewDialog({
    super.key,
    required this.changes,
    required this.readRows,
    required this.readError,
    required this.isImporting,
    required this.isBatchRunning,
    required this.readOverwrite,
    required this.readAllowUnsubmitted,
    required this.onOverwriteChanged,
    required this.onAllowUnsubmittedChanged,
    required this.onImport,
    required this.onSubmit,
    required this.onStopBatch,
  });

  final Listenable changes;
  final List<TaGradeRow> Function() readRows;
  final String? Function() readError;
  final bool Function() isImporting;
  final bool Function() isBatchRunning;
  final bool Function() readOverwrite;
  final bool Function() readAllowUnsubmitted;
  final ValueChanged<bool> onOverwriteChanged;
  final ValueChanged<bool> onAllowUnsubmittedChanged;
  final VoidCallback onImport;
  final VoidCallback onSubmit;
  final VoidCallback onStopBatch;

  @override
  State<TaCsvReviewDialog> createState() => _TaCsvReviewDialogState();
}

class _TaCsvReviewDialogState extends State<TaCsvReviewDialog> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.changes,
      builder: (context, _) {
        final rows = widget.readRows();
        final csvError = widget.readError();
        final importing = widget.isImporting();
        final batchRunning = widget.isBatchRunning();
        final overwrite = widget.readOverwrite();
        final allowUnsubmitted = widget.readAllowUnsubmitted();
        final invalid = rows.where((r) => r.issue != null).length;
        final saved = rows.where((r) => r.status == TaRowStatus.saved).length;
        final canSubmit =
            !batchRunning &&
            !importing &&
            invalid == 0 &&
            !rows.any(
              (r) =>
                  r.status == TaRowStatus.uncertain ||
                  r.status == TaRowStatus.failed,
            ) &&
            rows.any((r) => r.status == TaRowStatus.ready);
        final palette = AppPalette.of(context);
        return PopScope(
          canPop: !batchRunning,
          child: AppDialogFrame(
            maxWidth: rows.isEmpty ? 480 : 720,
            insetPadding: const EdgeInsets.all(AppSpace.md),
            child: SizedBox(
              key: const ValueKey('ta-csv-content'),
              width: double.infinity,
              height: rows.isEmpty
                  ? null
                  : (324.0 + rows.length * 42).clamp(
                      300.0,
                      (MediaQuery.sizeOf(context).height * .82).clamp(
                        300.0,
                        620.0,
                      ),
                    ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            rows.isEmpty ? '导入成绩' : '核对成绩表',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        AppSheetCloseButton(
                          enabled: !batchRunning,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (csvError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          csvError,
                          style: TextStyle(color: palette.danger),
                        ),
                      ),
                    if (rows.isEmpty)
                      Flexible(
                        fit: FlexFit.loose,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: palette.controlSurface,
                                  border: Border.all(
                                    color: palette.controlRim,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.card,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    const AppServiceSymbol(
                                      icon: AppIcons.document,
                                      size: 44,
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      '选择包含学号和成绩的 CSV 文件',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: palette.ink,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              AppDisclosure(
                                title: 'CSV 格式与模板',
                                children: [
                                  const SelectableText(
                                    'user_no,score\nDEMO0001,86\nDEMO0002,90',
                                    style: TextStyle(height: 1.6),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '两列依次为学号、成绩。学号保留前导零，成绩范围为 0 至 100。',
                                    style: TextStyle(
                                      color: palette.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpace.sm),
                            ],
                          ),
                        ),
                      ),
                    if (rows.isNotEmpty) ...[
                      Text(
                        '共 ${rows.length} 行，错误 $invalid 行，已保存 $saved 行',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Scrollbar(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: 620,
                              child: Column(
                                children: [
                                  _csvRow(context, [
                                    '学号',
                                    '姓名',
                                    '新成绩',
                                    '处理结果',
                                  ], heading: true),
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: rows.length,
                                      itemBuilder: (_, i) {
                                        final row = rows[i];
                                        return _csvRow(
                                          context,
                                          [
                                            row.number,
                                            row.student?.name ?? '未匹配',
                                            row.score,
                                            row.issue ??
                                                row.result ??
                                                '待提交',
                                          ],
                                          error:
                                              row.issue != null ||
                                              row.status ==
                                                  TaRowStatus.failed ||
                                              row.status ==
                                                  TaRowStatus.uncertain,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      AppCheckboxRow(
                        label: '允许覆盖已有成绩',
                        value: overwrite,
                        onChanged: batchRunning ? null : widget.onOverwriteChanged,
                      ),
                      AppCheckboxRow(
                        label: '允许为未提交者评分',
                        value: allowUnsubmitted,
                        onChanged: batchRunning
                            ? null
                            : widget.onAllowUnsubmittedChanged,
                      ),
                      if (batchRunning)
                        const LinearProgressIndicator(minHeight: 2),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (batchRunning)
                          TextButton(
                            onPressed: widget.onStopBatch,
                            child: const Text('停止后续提交'),
                          ),
                        if (rows.isEmpty)
                          TextButton(
                            onPressed: () async {
                              await Clipboard.setData(
                                const ClipboardData(
                                  text:
                                      'user_no,score\nDEMO0001,86\nDEMO0002,90\n',
                                ),
                              );
                              if (mounted) {
                                setState(() => _copied = true);
                              }
                            },
                            child: Text(_copied ? '已复制模板' : '复制模板'),
                          ),
                        if (!batchRunning && rows.isEmpty)
                          AppButton(
                            label: importing ? '正在读取…' : '选择 CSV 文件',
                            icon: AppIcons.upload,
                            busy: importing,
                            onPressed: widget.onImport,
                          ),
                        if (!batchRunning && rows.isNotEmpty)
                          TextButton(
                            onPressed: importing ? null : widget.onImport,
                            child: Text(importing ? '正在读取…' : '更换文件'),
                          ),
                        if (rows.isNotEmpty)
                          AppButton(
                            label: '提交成绩',
                            icon: AppIcons.check,
                            onPressed: canSubmit ? widget.onSubmit : null,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Widget _csvRow(
  BuildContext context,
  List<String> cells, {
  bool heading = false,
  bool error = false,
}) {
  final p = AppPalette.of(context);
  return Container(
    constraints: const BoxConstraints(minHeight: 42),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: heading ? p.content : null,
      border: Border(bottom: BorderSide(color: p.border)),
    ),
    child: Row(
      children: [
        for (var i = 0; i < cells.length; i++)
          Expanded(
            flex: i == 3 ? 3 : 2,
            child: Text(
              cells[i],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: error ? p.danger : p.ink,
                fontWeight: heading ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
      ],
    ),
  );
}
