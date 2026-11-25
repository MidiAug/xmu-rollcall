import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:pointycastle/export.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/network/tron_endpoints.dart';
import 'campus_card_models.dart';
export 'campus_card_models.dart';

/// A verified current-account session. The provider connects once before
/// invoking business methods; no caller supplies an unrelated card account.
class CampusCardClient {
  CampusCardClient(Dio dio, {RateLimiter? limiter})
    : _dio = dio,
      limiter = limiter ?? RateLimiter() {
    _dio.interceptors.add(CookieManager(_cookies));
    _dio.options.connectTimeout = const Duration(seconds: 20);
    _dio.options.receiveTimeout = const Duration(seconds: 25);
  }
  static const baseUrl = 'https://ecardpay.xmu.edu.cn';
  final Dio _dio;
  final RateLimiter limiter;
  final _cookies = CookieJar();
  Future<bool> Function()? identityGuard;
  CampusCardInfo? _info;
  String? _studentNo;
  Future<CampusCardInfo>? _flight;
  bool _writing = false;
  void close() => _dio.close(force: true);
  Future<void> _guard() async {
    if (identityGuard != null && !await identityGuard!()) {
      throw StateError('账号已切换');
    }
  }

  Future<Object?> _post(
    String path,
    Map<String, dynamic> fields, {
    bool write = false,
  }) async {
    try {
      final response = await limiter.schedule(() async {
        final cookies = await _cookies.loadForRequest(Uri.parse(baseUrl));
        await _guard();
        return _dio.post<dynamic>(
          '$baseUrl$path',
          data: {...fields, 'json': 'true'},
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            responseType: ResponseType.plain,
            followRedirects: false,
            validateStatus: (s) => s != null && s < 500,
            headers: {
              'User-Agent': TronEndpoints.userAgent,
              'X_REQUESTED_WITH':
                  cookies
                      .where((c) => c.name == 'pageToken')
                      .firstOrNull
                      ?.value ??
                  '',
            },
          ),
        );
      }, priority: write ? RequestPriority.submission : RequestPriority.normal);
      await _guard();
      if (response.statusCode != 200) {
        if (write) throw const CampusCardWriteUncertain();
        throw const CampusCardException('校园卡服务暂不可用，请稍后重试');
      }
      final data = cardDecode(response.data);
      if (data is Map && {'-404', '-405'}.contains(cardText(data['Msg']))) {
        _info = null;
        throw const CampusCardException('校园卡会话已过期，请更新账户');
      }
      return data;
    } on DioException {
      if (write) throw const CampusCardWriteUncertain();
      rethrow;
    } on FormatException catch (e) {
      if (write && e is! CampusCardException) {
        throw const CampusCardWriteUncertain();
      }
      rethrow;
    }
  }

  Future<String> _formDocument(
    String path,
    Map<String, dynamic> fields, {
    CancelToken? cancelToken,
  }) async {
    var uri = Uri.parse('$baseUrl$path');
    var method = 'POST';
    for (var hop = 0; hop < 5; hop++) {
      final response = await limiter.schedule(() async {
        await _guard();
        return _dio.requestUri<dynamic>(
          uri,
          data: method == 'POST' ? fields : null,
          cancelToken: cancelToken,
          options: Options(
            method: method,
            contentType: Headers.formUrlEncodedContentType,
            followRedirects: false,
            responseType: ResponseType.plain,
            validateStatus: (s) => s != null && s < 500,
            headers: {'User-Agent': TronEndpoints.userAgent},
          ),
        );
      });
      final location = response.headers.value('location');
      if (response.statusCode == 200) return '${response.data ?? ''}';
      if (location == null ||
          !{301, 302, 303, 307, 308}.contains(response.statusCode)) {
        break;
      }
      uri = uri.resolve(location);
      if (uri.scheme != 'https' || uri.host != 'ecardpay.xmu.edu.cn') {
        throw const CampusCardException('校园卡登录跳转异常');
      }
      method = 'GET';
    }
    throw const CampusCardException('校园卡连接失败，请稍后重试');
  }

  Future<CampusCardInfo> fetch({
    required String studentNo,
    CancelToken? cancelToken,
    bool force = false,
  }) => _flight ??= _fetch(
    studentNo,
    cancelToken,
    force,
  ).whenComplete(() => _flight = null);
  Future<CampusCardInfo> _fetch(
    String studentNo,
    CancelToken? cancelToken,
    bool force,
  ) async {
    if (studentNo.isEmpty) throw const CampusCardException('请重新登录所选账号以连接校园卡');
    if (_studentNo != null && _studentNo != studentNo) {
      throw const CampusCardException('校园卡会话与所选账号不一致');
    }
    await _guard();
    if (_info != null && !force) return _info!;
    if (_info == null) {
      await _formDocument('/cassyno/index', {
        'errorcode': '1',
        'continueurl': '',
        'ssoticketid': studentNo,
      }, cancelToken: cancelToken);
    }
    final result = parseCardInfoResponse(await _post('/User/GetCardInfo', {}));
    if (result == null || result.studentNo != studentNo) {
      throw const CampusCardException('校园卡返回的身份与所选账号不一致');
    }
    await _guard();
    _studentNo = studentNo;
    _info = result;
    return result;
  }

  Map<String, dynamic> _business(Object? value, String name) {
    final root = cardMap(value), inner = cardMap(root['Msg']);
    final data = cardMap(inner[name]);
    if (cardText(data['retcode']) != '0') {
      throw CampusCardException(cardText(data['errmsg']));
    }
    return data;
  }

  Future<List<({String name, double balance})>> accounts() async {
    final data = _business(
      await _post('/User/GetCardAccInfo', {'acc': _info!.account}),
      'query_accinfo',
    );
    return cardRows(data['accinfo'])
        .map(
          (r) => (
            name: cardText(r['name']),
            balance: cardNumber(r['balance']).toDouble() / 100,
          ),
        )
        .toList();
  }

  Future<CardRecordPage> records(CardRecordKind kind, int page) async {
    if (kind == CardRecordKind.rice) {
      final now = DateTime.now();
      String day(DateTime d) =>
          '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
      final data = _business(
        await _post('/Tsm/GetRiceWate', {
          'account': _info!.account,
          'page': 10,
          'index': page,
          'sdate': day(DateTime(now.year - 1, now.month, now.day)),
          'edate': day(now),
        }),
        'query_mf_xfls',
      );
      final rows = cardRows(data['mfxfls']).map(CardRecord.rice).toList();
      final next = int.tryParse(cardText(data['nextpage']));
      return CardRecordPage(rows, next == null || next == 0 ? null : next);
    }
    final result = cardMap(
      await _post(
        kind == CardRecordKind.transactions
            ? '/Report/GetPersonTrjn'
            : '/Report/GetMyBill',
        {'account': _info!.account, 'page': page},
      ),
    );
    final rows = cardRows(result['rows']).map(CardRecord.fromJson).toList();
    return CardRecordPage(rows, rows.length < 15 ? null : page + 1);
  }

  Future<List<CardBillCategory>> billCategories(String month) async => cardRows(
    await _post('/report/getamtBypaytype', {
      'account': _info!.account,
      'month': month,
    }),
  ).map(CardBillCategory.new).toList();
  Future<List<CardRecord>> categoryRecords(String month, String code) async =>
      cardRows(
        cardMap(
          await _post('/report/getMonthbillBytype', {
            'account': _info!.account,
            'month': month,
            'typeid': code,
          }),
        )['rows'],
      ).map(CardRecord.fromJson).toList();
  Future<Map<String, dynamic>> _electric(
    String name,
    Map<String, dynamic> fields,
  ) async => _business(
    await _post('/Tsm/TsmCommon', {
      'jsondata': jsonEncode({'query_$name': fields}),
      'funname': 'synjones.onecard.query.${name.replaceAll('_', '.')}',
    }),
    'query_$name',
  );
  Future<List<CardChoice>> electricApplications() async => cardRows(
    (await _electric('applist', {'apptype': 'elec'}))['applist'],
  ).map((r) => CardChoice(cardText(r['aid']), cardText(r['name']))).toList();
  Future<List<CardChoice>> electricAreas(CardChoice app) async =>
      cardRows(
            (await _electric('elec_area', {
              'aid': app.id,
              'account': _info!.account,
            }))['areatab'],
          )
          .map((r) => CardChoice(cardText(r['area']), cardText(r['areaname'])))
          .toList();
  Future<List<CardChoice>> electricBuildings(
    CardChoice app,
    CardChoice area,
  ) async =>
      cardRows(
            (await _electric('elec_building', {
              'aid': app.id,
              'account': _info!.account,
              'area': {'area': area.id, 'areaname': area.name},
            }))['buildingtab'],
          )
          .map(
            (r) =>
                CardChoice(cardText(r['buildingid']), cardText(r['building'])),
          )
          .toList();
  Future<CardElectricRoom> electricRoom(
    CardChoice app,
    CardChoice area,
    CardChoice building,
    String room,
  ) async {
    final data = await _electric('elec_roominfo', {
      'aid': app.id,
      'account': _info!.account,
      'area': {'area': area.id, 'areaname': area.name},
      'building': {'buildingid': building.id, 'building': building.name},
      'floor': {'floorid': '', 'floor': ''},
      'room': {'roomid': room, 'room': room},
    });
    final resolved = cardMap(data['room']);
    if (cardText(resolved['roomid']).isEmpty) {
      throw const CampusCardException('未找到该宿舍，请核对房间号');
    }
    return CardElectricRoom(
      application: app,
      area: area,
      building: building,
      id: cardText(resolved['roomid']),
      name: cardText(resolved['room']),
    );
  }

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    if (_writing) throw const CampusCardException('上一项操作尚未结束');
    _writing = true;
    try {
      return await action();
    } finally {
      _writing = false;
    }
  }

  Future<({String key, String publicKey})> _rsa() async {
    final data = cardMap(await _post('/Common/GetRsaKey', {}));
    if (data['IsSucceed'] != true ||
        cardText(data['Obj']).split(',').length != 2) {
      throw const CampusCardException('暂时无法验证密码，请稍后重试');
    }
    return (key: cardText(data['Msg']), publicKey: cardText(data['Obj']));
  }

  Future<void> lose(String password) => _exclusive(() async {
    final rsa = await _rsa();
    _success(
      await _post('/User/LostCard', {
        'acc': _info!.account,
        'pwd': cardEncryptPassword(password, rsa.publicKey),
        'key': rsa.key,
      }, write: true),
    );
  });
  Future<void> sendPasswordCode() => _exclusive(
    () async => _success(
      await _post('/GetPasswd/SendSMS', {'outtime': 120}, write: true),
    ),
  );
  Future<void> changePassword(String password, String code) =>
      _exclusive(() async {
        final rsa = await _rsa();
        _success(
          await _post('/User/MendQueryPasswd', {
            'acc': _info!.account,
            'pwd': '',
            'npwd': cardEncryptPassword(password, rsa.publicKey),
            'vcode': code,
            'key': rsa.key,
          }, write: true),
        );
      });
  void _success(Object? value) {
    if (value is! Map<String, dynamic> || value['IsSucceed'] is! bool) {
      throw const CampusCardWriteUncertain();
    }
    final result = value;
    if (result['IsSucceed'] != true) {
      throw CampusCardException(
        cardText(result['Msg']).isEmpty
            ? '学校未通过本次操作，请更新后重试'
            : cardText(result['Msg']),
      );
    }
  }

  void _checkAmount(int cents) {
    if (cents < 1 || cents > 999900) {
      throw const CampusCardException('充值金额须在0.01至9999元之间');
    }
  }

  Future<CardPaymentOrder> recharge(int cents) => _exclusive(() async {
    _checkAmount(cents);
    final result = await _post('/User/Account_Pay', {
      'account': _info!.account,
      'acctype': '###',
      'tranamt': cents,
      'objtype': 'own',
      'paytype': 'alipay',
      'client_type': 'wap',
      'qpwd': '',
      'paymethod': '4',
      'iacctype': 'acc',
      'spbill_create_ip': '',
      'bpwd': '',
      'key': '',
      'cardbagpay': '',
      'thirdapp': '',
      'iswap': '0',
    }, write: true);
    _success(result);
    return cardPaymentOrder(cardMap(result));
  });
  Future<({String key, String signature, String time})>
  _electricOrderContext() async {
    final html = await _formDocument('/Page/Page', {
      'flowID': '31',
      'type': '3',
      'apptype': '2',
      'Url': '',
      'MenuName': '交电费',
      'EMenuName': 'Electricity',
      'parm11': '',
      'parm22': '',
      'comeapp': '0',
    });
    final start = html.indexOf('function SaveOrder(');
    if (start < 0) throw const CampusCardException('暂时无法准备电费缴费，请稍后重试');
    final save = html.substring(start);
    final key = RegExp(
      r"mm\.keyvalue\s*=\s*'([^']+)'",
    ).firstMatch(save)?.group(1);
    final signature = RegExp(
      r"mm\.sign\s*=\s*'([^']+)'",
    ).firstMatch(save)?.group(1);
    final time = RegExp(
      r"var timenow\s*=\s*'([^']+)'",
    ).firstMatch(html)?.group(1);
    final account =
        RegExp(r"var account1\s*=\s*'([^']+)'").firstMatch(html)?.group(1) ??
        RegExp(r"account1\s*=\s*'([^']+)'").firstMatch(html)?.group(1);
    if (key == null ||
        signature == null ||
        time == null ||
        account != _info!.account) {
      throw const CampusCardException('电费缴费配置与当前账户不一致，请重新打开');
    }
    return (key: key, signature: signature, time: time);
  }

  Future<CardPaymentOrder> payElectricity(
    CardElectricRoom room,
    int cents,
  ) => _exclusive(() async {
    _checkAmount(cents);
    final context = await _electricOrderContext();
    final checked = await electricRoom(
      room.application,
      room.area,
      room.building,
      room.id,
    );
    final result = cardMap(
      await _post('/Tsm/Elec_Pay_Gateway', {
        'client_type': 'wap',
        'pay_type': 'alipay',
        'account': _info!.account,
        'acctype': '###',
        'order_no': '',
        'order_amount': cents,
        'order_time': '',
        'order_note': '电控缴费',
        'aic_note': '',
        'return_url': '',
        'notify_url': '',
        'openid': '',
        ...checked.paymentFields,
      }, write: true),
    );
    _success(result);
    late Map<String, dynamic> payment;
    try {
      payment = cardMap(cardMap(result['Obj'])['pay_elec_paygw_apply']);
    } on FormatException {
      throw const CampusCardWriteUncertain();
    }
    final orderNo = cardText(payment['order_no']);
    if (cardText(payment['retcode']) != '0' || orderNo.isEmpty) {
      throw const CampusCardWriteUncertain();
    }
    // The official electricity flow records this order's room metadata using a
    // page-scoped grant. Never persist or hard-code the grant, nor expose a
    // general table-update API to callers.
    try {
      _success(
        await _post('/T_Json/UpdataColsByJson', {
          'table': 's_h_order',
          'cols':
              'ORDERID-STATUS-PARM2-PARM3-PARM4-PARM7-PARM8-PARM9-PARM10-PARM11',
          'colvalue': [
            orderNo,
            '1',
            _info!.account,
            checked.application.id,
            checked.area.name,
            checked.building.name,
            checked.id,
            '$cents',
            context.time,
            '###',
          ].join('-'),
          'key': 'PARM1',
          'keyvalue': context.key,
          'con': '',
          'sign': context.signature,
        }, write: true),
      );
    } catch (_) {
      throw const CampusCardWriteUncertain();
    }
    return cardPaymentOrder({...result, 'OrderID': orderNo});
  });
}

String cardEncryptPassword(String value, String publicKey) {
  final parts = publicKey.split(',');
  final rng = Random.secure();
  final random = FortunaRandom()
    ..seed(
      KeyParameter(
        Uint8List.fromList(List.generate(32, (_) => rng.nextInt(256))),
      ),
    );
  final cipher = PKCS1Encoding(RSAEngine())
    ..init(
      true,
      ParametersWithRandom(
        PublicKeyParameter<RSAPublicKey>(
          RSAPublicKey(
            BigInt.parse(parts[1], radix: 16),
            BigInt.parse(parts[0], radix: 16),
          ),
        ),
        random,
      ),
    );
  return cipher
      .process(Uint8List.fromList(utf8.encode(value)))
      .map((v) => v.toRadixString(16).padLeft(2, '0'))
      .join();
}

String _htmlText(String raw) => raw.replaceAllMapped(
  RegExp(r'&(?:amp|quot|apos|lt|gt|#39|#\d+|#x[0-9a-fA-F]+);'),
  (match) {
    final entity = match.group(0)!;
    const named = {
      '&amp;': '&',
      '&quot;': '"',
      '&apos;': "'",
      '&lt;': '<',
      '&gt;': '>',
    };
    if (named.containsKey(entity)) return named[entity]!;
    final hex = entity.startsWith('&#x');
    return String.fromCharCode(
      int.parse(
        entity.substring(hex ? 3 : 2, entity.length - 1),
        radix: hex ? 16 : 10,
      ),
    );
  },
);

CardPaymentOrder cardPaymentOrder(Map<String, dynamic> data) {
  var value = cardText(data['Msg']);
  if (data['Obj'] == 'form') {
    try {
      value = utf8.decode(base64Decode(value));
    } catch (_) {
      throw const CampusCardWriteUncertain();
    }
  }
  Uri? uri = Uri.tryParse(_htmlText(value));
  if (RegExp(r'<form\b', caseSensitive: false).hasMatch(value)) {
    final action = RegExp(
      r'''<form\b[^>]*\baction\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(value)?.group(1);
    if (action == null) throw const CampusCardWriteUncertain();
    final fields = <String, String>{};
    for (final input in RegExp(
      r'<input\b[^>]*>',
      caseSensitive: false,
    ).allMatches(value)) {
      final attrs = {
        for (final match in RegExp(
          r'''([\w-]+)\s*=\s*(["'])(.*?)\2''',
        ).allMatches(input.group(0)!))
          match[1]!.toLowerCase(): _htmlText(match[3]!),
      };
      if (attrs['name'] != null) fields[attrs['name']!] = attrs['value'] ?? '';
    }
    final actionUri = Uri.tryParse(_htmlText(action));
    uri = actionUri?.replace(
      queryParameters: {...actionUri.queryParameters, ...fields},
    );
  }
  if (uri == null ||
      uri.scheme != 'https' ||
      !(uri.host == 'alipay.com' || uri.host.endsWith('.alipay.com'))) {
    throw const CampusCardWriteUncertain();
  }
  return CardPaymentOrder(uri, cardText(data['OrderID']));
}
