import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final windowsStartupProvider = Provider((ref) => WindowsStartup());

/// Only this app's current-user Run value is changed, after a settings action.
class WindowsStartup {
  WindowsStartup({
    bool? supported,
    String? executable,
    Future<ProcessResult> Function(String, List<String>)? run,
  }) : supported = supported ?? (Platform.isWindows && kReleaseMode),
       executable = executable ?? Platform.resolvedExecutable,
       _run =
           run ??
           ((program, args) => Process.run(program, args, runInShell: false));
  final bool supported;
  final String executable;
  final Future<ProcessResult> Function(String, List<String>) _run;
  static const registryKey =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const valueName = 'XmuRollcall';
  String get command => '"$executable"';

  Future<bool> isEnabled() async {
    if (!supported) return false;
    final result = await _run('reg.exe', [
      'query',
      registryKey,
      '/v',
      valueName,
    ]);
    if (result.exitCode != 0) return false;
    final match = RegExp(
      r'REG_SZ\s+([^\r\n]+)',
    ).firstMatch(result.stdout.toString());
    return match?.group(1)?.trim() == command;
  }

  Future<void> setEnabled(bool enabled) async {
    if (!supported) throw StateError('请在 Windows 正式版中设置开机启动');
    final result = await _run(
      'reg.exe',
      enabled
          ? [
              'add',
              registryKey,
              '/v',
              valueName,
              '/t',
              'REG_SZ',
              '/d',
              command,
              '/f',
            ]
          : ['delete', registryKey, '/v', valueName, '/f'],
    );
    if (result.exitCode != 0 || await isEnabled() != enabled) {
      throw StateError('开机启动设置未能保存，请重试');
    }
  }
}
