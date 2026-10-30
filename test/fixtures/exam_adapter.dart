import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';

class ExamAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Completer<void>? gate;
  final entered = Completer<void>();
  bool emptyArranged = false, empty = false;
  bool wrongStudent = false;
  bool wrongIdentity = false,
      wrongTerm = false,
      failUnarranged = false,
      repeat = false,
      invalidDate = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    final path = options.uri.path;
    Object data = '<html></html>';
    if (path.endsWith('initXsxx.do')) {
      return ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': ['/authserver/login'],
        },
      );
    } else if (path.endsWith('cxxsjbxx.do')) {
      data = {
        'code': '0',
        'datas': {
          'cxxsjbxx': {
            'totalSize': 1,
            'rows': [
              {'XH': wrongStudent ? 'other' : 'synthetic'},
            ],
          },
        },
      };
    } else if (path.endsWith('setJwCommonAppRole.do')) {
      data = {'success': '1'};
    } else if (path.endsWith('/cxxsksap.do') ||
        path.endsWith('/cxyxkwapkwdkc.do')) {
      if (!entered.isCompleted) entered.complete();
      if (gate != null) await gate!.future;
      final unarranged = path.endsWith('/cxyxkwapkwdkc.do');
      if (unarranged && failUnarranged) {
        return ResponseBody.fromString('unavailable', 503);
      }
      final form = options.data as Map;
      final page = form['pageNumber'] as int;
      final rows = empty || (!unarranged && emptyArranged)
          ? <Map<String, dynamic>>[]
          : unarranged
          ? [
              {'KCH': 'undated', 'KCM': '考查课程'},
              {'KCH': 'pending', 'KCM': '未安排课程'},
            ]
          : page == 1 || repeat
          ? [
              {
                'KSRWID': 'a',
                'KCH': 'dated',
                'KCM': '已排课程',
                'XH': wrongIdentity ? 'another' : 'synthetic',
                'XNXQDM': wrongTerm ? '2025-2026-2' : form['XNXQDM'],
                'KSRQ': invalidDate ? '2026-02-30' : '2026-11-10',
                'KSSJMS': '2026-11-10 08:00-10:00(星期二)',
                'JASMC': '测试楼A101',
                'ZWH': '12',
                'KSXS_DISPLAY': '闭卷',
                'private_unneeded': 'must-not-persist',
              },
            ]
          : [
              {
                'KSRWID': 'b',
                'KCH': 'undated',
                'KCM': '考查课程',
                'KSRQ': null,
                'SFAPSJ': '0',
                'SFXYAPKS': '0',
                'XH': 'synthetic',
                'XNXQDM': form['XNXQDM'],
              },
            ];
      data = {
        'code': '0',
        'datas': {
          unarranged ? 'cxyxkwapkwdkc' : 'cxxsksap': {
            'rows': rows,
            'totalSize': rows.isEmpty ? 0 : 2,
          },
        },
      };
    }
    return ResponseBody.fromString(
      data is String ? data : jsonEncode(data),
      200,
    );
  }

  @override
  void close({bool force = false}) {}
}
