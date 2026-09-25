import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xmu_rollcall/core/logging/log_record.dart';
import 'package:xmu_rollcall/core/logging/ndjson_file_sink.dart';

class LogExportResult {
  const LogExportResult({
    required this.zipPath,
    required this.manifest,
  });

  final String zipPath;
  final Map<String, dynamic> manifest;
}

/// Flush → force-copy NDJSON → manifest → zip → share → cleanup.
class LogExporter {
  LogExporter(this._sink);

  final NdjsonFileSink _sink;

  Future<LogExportResult?> exportAndShare({
    bool share = true,
  }) async {
    final support = await getApplicationSupportDirectory();
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final snapDir = Directory('${support.path}/log-export-snap-$stamp');
    final zipFile = File('${support.path}/xmu-rollcall-logs-$stamp.zip');

    try {
      final copies = await _sink.copyAllTo(snapDir);
      final fileEntries = <Map<String, dynamic>>[];
      DateTime? coverageFrom;
      DateTime? coverageTo;

      for (final file in copies) {
        final bytes = await file.readAsBytes();
        final digest = sha256.convert(bytes);
        fileEntries.add({
          'name': file.uri.pathSegments.last,
          'bytes': bytes.length,
          'sha256': digest.toString(),
        });
        final text = utf8.decode(bytes, allowMalformed: true);
        for (final line in const LineSplitter().convert(text)) {
          final rec = LogRecord.tryParse(line);
          if (rec == null) continue;
          if (coverageFrom == null || rec.ts.isBefore(coverageFrom)) {
            coverageFrom = rec.ts;
          }
          if (coverageTo == null || rec.ts.isAfter(coverageTo)) {
            coverageTo = rec.ts;
          }
        }
      }

      final info = await PackageInfo.fromPlatform();
      final manifest = <String, dynamic>{
        'schemaVersion': 1,
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
        'app': {
          'name': 'xmu_rollcall',
          'version': info.version,
          'buildNumber': info.buildNumber,
        },
        'platform': {
          'os': Platform.operatingSystem,
          'osVersion': Platform.operatingSystemVersion,
          'locale': Platform.localeName,
        },
        'coverage': {
          'from': coverageFrom?.toUtc().toIso8601String(),
          'to': coverageTo?.toUtc().toIso8601String(),
        },
        'files': fileEntries,
        'sink': {
          'healthy': _sink.healthy,
          'droppedCount': _sink.droppedCount,
          'writeErrorCount': _sink.writeErrorCount,
          'corruptLineCount': _sink.corruptLineCount,
        },
      };

      final manifestFile = File('${snapDir.path}/manifest.json');
      await manifestFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(manifest),
      );

      final archive = Archive();
      await for (final entity in snapDir.list(recursive: false)) {
        if (entity is! File) continue;
        final data = await entity.readAsBytes();
        archive.addFile(
          ArchiveFile(entity.uri.pathSegments.last, data.length, data),
        );
      }
      final zipBytes = ZipEncoder().encode(archive);
      await zipFile.writeAsBytes(zipBytes, flush: true);

      if (share) {
        await SharePlus.instance.share(
          ShareParams(files: [XFile(zipFile.path)]),
        );
      }

      return LogExportResult(zipPath: zipFile.path, manifest: manifest);
    } finally {
      try {
        if (await snapDir.exists()) {
          await snapDir.delete(recursive: true);
        }
      } catch (_) {}
      if (share) {
        try {
          if (await zipFile.exists()) {
            await zipFile.delete();
          }
        } catch (_) {}
      }
    }
  }
}
