import 'dart:convert';

Object? cardDecode(Object? value) {
  if (value is! String) return value;
  try {
    return jsonDecode(value);
  } catch (_) {
    throw const FormatException('校园卡返回的数据无法读取');
  }
}

Map<String, dynamic> cardMap(Object? value) {
  final data = cardDecode(value);
  if (data is! Map<String, dynamic>) throw const FormatException('校园卡返回格式异常');
  return data;
}

String cardText(Object? value) => value == null ? '' : '$value'.trim();
num cardNumber(Object? value) {
  final result = value is num ? value : num.tryParse(cardText(value));
  if (result == null || !result.isFinite) {
    throw const FormatException('校园卡金额格式异常');
  }
  return result;
}

int cardCents(Object? value) {
  final amount = cardNumber(value);
  if (amount != amount.truncateToDouble()) {
    throw const FormatException('校园卡金额单位异常');
  }
  return amount.toInt();
}

List<Map<String, dynamic>> cardRows(Object? value) {
  if (value is! List) throw const FormatException('校园卡列表格式异常');
  return value.map((row) => Map<String, dynamic>.from(row as Map)).toList();
}

class CampusCardInfo {
  const CampusCardInfo({
    required this.account,
    required this.cardName,
    required this.balanceCents,
    required this.unsettledCents,
    required this.electricityCents,
    required this.expiryDate,
    required this.createdDate,
    required this.lost,
    required this.frozen,
    this.studentNo = '',
  });
  final String account, cardName, expiryDate, createdDate, studentNo;
  final int balanceCents, unsettledCents, electricityCents;
  final bool lost, frozen;
  double get balanceYuan => balanceCents / 100;
  double get electricityYuan => electricityCents / 100;
  factory CampusCardInfo.fromCardJson(Map<String, dynamic> row) {
    final account = cardText(row['account']);
    if (account.isEmpty) throw const FormatException('未返回校园卡账户');
    bool flag(String key) {
      final value = cardText(row[key]);
      if (!const {'0', '1'}.contains(value)) {
        throw const FormatException('校园卡状态字段缺失');
      }
      return value == '1';
    }

    return CampusCardInfo(
      account: account,
      cardName: cardText(row['cardname']),
      balanceCents: cardCents(row['db_balance']),
      unsettledCents: cardCents(row['unsettle_amount']),
      electricityCents: cardCents(row['elec_accamt']),
      expiryDate: cardText(row['expdate']),
      createdDate: cardText(row['createdate']),
      studentNo: cardText(row['sno']),
      lost: flag('lostflag'),
      frozen: flag('freezeflag'),
    );
  }
  Map<String, dynamic> toJson() => {
    'account': account,
    'cardname': cardName,
    'db_balance': balanceCents,
    'unsettle_amount': unsettledCents,
    'elec_accamt': electricityCents,
    'expdate': expiryDate,
    'createdate': createdDate,
    'sno': studentNo,
    'lostflag': lost ? '1' : '0',
    'freezeflag': frozen ? '1' : '0',
  };
}

class CampusCardException extends FormatException {
  const CampusCardException(super.message);
}

class CampusCardWriteUncertain extends CampusCardException {
  const CampusCardWriteUncertain() : super('未能确认操作结果，请先核对账户或记录，避免重复提交');
}

CampusCardInfo? parseCardInfoResponse(Object? payload) {
  final outer = cardMap(payload);
  final raw = outer['Msg'] ?? outer['msg'];
  if (raw == null) return null;
  final root = cardMap(raw)['query_card'];
  if (root == null) return null;
  final data = cardMap(root);
  if (cardText(data['retcode']) != '0') {
    throw CampusCardException(cardText(data['errmsg']));
  }
  final rows = cardRows(data['card']);
  return rows.isEmpty ? null : CampusCardInfo.fromCardJson(rows.first);
}

class CardRecord {
  const CardRecord({
    required this.title,
    required this.kind,
    required this.time,
    required this.amount,
    this.balance,
    this.note = '',
    this.number = '',
  });
  factory CardRecord.fromJson(Map<String, dynamic> row) => CardRecord(
    title: cardText(row['MERCNAME']),
    kind: cardText(row['TRANNAME']),
    time: cardText(row['OCCTIME']),
    amount: cardNumber(row['TRANAMT']).toDouble(),
    balance: row['CARDBAL'] == null
        ? null
        : cardNumber(row['CARDBAL']).toDouble(),
    note: cardText(row['JDESC']),
    number: cardText(row['JNUM']),
  );
  factory CardRecord.rice(Map<String, dynamic> row) {
    final day = cardText(row['tradedate']),
        clock = cardText(row['tradetime']).padLeft(6, '0');
    return CardRecord(
      title: cardText(row['mercname']),
      kind: '免费米饭',
      amount: cardNumber(row['tranamt']).toDouble(),
      time: day.length == 8 && clock.length == 6
          ? '${day.substring(0, 4)}-${day.substring(4, 6)}-${day.substring(6)} ${clock.substring(0, 2)}:${clock.substring(2, 4)}:${clock.substring(4)}'
          : '$day $clock',
    );
  }
  final String title, kind, time, note, number;
  String get day => time.length >= 10 ? time.substring(0, 10) : '日期未知';
  String get clock => time.length >= 16 ? time.substring(11, 16) : time;
  final double amount;
  final double? balance;
}

enum CardRecordKind { transactions, bills, rice }

class CardRecordPage {
  const CardRecordPage(this.rows, this.nextPage);
  final List<CardRecord> rows;
  final int? nextPage;
}

class CardBillCategory {
  CardBillCategory(Map<String, dynamic> row)
    : code = cardText(row['code']),
      name = cardText(row['name']),
      amount = cardNumber(row['value']).toDouble();
  final String code, name;
  final double amount;
}

class CardChoice {
  const CardChoice(this.id, this.name);
  final String id, name;
  List<String> get path {
    final match = RegExp(r'^(思明|翔安|漳州)(?:校区)?(.*)$').firstMatch(name);
    return match == null || match[2]!.isEmpty
        ? [name]
        : ['${match[1]}校区', match[2]!];
  }
}

enum CardElectricRoomKind {
  personal('个人房间'),
  shared('公共客厅');

  const CardElectricRoomKind(this.label);
  final String label;
}

class CardElectricRoom {
  const CardElectricRoom({
    required this.application,
    required this.area,
    required this.building,
    required this.id,
    required this.name,
  });
  final CardChoice application, area, building;
  final String id, name;
  String get address => '${area.name} ${building.name} $name';
  Map<String, dynamic> toJson() => {
    'application': {'id': application.id, 'name': application.name},
    'area': {'id': area.id, 'name': area.name},
    'building': {'id': building.id, 'name': building.name},
    'id': id,
    'name': name,
  };
  factory CardElectricRoom.fromJson(Map<String, dynamic> json) {
    CardChoice choice(String key) {
      final row = cardMap(json[key]);
      final id = cardText(row['id']), name = cardText(row['name']);
      if (id.isEmpty || name.isEmpty) throw const FormatException('宿舍记录不完整');
      return CardChoice(id, name);
    }

    final id = cardText(json['id']), name = cardText(json['name']);
    if (id.isEmpty || name.isEmpty) throw const FormatException('宿舍记录不完整');
    return CardElectricRoom(
      application: choice('application'),
      area: choice('area'),
      building: choice('building'),
      id: id,
      name: name,
    );
  }
  Map<String, String> get paymentFields => {
    'aid': application.id,
    'areaid': area.id,
    'areaname': area.name,
    'buildingid': building.id,
    'building': building.name,
    'floorid': '',
    'floor': '',
    'roomid': id,
    'room': name,
  };
}

class CardPaymentOrder {
  const CardPaymentOrder(this.cashier, this.id);
  final Uri cashier;
  final String id;
}

String cardDate(String raw) => raw.length == 8
    ? '${raw.substring(0, 4)}-${raw.substring(4, 6)}-${raw.substring(6)}'
    : raw;
String? cardRequired(String? value) =>
    value == null || value.trim().isEmpty ? '请填写此项' : null;
String? cardPassword(String? value) =>
    RegExp(r'^\d{6}$').hasMatch(value ?? '') ? null : '请输入六位数字密码';
int? cardAmountCents(String text) {
  if (!RegExp(r'^\d{1,4}(\.\d{1,2})?$').hasMatch(text.trim())) return null;
  final parts = text.trim().split('.');
  final cents =
      int.parse(parts[0]) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
  return cents > 0 && cents <= 999900 ? cents : null;
}
