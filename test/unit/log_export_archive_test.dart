import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xmu_rollcall/core/logging/log_exporter.dart';
import 'package:xmu_rollcall/core/logging/log_record.dart';
import 'package:xmu_rollcall/core/logging/ndjson_file_sink.dart';

void main() {
  late Directory root;
  late NdjsonFileSink sink;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('xmu_archive_test_');
    sink = NdjsonFileSink(logsDir: Directory('${root.path}/logs'));
    await sink.open();
    await sink.appendLine(
      LogRecord(
        ts: DateTime.utc(2026, 10, 21),
        level: 'W',
        event: 'rollcall.type.unknown',
        fields: {'rollcallId': 7},
      ).toNdjsonLine(),
    );
  });
  tearDown(() async {
    await sink.close();
    await root.delete(recursive: true);
  });
  Future<PackageInfo> info() async => PackageInfo(
    appName: 'test',
    packageName: 'test',
    version: '1',
    buildNumber: '2',
  );

  test(
    'real ZIP retains shared file and includes verified foreground/background diagnostics',
    () async {
      final monitor = await Directory('${root.path}/monitor-logs').create();
      await File('${monitor.path}/monitor.ndjson').writeAsString(
        '${LogRecord(ts: DateTime.utc(2026, 10, 21, 1), level: 'E', event: 'poll.failed').toNdjsonLine()}\npartial-json',
      );
      final exporter = LogExporter(
        sink,
        supportDirectory: root,
        packageInfo: info,
        shareFile: (params) async {
          expect(params.files!.single.mimeType, 'application/zip');
          expect(await File(params.files!.single.path).exists(), isTrue);
          return const ShareResult('', ShareResultStatus.dismissed);
        },
      );
      final result = (await exporter.exportAndShare(
        diagnostics: {
          'session': {'signedIn': true, 'password': 'secret-value'},
          'activeRollcalls': {
            'typeCounts': {'qrcode': 1},
          },
        },
      ))!;
      expect(result.shareStatus, ShareResultStatus.dismissed);
      // Simulate the receiving application opening the file after chooser return.
      final zip = ZipDecoder().decodeBytes(
        await File(result.zipPath).readAsBytes(),
      );
      final files = {for (final file in zip.files) file.name: file};
      expect(
        files.keys,
        containsAll([
          'README.txt',
          'network.ndjson',
          'manifest.json',
          'snapshot.json',
          'recent-errors.json',
          'app.ndjson',
          'monitor-monitor.ndjson',
        ]),
      );
      final trace = utf8.decode(files['network.ndjson']!.content as List<int>);
      expect(jsonDecode(trace.trim())['event'], 'rollcall.type.unknown');
      final guide = utf8.decode(files['README.txt']!.content as List<int>);
      expect(guide, contains('requestId'));
      expect(guide, contains('queueMs'));
      final manifest =
          jsonDecode(utf8.decode(files['manifest.json']!.content as List<int>))
              as Map;
      for (final entry in manifest['files'] as List) {
        final bytes = files[entry['name']]!.content as List<int>;
        expect(entry['bytes'], bytes.length);
        expect(entry['sha256'], sha256.convert(bytes).toString());
      }
      final snapshotText = utf8.decode(
        files['snapshot.json']!.content as List<int>,
      );
      expect(snapshotText, isNot(contains('secret-value')));
      expect((jsonDecode(snapshotText) as Map)['export']['corruptLines'], 1);
      final errors =
          jsonDecode(
                utf8.decode(files['recent-errors.json']!.content as List<int>),
              )
              as List;
      expect(errors.map((e) => e['event']), [
        'poll.failed',
        'rollcall.type.unknown',
      ]);
      expect(
        await root.list().any(
          (entry) => entry.path.contains('log-export-snap-'),
        ),
        isFalse,
      );
    },
  );

  test(
    'retains only three recent archives and keeps ZIP on share failure',
    () async {
      final directory = await Directory('${root.path}/log-exports').create();
      for (var i = 0; i < 4; i++) {
        await File(
          '${directory.path}/xmu-rollcall-logs-2026-10-0$i.zip',
        ).writeAsBytes([1]);
      }
      final exporter = LogExporter(
        sink,
        supportDirectory: root,
        packageInfo: info,
        shareFile: (_) async => throw StateError('chooser failed'),
      );
      await expectLater(exporter.exportAndShare(), throwsStateError);
      final retained = await directory.list().toList();
      expect(retained, hasLength(3));
      expect(
        await root.list().any(
          (entry) => entry.path.contains('log-export-snap-'),
        ),
        isFalse,
      );
    },
  );
}
