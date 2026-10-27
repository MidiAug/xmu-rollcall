import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/identity/device_identity.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:xmu_rollcall/core/session/assist_identity_store.dart';
import 'package:xmu_rollcall/core/session/assist_service.dart';
import 'package:xmu_rollcall/core/session/session_client_registry.dart';
import 'dart:convert';

void main() {
  test(
    'student id survives reinstalls, differs across students and updates the live cache',
    () async {
      final first = DeviceIdentity(SecureStore.memory());
      final prior = await first.getId();
      final stable = await first.bindStudentNumber(' 2099000000001 ');
      expect(stable, isNot(prior));
      expect(await first.getId(), stable);
      final reinstall = DeviceIdentity(SecureStore.memory());
      expect(await reinstall.bindStudentNumber('2099000000001'), stable);
      expect(await reinstall.bindStudentNumber('2099000000002'), isNot(stable));
      expect(DeviceIdentity.forStudentNumber('display name'), isNull);
      expect(DeviceIdentity.forStudentNumber('123'), isNull);
      expect(await first.bindStudentNumber(null), stable);
    },
  );
  test(
    'legacy assists migrate from their own secure student credential and preserve unknown identities',
    () async {
      final store = SecureStore.memory({
        AssistService.accountCredKey(2): jsonEncode({
          'username': '2099000000002',
          'password': 'synthetic-password',
        }),
      });
      final roster = AssistIdentityStore(store);
      const imported = AssistIdentity(
        userId: 2,
        displayName: '示例',
        kind: AssistCredentialKind.account,
        deviceId: 'legacy-assist',
      );
      await roster.upsert(imported);
      final service = AssistService(
        store: store,
        registry: SessionClientRegistry(store: store),
      );
      final migrated = await service.ensureDeviceId(imported);
      expect(
        migrated.deviceId,
        DeviceIdentity.forStudentNumber('2099000000002'),
      );
      expect((await roster.list()).single.studentNo, '2099000000002');
      final unknown = await service.ensureDeviceId(
        const AssistIdentity(
          userId: 3,
          displayName: '未知',
          kind: AssistCredentialKind.session,
          deviceId: 'keep-existing',
        ),
      );
      expect(unknown.deviceId, 'keep-existing');
    },
  );
  test('parallel identity migrations preserve both roster updates', () async {
    final store = SecureStore.memory();
    final roster = AssistIdentityStore(store);
    for (var uid = 2; uid <= 3; uid++) {
      await roster.upsert(
        AssistIdentity(
          userId: uid,
          displayName: '示例$uid',
          kind: AssistCredentialKind.account,
          deviceId: 'legacy-$uid',
        ),
      );
      await store.write(
        AssistService.accountCredKey(uid),
        jsonEncode({'username': '209900000000$uid', 'password': 'synthetic'}),
      );
    }
    final service = AssistService(
      store: store,
      registry: SessionClientRegistry(store: store),
    );
    await Future.wait((await roster.list()).map(service.ensureDeviceId));
    final result = await roster.list();
    expect(result, hasLength(2));
    for (final identity in result) {
      expect(identity.studentNo, '209900000000${identity.userId}');
      expect(
        identity.deviceId,
        DeviceIdentity.forStudentNumber(identity.studentNo),
      );
    }
  });
}
