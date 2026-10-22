import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xmu_rollcall/core/logging/log_record.dart';
import 'package:xmu_rollcall/core/logging/ndjson_file_sink.dart';
import 'package:xmu_rollcall/core/logging/log_redactor.dart';

class LogExportResult {
  const LogExportResult({
    required this.zipPath,
    required this.manifest,
    this.shareStatus,
  });

  final String zipPath;
  final Map<String, dynamic> manifest;
  final ShareResultStatus? shareStatus;
}

/// Flush → force-copy NDJSON → manifest → zip → share → cleanup.
class LogExporter {
  LogExporter(
    this._sink, {
    this.supportDirectory,
    Future<PackageInfo> Function()? packageInfo,
    Future<ShareResult> Function(ShareParams)? shareFile,
  }) : _packageInfo = packageInfo ?? PackageInfo.fromPlatform,
       _shareFile = shareFile ?? SharePlus.instance.share;

  final NdjsonFileSink _sink;
  final Directory? supportDirectory;
  final Future<PackageInfo> Function() _packageInfo;
  final Future<ShareResult> Function(ShareParams) _shareFile;

  Future<LogExportResult?> exportAndShare({
    bool share = true,
    Map<String, dynamic> diagnostics = const {},
    Rect? sharePositionOrigin,
  }) async {
    final support = supportDirectory ?? await getApplicationSupportDirectory();
    final exports = await Directory(
      '${support.path}/log-exports',
    ).create(recursive: true);
    // Keep recent files alive after the Android chooser closes: receiving apps
    // may not open the shared content URI until later.
    final previous = await exports
        .list()
        .where((e) => e is File && e.path.endsWith('.zip'))
        .cast<File>()
        .toList();
    previous.sort((a, b) => b.path.compareTo(a.path));
    for (var i = 0; i < previous.length; i++) {
      if (i >= 2 ||
          DateTime.now().difference(await previous[i].lastModified()).inDays >=
              7) {
        try {
          await previous[i].delete();
        } catch (_) {}
      }
    }
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final snapDir = Directory('${support.path}/log-export-snap-$stamp');
    final zipFile = File('${exports.path}/xmu-rollcall-logs-$stamp.zip');

    try {
      final copies = await _sink.copyAllTo(snapDir);
      // The foreground isolate writes separately to avoid concurrent rotation.
      final monitorLogs = Directory('${support.path}/monitor-logs');
      if (await monitorLogs.exists()) {
        await for (final entry in monitorLogs.list()) {
          if (entry is File && entry.path.endsWith('.ndjson')) {
            copies.add(
              await entry.copy(
                '${snapDir.path}/monitor-${entry.uri.pathSegments.last}',
              ),
            );
          }
        }
      }
      final fileEntries = <Map<String, dynamic>>[];
      DateTime? coverageFrom;
      DateTime? coverageTo;
      final recentWarnings = <Map<String, dynamic>>[];
      var corruptLines = 0;
      final networkRecords = <LogRecord>[];

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
          if (rec == null) {
            if (line.trim().isNotEmpty) corruptLines++;
            continue;
          }
          if (rec.event.startsWith('http.') ||
              rec.event.startsWith('rollcall.') ||
              rec.event.startsWith('homework.') ||
              rec.event.startsWith('login.')) {
            networkRecords.add(rec);
          }
          if (rec.level == 'W' || rec.level == 'E') {
            recentWarnings.add(LogRedactor.redactFields(rec.toJson()));
          }
          if (coverageFrom == null || rec.ts.isBefore(coverageFrom)) {
            coverageFrom = rec.ts;
          }
          if (coverageTo == null || rec.ts.isAfter(coverageTo)) {
            coverageTo = rec.ts;
          }
        }
      }

      final info = await _packageInfo();
      final generatedAt = DateTime.now().toUtc().toIso8601String();
      final sinkMeta = {
        'healthy': _sink.healthy,
        'droppedCount': _sink.droppedCount,
        'writeErrorCount': _sink.writeErrorCount,
        'corruptLineCount': _sink.corruptLineCount,
      };
      final appMeta = {
        'name': 'xmu_rollcall',
        'version': info.version,
        'buildNumber': info.buildNumber,
      };
      final platformMeta = {
        'os': Platform.operatingSystem,
        'osVersion': Platform.operatingSystemVersion,
        'locale': Platform.localeName,
      };
      final coverageMeta = {
        'from': coverageFrom?.toUtc().toIso8601String(),
        'to': coverageTo?.toUtc().toIso8601String(),
      };

      final snapshot = <String, dynamic>{
        'redactionPolicy': 'denylist_v1',
        'generatedAt': generatedAt,
        'app': appMeta,
        'platform': platformMeta,
        'sink': sinkMeta,
        'coverage': coverageMeta,
        'diagnostics': LogRedactor.redactFields(diagnostics),
        'export': {
          'corruptLines': corruptLines,
          'retentionDays': 7,
          'maxRetainedArchives': 3,
        },
      };
      final snapshotText = const JsonEncoder.withIndent('  ').convert(snapshot);
      final snapshotFile = File('${snapDir.path}/snapshot.json');
      await snapshotFile.writeAsString(snapshotText);
      final snapshotBytes = utf8.encode(snapshotText);
      fileEntries.add({
        'name': 'snapshot.json',
        'bytes': snapshotBytes.length,
        'sha256': sha256.convert(snapshotBytes).toString(),
      });
      recentWarnings.sort((a, b) => '${b['ts']}'.compareTo('${a['ts']}'));
      final errorsText = const JsonEncoder.withIndent(
        '  ',
      ).convert(recentWarnings.take(50).toList());
      await File(
        '${snapDir.path}/recent-errors.json',
      ).writeAsString(errorsText);
      final errorsBytes = utf8.encode(errorsText);
      fileEntries.add({
        'name': 'recent-errors.json',
        'bytes': errorsBytes.length,
        'sha256': sha256.convert(errorsBytes).toString(),
      });

      networkRecords.sort((a, b) => a.ts.compareTo(b.ts));
      final networkText = networkRecords
          .map(
            (record) => jsonEncode(
              LogRedactor.redactFields(
                record.toJson(),
                maxBytes: LogRedactor.maxProjectionUtf8Bytes,
              ),
            ),
          )
          .join('\n');
      final guide =
          '厦大签到诊断包\n'
          '应用版本：${info.version}+${info.buildNumber}\n'
          '系统：${Platform.operatingSystem}\n'
          '生成时间（UTC）：$generatedAt\n\n'
          'network.ndjson：按时间排序的网络、签到、作业和登录请求流水。\n'
          '使用 requestId 关联请求与响应，使用 opId 关联一次签到操作。\n'
          'queueMs 为排队耗时，latencyMs 为发出请求后的耗时；两者单位均为毫秒。\n'
          'recent-errors.json：最近 50 条警告和错误，包含可用的异常类型和堆栈。\n'
          'snapshot.json：当前身份范围、监测状态和日志状态快照。\n'
          'app.ndjson / monitor-*.ndjson：原始前台及后台诊断事件。\n'
          'manifest.json：文件大小及 SHA-256，用于检查压缩包完整性。\n'
          '时间戳统一为 UTC，本地时间需要按时区换算。\n'
          '日志已过滤登录密码、Cookie 和访问令牌。\n';
      for (final entry in {
        'network.ndjson': networkText,
        'README.txt': guide,
      }.entries) {
        final bytes = utf8.encode(entry.value);
        await File('${snapDir.path}/${entry.key}').writeAsBytes(bytes);
        fileEntries.add({
          'name': entry.key,
          'bytes': bytes.length,
          'sha256': sha256.convert(bytes).toString(),
        });
      }

      final manifest = <String, dynamic>{
        'schemaVersion': 1,
        'redactionPolicy': 'denylist_v1',
        'generatedAt': generatedAt,
        'app': appMeta,
        'platform': platformMeta,
        'coverage': coverageMeta,
        'files': fileEntries,
        'sink': sinkMeta,
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

      ShareResultStatus? shareStatus;
      if (share) {
        shareStatus = (await _shareFile(
          ShareParams(
            files: [XFile(zipFile.path, mimeType: 'application/zip')],
            title: '厦大签到诊断日志',
            sharePositionOrigin: sharePositionOrigin,
          ),
        )).status;
      }

      return LogExportResult(
        zipPath: zipFile.path,
        manifest: manifest,
        shareStatus: shareStatus,
      );
    } finally {
      try {
        if (await snapDir.exists()) {
          await snapDir.delete(recursive: true);
        }
      } catch (_) {}
    }
  }
}
