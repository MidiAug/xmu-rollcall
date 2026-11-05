import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/platform/windows_startup.dart';

void main() {
  test(
    'startup setting only changes the app value and quotes the executable',
    () async {
      String? saved;
      final calls = <List<String>>[];
      final startup = WindowsStartup(
        supported: true,
        executable: r'C:\Program Files\厦大签到\xmu_rollcall.exe',
        run: (program, args) async {
          expect(program, 'reg.exe');
          expect(args[1], WindowsStartup.registryKey);
          expect(args[args.indexOf('/v') + 1], WindowsStartup.valueName);
          calls.add(args);
          if (args.first == 'add') {
            saved = args[args.indexOf('/d') + 1];
          }
          if (args.first == 'delete') {
            saved = null;
          }
          return ProcessResult(
            1,
            args.first == 'query' && saved == null ? 1 : 0,
            saved == null ? '' : 'XmuRollcall REG_SZ $saved',
            '',
          );
        },
      );
      expect(await startup.isEnabled(), isFalse);
      await startup.setEnabled(true);
      expect(saved, '"C:\\Program Files\\厦大签到\\xmu_rollcall.exe"');
      expect(await startup.isEnabled(), isTrue);
      await startup.setEnabled(false);
      expect(await startup.isEnabled(), isFalse);
      expect(calls.where((args) => args.first == 'add'), hasLength(1));
      expect(calls.where((args) => args.first == 'delete'), hasLength(1));
    },
  );
  test(
    'development and unsupported platforms never write OS startup settings',
    () async {
      var calls = 0;
      final startup = WindowsStartup(
        supported: false,
        run: (program, args) async {
          calls++;
          return ProcessResult(1, 0, '', '');
        },
      );
      expect(await startup.isEnabled(), isFalse);
      await expectLater(startup.setEnabled(true), throwsStateError);
      await expectLater(startup.setEnabled(false), throwsStateError);
      expect(calls, 0);
    },
  );
  test(
    'failed registry writes remain errors rather than showing success',
    () async {
      final startup = WindowsStartup(
        supported: true,
        run: (program, args) async => ProcessResult(1, 1, '', 'denied'),
      );
      await expectLater(startup.setEnabled(true), throwsStateError);
      await expectLater(startup.setEnabled(false), throwsStateError);
    },
  );
}
