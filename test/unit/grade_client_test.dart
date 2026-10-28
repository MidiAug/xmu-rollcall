import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/schedule/academic_client.dart';
import 'dart:convert';

class Client extends AcademicClient {
  Client() : super(store: SecureStore.memory({SecureStore.keyUserId: '1'}));
  final queries = <Map<String, dynamic>>[];
  bool wrongIdentity = false, repeating = false;
  @override
  Future<void> open(Uri uri, {String? username, String? password}) async {}
  @override
  Future<Map<String, dynamic>> json(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    if (path.contains('initXsxx')) {
      return {
        'success': true,
        'data': {'XH': 'sample'},
      };
    }
    if (path.contains('cxdqxnxq')) {
      return {
        'datas': {
          'cxdqxnxqhsygxnxq': {
            'rows': [
              {'XNXQDM': '2026-2027-1'},
              {'XNXQDM': '2025-2026-9'},
            ],
          },
        },
      };
    }
    queries.add(data!);
    final q = jsonDecode(data['querySetting'] as String) as List;
    final term =
        q.where((r) => r['name'] == 'XNXQDM').firstOrNull?['value'] ?? 'all';
    return {
      'datas': {
        'xscjcx': {
          'totalSize': repeating ? 5 : 1,
          'rows': [
            {
              'WID': 'record-$term',
              'XH': wrongIdentity ? 'other' : 'sample',
              'KCM': 'Test',
              'XF': '2',
              'JDF': '3.7',
              'XNXQDM': term,
            },
          ],
        },
      },
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'full and recent use captured endpoints and minimize persisted columns',
    () async {
      final all = Client();
      final result = await all.fetchGrades(1, username: 'sample');
      expect(all.queries.length, 1);
      expect(result.replacedTerms, isEmpty);
      expect(result.rows.single.containsKey('XH'), isFalse);
      final recent = Client();
      final delta = await recent.fetchGrades(
        1,
        username: 'sample',
        recent: true,
      );
      expect(recent.queries.length, 2);
      expect(delta.replacedTerms, {'2026-2027-1', '2025-2026-9'});
    },
  );
  test(
    'wrong account and ignored pagination never become a complete cache',
    () async {
      await expectLater(
        (Client()..wrongIdentity = true).fetchGrades(1, username: 'sample'),
        throwsFormatException,
      );
      await expectLater(
        (Client()..repeating = true).fetchGrades(1, username: 'sample'),
        throwsFormatException,
      );
    },
  );
}
