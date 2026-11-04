import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'ta_repository.dart';

final taCsvReaderProvider = Provider<Future<String?> Function()>(
  (ref) => () async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'CSV 成绩表',
          extensions: ['csv'],
          mimeTypes: ['text/csv'],
        ),
      ],
    );
    if (file == null) return null;
    if (await file.length() > 5 * 1024 * 1024) {
      throw const FormatException('CSV 文件不能超过 5 MB');
    }
    return file.readAsString();
  },
);

final taRepositoryProvider = FutureProvider.autoDispose<TaGradingRepository>((
  ref,
) async {
  final auth = ref.watch(authControllerProvider);
  final scope = ref.watch(selectedRollcallAccountProvider);
  final http = ref.watch(homeworkRepositoryProvider).http;
  var alive = true;
  TaGradingRepository? repository;
  ref.onDispose(() {
    alive = false;
    repository?.dispose();
  });
  if (!auth.isSignedIn) throw StateError('请先登录');
  await prepareHomeworkSession(ref, scope);
  if (!alive) throw StateError('账号已变更');
  await http.init();
  if (!alive) throw StateError('账号已变更');
  // Keep the current identity's course summaries across route visits. Watched
  // identity/session dependencies still dispose this repository on change.
  ref.keepAlive();
  return repository = TaGradingRepository(http);
});
