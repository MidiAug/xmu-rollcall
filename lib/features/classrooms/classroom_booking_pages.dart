import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_checkbox.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'classroom_providers.dart';
import 'classroom_page_session.dart';

class ClassroomSeatBookingPage extends ConsumerStatefulWidget {
  const ClassroomSeatBookingPage({super.key, required this.room});
  final SeatRoom room;
  @override
  ConsumerState<ClassroomSeatBookingPage> createState() => _SeatBookingState();
}

class _SeatBookingState extends ConsumerState<ClassroomSeatBookingPage>
    with ClassroomPageSession<ClassroomSeatBookingPage> {
  SeatRules? rules;
  List<ClassroomDateStatus> dates = [];
  List<SeatTimeRange> ranges = [];
  List<ClassroomSeat> seats = [];
  String? date, start, end;
  ClassroomSeat? selected;
  bool agreed = false, uncertain = false;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() => perform(() async {
    final r = await ref
        .read(classroomProvider.notifier)
        .run((c) => c.seatRules(widget.room.id));
    if (!current) return;
    rules = r;
    final ds = await ref
        .read(classroomProvider.notifier)
        .run((c) => c.seatDates(widget.room.id, r.days));
    if (!current) return;
    dates = ds.where((v) => v.status == 1).toList();
    date = dates.firstOrNull?.date;
    if (date != null) await loadTimes();
  });
  List<String> get starts {
    final values = <String>[];
    for (final range in ranges) {
      var t = _minute(range.start);
      final last = _minute(range.end);
      for (; t < last; t += 15) {
        final value = _clock(t);
        if (date == classroomDate(DateTime.now()) &&
            t < DateTime.now().hour * 60 + DateTime.now().minute) {
          continue;
        }
        values.add(value);
      }
    }
    return values;
  }

  List<String> get ends {
    if (start == null) return [];
    final min = rules?.minimum ?? 0;
    final max = rules?.maximum ?? 0;
    final from = _minute(start!);
    final range = ranges
        .where((r) => from >= _minute(r.start) && from < _minute(r.end))
        .firstOrNull;
    if (range == null) return [];
    return [
      for (
        var t = from + (min > 0 ? min : 15);
        t <= _minute(range.end) && (max <= 0 || t - from <= max);
        t += 15
      )
        _clock(t),
    ];
  }

  Future<void> loadTimes() async {
    final result = await ref
        .read(classroomProvider.notifier)
        .run((c) => c.seatTimes(widget.room.id, date!));
    if (!current) return;
    ranges = result;
    start = starts.firstOrNull;
    end = ends.firstOrNull;
    selected = null;
    seats = [];
    if (start != null && end != null) await loadSeats();
  }

  Future<void> loadSeats() async {
    if (date == null || start == null || end == null) return;
    final result = await ref
        .read(classroomProvider.notifier)
        .run((c) => c.seats(widget.room.id, date!, start!, end!));
    if (current) {
      seats = result;
      selected = null;
    }
  }

  Future<void> submit() async {
    if (selected == null || uncertain || busy || !current) return;
    if (rules!.promise.isNotEmpty && !agreed) {
      setState(() => error = '请阅读并同意使用承诺');
      return;
    }
    final seat = selected!;
    final confirmed = await showAppConfirmDialog(
      context,
      title: '确认预约？',
      message:
          '${widget.room.name} ${seat.name}\n$date\n$start—$end\n请按学校规则完成现场签到。',
      confirmLabel: '确认预约',
    );
    if (!mounted || !current || !confirmed) return;
    await perform(() async {
      try {
        await ref
            .read(classroomProvider.notifier)
            .run(
              (c) => c.bookSeat(widget.room.id, seat.id, date!, start!, end!),
            );
        if (mounted && current) Navigator.of(context).pop(true);
      } on ClassroomWriteUncertain {
        uncertain = true;
        rethrow;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    watchSession();
    return SubpageScaffold(
      title: widget.room.name,
      isBusy: () => busy,
      body: AppPageViewport(
        maxWidth: AppLayout.readingMaxWidth,
        builder: (context, insets) => ListView(
          padding: insets + EdgeInsets.all(AppSpace.pageXOf(context)),
          children: [
            if (busy) const Center(child: CircularProgressIndicator()),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.md),
                child: Text(error!),
              ),
            if (rules == null && !busy) AppButton(label: '重试', onPressed: load),
            if (rules != null) ...[
              if (rules!.notice.isNotEmpty) Panel(child: Text(rules!.notice)),
              const SizedBox(height: AppSpace.md),
              if (!rules!.open || dates.isEmpty)
                const EmptyHint(icon: AppIcons.calendar, title: '暂无可预约日期')
              else ...[
                SettingsSection(
                  padTop: false,
                  hasLeading: false,
                  children: [
                    if (date != null)
                      SettingsRow(
                        title: '预约日期',
                        trailing: AppShellSelect<String>(
                          value: date!,
                          items: dates.map((v) => v.date).toList(),
                          labelOf: (v) => v,
                          onChanged: busy || uncertain
                              ? null
                              : (v) {
                                  setState(() => date = v);
                                  unawaited(perform(loadTimes));
                                },
                        ),
                      ),
                    if (start != null)
                      SettingsRow(
                        title: '开始时间',
                        trailing: AppShellSelect<String>(
                          value: start!,
                          items: starts,
                          labelOf: (v) => v,
                          onChanged: busy || uncertain
                              ? null
                              : (v) {
                                  setState(() {
                                    start = v;
                                    end = ends.firstOrNull;
                                  });
                                  unawaited(perform(loadSeats));
                                },
                        ),
                      ),
                    if (end != null)
                      SettingsRow(
                        title: '结束时间',
                        trailing: AppShellSelect<String>(
                          value: end!,
                          items: ends,
                          labelOf: (v) => v,
                          onChanged: busy || uncertain
                              ? null
                              : (v) {
                                  setState(() => end = v);
                                  unawaited(perform(loadSeats));
                                },
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.lg),
                if (seats.isEmpty && !busy)
                  const EmptyHint(icon: AppIcons.people, title: '该时段暂无可用座位'),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: [
                    for (final seat in seats)
                      AppButton(
                        label: seat.name,
                        compact: true,
                        kind: selected?.id == seat.id
                            ? AppButtonKind.primary
                            : AppButtonKind.secondary,
                        onPressed: busy || uncertain || seat.status != 1
                            ? null
                            : () => setState(() => selected = seat),
                      ),
                  ],
                ),
                if (rules!.promise.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.lg),
                  AppDisclosure(
                    title: '使用承诺',
                    children: [Text(rules!.promise)],
                  ),
                  AppCheckboxRow(
                    label: '已阅读并同意使用承诺',
                    value: agreed,
                    onChanged: busy || uncertain
                        ? null
                        : (v) => setState(() => agreed = v),
                  ),
                ],
                const SizedBox(height: AppSpace.lg),
                AppButton(
                  label: uncertain ? '查看我的预约' : '确认预约',
                  busy: busy,
                  onPressed: uncertain
                      ? () => AppPageRoutes.push<void>(
                          context,
                          const ClassroomBookingsPage(),
                        )
                      : selected == null
                      ? null
                      : submit,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

int _minute(String value) {
  final parts = value.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

String _clock(int value) =>
    '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';

class ClassroomBookingsPage extends ConsumerStatefulWidget {
  const ClassroomBookingsPage({super.key});
  @override
  ConsumerState<ClassroomBookingsPage> createState() => _BookingsState();
}

class _BookingsState extends ConsumerState<ClassroomBookingsPage>
    with ClassroomPageSession<ClassroomBookingsPage> {
  List<ClassroomBooking> rows = [];
  int? nextPage, seminarNext;
  bool loaded = false;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> readRows({bool more = false}) async {
    final result = await ref
        .read(classroomProvider.notifier)
        .run(
          (c) async => (
            seats: !more || nextPage != null
                ? await c.bookings(more ? nextPage! : 1)
                : null,
            rooms: !more || seminarNext != null
                ? await c.seminarBookings(more ? seminarNext! : 1)
                : null,
          ),
        );
    if (!current) return;
    final combined = [
      if (more) ...rows,
      ...?result.seats?.items,
      ...?result.rooms?.items,
    ];
    rows = {
      for (final row in combined)
        '${row.seminar ? 'room' : 'seat'}:${row.id}': row,
    }.values.toList();
    rows.sort(
      (a, b) =>
          (b.periods.firstOrNull ?? '').compareTo(a.periods.firstOrNull ?? ''),
    );
    if (result.seats != null) nextPage = result.seats!.nextPage;
    if (result.rooms != null) seminarNext = result.rooms!.nextPage;
    loaded = true;
  }

  Future<void> load({bool more = false}) => perform(() => readRows(more: more));
  Future<void> cancel(ClassroomBooking row) async {
    final ok = await showAppConfirmDialog(
      context,
      title: '取消这项预约？',
      message:
          '${row.room} ${row.seat}\n${row.periods.join('\n')}\n取消后该时段会重新开放。',
      confirmLabel: '取消预约',
    );
    if (!mounted || !current || !ok) return;
    await perform(() async {
      await ref
          .read(classroomProvider.notifier)
          .run(
            (c) =>
                row.seminar ? c.cancelSeminar(row.id) : c.cancelBooking(row.id),
          );
      await readRows();
    });
  }

  @override
  Widget build(BuildContext context) {
    watchSession();
    return SubpageScaffold(
      title: '我的预约',
      actions: [AppRefreshButton(busy: busy, onRefresh: load)],
      body: AppPageViewport(
        maxWidth: AppLayout.readingMaxWidth,
        builder: (context, insets) => ListView(
          padding: insets + EdgeInsets.all(AppSpace.pageXOf(context)),
          children: [
            if (error != null) Text(error!),
            if (busy) const Center(child: CircularProgressIndicator()),
            if (loaded && rows.isEmpty)
              const EmptyHint(icon: AppIcons.calendar, title: '暂无预约'),
            for (final row in rows)
              SettingsSection(
                padTop: false,
                hasLeading: false,
                children: [
                  SettingsRow(
                    title: '${row.room} ${row.seat}',
                    subtitle: '${row.status}\n${row.periods.join('\n')}',
                    trailing: row.canCancel
                        ? AppButton(
                            label: '取消预约',
                            compact: true,
                            kind: AppButtonKind.secondary,
                            onPressed: busy ? null : () => cancel(row),
                          )
                        : null,
                  ),
                ],
              ),
            if (nextPage != null || seminarNext != null)
              AppButton(
                label: '加载更多',
                busy: busy,
                onPressed: () => load(more: true),
              ),
          ],
        ),
      ),
    );
  }
}

class ClassroomSeminarBookingPage extends ConsumerStatefulWidget {
  const ClassroomSeminarBookingPage({super.key, required this.room});
  final ClassroomSeminar room;
  @override
  ConsumerState<ClassroomSeminarBookingPage> createState() =>
      _SeminarBookingState();
}

class _SeminarBookingState extends ConsumerState<ClassroomSeminarBookingPage>
    with ClassroomPageSession<ClassroomSeminarBookingPage> {
  final form = GlobalKey<FormState>();
  final start = TextEditingController(text: '18:00'),
      end = TextEditingController(text: '19:00'),
      purpose = TextEditingController(),
      people = TextEditingController(text: '1');
  String? date, rule;
  bool agreed = false, allowMany = true, uncertain = false, submitted = false;
  @override
  void initState() {
    super.initState();
    date = widget.room.dates.firstOrNull;
    unawaited(
      perform(() async {
        final v = await ref
            .read(classroomProvider.notifier)
            .run((c) => c.seminarRule(widget.room.id));
        if (current) rule = v;
      }),
    );
  }

  @override
  void dispose() {
    for (final c in [start, end, purpose, people]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate() || date == null || busy || uncertain) {
      return;
    }
    if (rule == null || rule!.isNotEmpty && !agreed) {
      setState(() => error = '请阅读并同意预约规则');
      return;
    }
    if (_minute(end.text) <= _minute(start.text)) {
      setState(() => error = '结束时间应晚于开始时间');
      return;
    }
    if (DateTime.parse('$date ${start.text}:00').isBefore(DateTime.now())) {
      setState(() => error = '开始时间已过去，请重新选择');
      return;
    }
    int? available;
    await perform(() async {
      available = await ref
          .read(classroomProvider.notifier)
          .run(
            (c) => c.seminarAvailability(
              widget.room.id,
              date!,
              start.text,
              end.text,
            ),
          );
    });
    if (!mounted || !current || available == null) return;
    if (available! < int.parse(people.text)) {
      setState(() => error = '该时段剩余可预约人数不足');
      return;
    }
    final ok = await showAppConfirmDialog(
      context,
      title: '确认预约研讨室？',
      message:
          '${widget.room.name}\n$date ${start.text}—${end.text}\n${people.text} 人\n${purpose.text}',
      confirmLabel: '确认预约',
    );
    if (!mounted || !current || !ok) return;
    await perform(() async {
      try {
        await ref
            .read(classroomProvider.notifier)
            .run(
              (c) => c.bookSeminar(
                widget.room.id,
                date!,
                start.text,
                end.text,
                purpose.text.trim(),
                int.parse(people.text),
                allowMany,
              ),
            );
        if (mounted && current) {
          submitted = true;
          Navigator.of(context).pop(true);
        }
      } on ClassroomWriteUncertain {
        uncertain = true;
        rethrow;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    watchSession();
    return SubpageScaffold(
      title: widget.room.name,
      isBusy: () => busy,
      hasUnsavedChanges: () =>
          purpose.text.isNotEmpty && !uncertain && !submitted,
      body: AppPageViewport(
        maxWidth: AppLayout.readingMaxWidth,
        builder: (context, insets) => ListView(
          padding: insets + EdgeInsets.all(AppSpace.pageXOf(context)),
          children: [
            if (error != null) Text(error!),
            if (busy) const Center(child: CircularProgressIndicator()),
            if (date == null)
              const EmptyHint(icon: AppIcons.calendar, title: '暂无可预约日期')
            else
              Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (rule != null && rule!.isNotEmpty)
                      Panel(child: Text(rule!)),
                    const SizedBox(height: AppSpace.md),
                    AppShellSelect<String>(
                      semanticLabel: '预约日期',
                      value: date!,
                      items: widget.room.dates,
                      labelOf: (v) => v,
                      onChanged: busy || uncertain
                          ? null
                          : (v) => setState(() => date = v),
                    ),
                    const SizedBox(height: AppSpace.md),
                    for (final item in [(start, '开始时间'), (end, '结束时间')])
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.md),
                        child: TextFormField(
                          controller: item.$1,
                          enabled: !busy && !uncertain,
                          decoration: InputDecoration(
                            labelText: item.$2,
                            hintText: 'HH:mm',
                          ),
                          validator: (v) =>
                              RegExp(
                                r'^(?:[01]\d|2[0-3]):[0-5]\d$',
                              ).hasMatch(v ?? '')
                              ? null
                              : '请输入有效时间，例如18:00',
                        ),
                      ),
                    TextFormField(
                      controller: purpose,
                      enabled: !busy && !uncertain,
                      decoration: const InputDecoration(labelText: '预约用途'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? '请填写预约用途' : null,
                    ),
                    const SizedBox(height: AppSpace.md),
                    TextFormField(
                      controller: people,
                      enabled: !busy && !uncertain,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '使用人数'),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        return n == null || n < 1 || n > widget.room.capacity
                            ? '请输入1至${widget.room.capacity}人'
                            : null;
                      },
                    ),
                    const SizedBox(height: AppSpace.md),
                    AppCheckboxRow(
                      label: '允许他人预约剩余人数',
                      value: allowMany,
                      onChanged: busy || uncertain
                          ? null
                          : (v) => setState(() => allowMany = v),
                    ),
                    if (rule != null && rule!.isNotEmpty)
                      AppCheckboxRow(
                        label: '已阅读并同意预约规则',
                        value: agreed,
                        onChanged: busy || uncertain
                            ? null
                            : (v) => setState(() => agreed = v),
                      ),
                    const SizedBox(height: AppSpace.lg),
                    AppButton(
                      label: uncertain ? '查看我的预约' : '确认预约',
                      busy: busy,
                      onPressed: uncertain
                          ? () => AppPageRoutes.push<void>(
                              context,
                              const ClassroomBookingsPage(),
                            )
                          : rule == null
                          ? null
                          : submit,
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
