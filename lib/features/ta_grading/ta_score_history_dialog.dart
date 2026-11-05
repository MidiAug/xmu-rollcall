import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'ta_models.dart';
import 'ta_repository.dart';

class TaScoreHistoryDialog extends StatefulWidget {
  const TaScoreHistoryDialog({
    super.key,
    required this.repository,
    required this.activityId,
    required this.student,
  });
  final TaGradingRepository repository;
  final int activityId;
  final TaStudent student;
  @override
  State<TaScoreHistoryDialog> createState() => _TaScoreHistoryDialogState();
}

class _TaScoreHistoryDialogState extends State<TaScoreHistoryDialog> {
  late final _repository = widget.repository.fork();
  late Future<List<TaScoreRecord>> _records = _read();
  Future<List<TaScoreRecord>> _read() =>
      _repository.scoreRecords(widget.activityId, widget.student.id);
  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  String _score(double? value) => value == null
      ? '未评分'
      : value.toString().replaceFirst(RegExp(r'\.0$'), '');

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    if (!_repository.active) {
      return AppNoticeDialog(
        title: '当前页面已失效',
        message: '请返回后重新打开作业',
        onClose: () => Navigator.pop(context),
      );
    }
    return AppDialogFrame(
      maxWidth: 560,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '评分记录',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                AppSheetCloseButton(onPressed: () => Navigator.pop(context)),
              ],
            ),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  widget.student.name,
                  style: TextStyle(color: p.ink, fontWeight: FontWeight.w500),
                ),
                Text(
                  widget.student.number,
                  style: TextStyle(color: p.muted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FutureBuilder<List<TaScoreRecord>>(
              future: _records,
              builder: (context, snapshot) {
                final limit = (MediaQuery.sizeOf(context).height * .5).clamp(
                  180.0,
                  360.0,
                );
                Widget area(Widget child, {double height = 180}) =>
                    SizedBox(height: height.clamp(96.0, limit), child: child);
                if (!_repository.active) {
                  return area(const Center(child: Text('当前页面已失效')));
                }
                if (snapshot.hasError) {
                  return area(
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('评分记录加载失败'),
                          const SizedBox(height: 12),
                          AppButton(
                            label: '重试',
                            kind: AppButtonKind.secondary,
                            onPressed: () {
                              final pending = _read();
                              setState(() {
                                _records = pending;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return area(const Center(child: CircularProgressIndicator()));
                }
                final records = snapshot.requireData;
                if (records.isEmpty) {
                  return area(
                    Center(
                      child: Text('暂无评分记录', style: TextStyle(color: p.muted)),
                    ),
                    height: 96,
                  );
                }
                return area(
                  ListView.separated(
                    itemCount: records.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: p.border),
                    itemBuilder: (context, index) {
                      final record = records[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  _score(record.oldScore),
                                  style: TextStyle(
                                    color: p.muted,
                                    fontSize: 16,
                                  ),
                                ),
                                Icon(AppIcons.right, color: p.muted, size: 13),
                                Text(
                                  _score(record.score),
                                  style: TextStyle(
                                    color: p.ink,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 16,
                              runSpacing: 4,
                              children: [
                                Text(
                                  record.createdAt
                                      .toLocal()
                                      .toString()
                                      .substring(0, 16),
                                  style: TextStyle(
                                    color: p.muted,
                                    fontSize: 12,
                                  ),
                                ),
                                if (record.operatorName.isNotEmpty)
                                  Text(
                                    record.operatorName,
                                    style: TextStyle(
                                      color: p.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  height:
                      records.length *
                      MediaQuery.textScalerOf(context).scale(96),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
