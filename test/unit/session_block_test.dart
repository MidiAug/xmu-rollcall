import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';

DateTime _t(int h, int m) => DateTime(2026, 9, 22, h, m); // Tuesday

List<SessionBlock> _afternoonTwoBlocks() {
  final slots = [
    TimetableSlot(sequence: 5, start: _t(14, 30), end: _t(15, 15)),
    TimetableSlot(sequence: 6, start: _t(15, 25), end: _t(16, 10)),
    TimetableSlot(sequence: 7, start: _t(16, 40), end: _t(17, 25)),
    TimetableSlot(sequence: 8, start: _t(17, 35), end: _t(18, 20)),
  ];
  return splitContiguousBlocks(slots);
}

void main() {
  test('splitContiguousBlocks merges 5-6 and 7-8 separately', () {
    final blocks = _afternoonTwoBlocks();
    expect(blocks.map((b) => b.id), ['5-6', '7-8']);
    expect(blocks[0].sectionLabel, '第5–6节');
    expect(formatHm(blocks[0].coreStart), '14:30');
    expect(formatHm(blocks[0].coreEnd), '16:10');
  });

  test('pre-class 14:20 maps to 5-6', () {
    final blocks = _afternoonTwoBlocks();
    final b = resolveBlock(blocks, _t(14, 20));
    expect(b?.id, '5-6');
  });

  test('mid-class 15:20 maps to 5-6', () {
    final blocks = _afternoonTwoBlocks();
    expect(resolveBlock(blocks, _t(15, 20))?.id, '5-6');
  });

  test('16:50 maps to 7-8 not 5-6', () {
    final blocks = _afternoonTwoBlocks();
    expect(resolveBlock(blocks, _t(16, 50))?.id, '7-8');
  });

  test('overlap / big break 16:15 prefers next block 7-8', () {
    final blocks = _afternoonTwoBlocks();
    // 5-6 window ends 16:15; 7-8 window starts 16:15
    expect(resolveBlock(blocks, _t(16, 15))?.id, '7-8');
  });

  test('unscoped when outside all windows', () {
    final blocks = _afternoonTwoBlocks();
    expect(resolveBlock(blocks, _t(12, 0)), isNull);
  });

  test('parseTimetables reads capture-shaped payload', () {
    final raw = {
      '5': [
        {
          'timetable_slot': {
            'sequence': 5,
            'start_time': '14:30:00',
            'end_time': '15:15:00',
          },
        },
        {
          'timetable_slot': {
            'sequence': 6,
            'start_time': '15:25:00',
            'end_time': '16:10:00',
          },
        },
      ],
    };
    final map = parseTimetables(raw, anchor: _t(0, 0));
    expect(map[5], isNotNull);
    final blocks = splitContiguousBlocks(map[5]!);
    expect(blocks.single.id, '5-6');
  });
}
