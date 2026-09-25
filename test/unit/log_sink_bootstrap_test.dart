import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/core/logging/log_record.dart';
import 'package:xmu_rollcall/core/logging/memory_log_index.dart';
import 'package:xmu_rollcall/core/logging/ndjson_file_sink.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('xmu_log_');
  });

  tearDown(() async {
    await AppLog.resetForTest();
    try {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    } catch (_) {
      // Windows may keep a handle briefly; ignore cleanup noise.
    }
  });

  group('NdjsonFileSink', () {
    test('rotates when maxFileBytes exceeded', () async {
      final sink = NdjsonFileSink(
        logsDir: temp,
        maxFileBytes: 80,
        maxTotalBytes: 10 * 1024 * 1024,
      );
      await sink.open();
      for (var i = 0; i < 20; i++) {
        await sink.appendLine(
          '{"ts":"2026-09-25T00:00:00.${i.toString().padLeft(3, '0')}Z","level":"I","event":"t","msg":"t","fields":{}}',
        );
      }
      await sink.flush();
      final files = await sink.listNdjsonFiles();
      expect(files.length, greaterThan(1));
      final active = File('${temp.path}/app.ndjson');
      expect(await active.exists(), isTrue);
      expect(await active.length(), lessThan(80));
      await sink.close();
    });

    test('enforces maxTotalBytes by deleting oldest rotated', () async {
      final sink = NdjsonFileSink(
        logsDir: temp,
        maxFileBytes: 60,
        maxTotalBytes: 200,
      );
      await sink.open();
      for (var i = 0; i < 40; i++) {
        await sink.appendLine(
          '{"ts":"2026-09-25T00:00:00.${i.toString().padLeft(3, '0')}Z","level":"I","event":"t$i","msg":"t$i","fields":{}}',
        );
      }
      await sink.flush();
      var total = 0;
      await for (final e in temp.list()) {
        if (e is File && e.path.endsWith('.ndjson')) {
          total += await e.length();
        }
      }
      expect(total, lessThanOrEqualTo(200));
      await sink.close();
    });

    test('copyAllTo snapshot is independent of later deletes', () async {
      final sink = NdjsonFileSink(logsDir: temp, maxFileBytes: 1024 * 1024);
      await sink.open();
      await sink.appendLine(
        '{"ts":"2026-09-25T12:00:00.000Z","level":"I","event":"keep","msg":"keep","fields":{}}',
      );
      await sink.flush();
      final snap = Directory('${temp.path}/snap');
      final copies = await sink.copyAllTo(snap);
      expect(copies, isNotEmpty);
      final digestBefore =
          sha256.convert(await copies.first.readAsBytes()).toString();

      // Close writer so Windows releases the active file handle.
      await sink.close();

      await for (final e in temp.list()) {
        if (e is File &&
            e.path.endsWith('.ndjson') &&
            !e.path.contains('${Platform.pathSeparator}snap${Platform.pathSeparator}') &&
            !e.path.contains('/snap/')) {
          // Only delete files directly under temp, not under snap.
          if (e.parent.path == temp.path) {
            await e.delete();
          }
        }
      }
      expect(await copies.first.exists(), isTrue);
      expect(
        sha256.convert(await copies.first.readAsBytes()).toString(),
        digestBefore,
      );
    });

    test('readNewest skips corrupt lines', () async {
      final sink = NdjsonFileSink(logsDir: temp);
      await sink.open();
      await sink.close();
      final file = File('${temp.path}/app.ndjson');
      await file.writeAsString(
        'not-json\n'
        '{"ts":"2026-09-25T12:00:00.000Z","level":"I","event":"ok","msg":"ok","fields":{}}\n'
        '{"ts":"bad"\n',
      );
      final sink2 = NdjsonFileSink(logsDir: temp);
      await sink2.open();
      final rows = await sink2.readNewest(limit: 10);
      expect(rows.length, 1);
      expect(rows.first.event, 'ok');
      expect(sink2.corruptLineCount, greaterThan(0));
      await sink2.close();
    });
  });

  group('AppLog.bootstrap', () {
    test('pending events land after ready; disk backfills index', () async {
      final prep = NdjsonFileSink(logsDir: temp);
      await prep.open();
      await prep.appendLine(
        '{"ts":"2026-09-25T10:00:00.000Z","level":"I","event":"old","msg":"old","fields":{"n":1}}',
      );
      await prep.close();

      await AppLog.resetForTest(index: MemoryLogIndex(capacity: 50));
      AppLog.event('pending.one', fields: {'x': 1});
      expect(AppLog.index.length, 0);

      await AppLog.bootstrap(sink: NdjsonFileSink(logsDir: temp));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await AppLog.flush();

      final events = AppLog.index.recent.map((e) => e.event).toList();
      expect(events, contains('old'));
      expect(events, contains('pending.one'));
      expect(events, contains('app.start'));
    });
  });

  group('LogRecord', () {
    test('roundtrip ndjson', () {
      final r = LogRecord(
        ts: DateTime.utc(2026, 9, 25, 1, 2, 3),
        level: 'I',
        event: 'rollcall.answer.start',
        opId: 'abc',
        fields: {'rollcallId': 9, 'ok': true},
      );
      final parsed = LogRecord.tryParse(r.toNdjsonLine());
      expect(parsed, isNotNull);
      expect(parsed!.event, r.event);
      expect(parsed.opId, 'abc');
      expect(parsed.rollcallId, 9);
      expect(parsed.ok, isTrue);
    });
  });
}
