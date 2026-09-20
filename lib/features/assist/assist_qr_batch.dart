import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/session_key.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';

class AssistQrTarget {
  const AssistQrTarget({
    required this.key,
    required this.label,
    required this.userId,
    this.deviceId,
  });

  final SessionKey key;
  final String label;
  final int userId;
  final String? deviceId;
}

class AssistQrSubmitResult {
  const AssistQrSubmitResult({
    required this.target,
    required this.ok,
    this.message,
  });

  final AssistQrTarget target;
  final bool ok;
  final String? message;
}

typedef AssistQrSubmitFn = Future<AnswerResult> Function(
  AssistQrTarget target,
  String qrData,
);

/// Pure filter: keep assists enrolled in [courseId].
List<AssistIdentity> filterAssistForCourse({
  required String? courseId,
  required List<AssistIdentity> identities,
  required Map<int, Set<String>> courseIdsByUser,
}) {
  if (courseId == null || courseId.isEmpty) return const [];
  return identities
      .where((e) => courseIdsByUser[e.userId]?.contains(courseId) ?? false)
      .toList();
}

/// Serial multi-identity QR submit (KB-01: no concurrent blast).
class AssistQrBatchRunner {
  AssistQrBatchRunner({required this.submit});

  final AssistQrSubmitFn submit;

  Future<List<AssistQrSubmitResult>> run({
    required String qrData,
    required List<AssistQrTarget> targets,
  }) async {
    final out = <AssistQrSubmitResult>[];
    for (final t in targets) {
      try {
        final r = await submit(t, qrData);
        out.add(
          AssistQrSubmitResult(
            target: t,
            ok: r.ok,
            message: r.message,
          ),
        );
      } catch (e) {
        out.add(
          AssistQrSubmitResult(
            target: t,
            ok: false,
            message: '$e',
          ),
        );
      }
    }
    return out;
  }
}
