import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Launches the signed payment-provider cashier returned by the native card
/// client. No school business page or WebView participates in this transition.
final campusCardCashierLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) => launchNativeCardCashier,
);
Future<bool> launchNativeCardCashier(Uri cashier) async {
  if (cashier.scheme != 'https' ||
      !(cashier.host == 'alipay.com' || cashier.host.endsWith('.alipay.com'))) {
    return false;
  }
  final app = Uri.parse(
    'alipays://platformapi/startapp',
  ).replace(queryParameters: {'appId': '20000067', 'url': cashier.toString()});
  if ((Platform.isAndroid || Platform.isIOS) && await _open(app)) return true;
  if (await _open(cashier)) return true;
  return _open(app);
}

Future<bool> _open(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
