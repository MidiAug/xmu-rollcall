import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'browser_session.dart';
import 'browser_environment.dart';
import 'browser_preferences.dart';

bool isWebPageUrl(Uri uri) =>
    const {'http', 'https'}.contains(uri.scheme) &&
    uri.host.isNotEmpty &&
    uri.userInfo.isEmpty;

class CampusWebPage extends ConsumerStatefulWidget {
  const CampusWebPage({
    super.key,
    required this.title,
    required this.url,
    this.completeAuthorization,
  });
  final String title;
  final Uri url;

  /// A login-only consumer can finish before navigating to business content.
  /// Null means this URL is still part of authorization; true means connected.
  final Future<bool?> Function(Uri, CookieManager)? completeAuthorization;
  @override
  ConsumerState<CampusWebPage> createState() => _CampusWebPageState();
}

class _CampusWebPageState extends ConsumerState<CampusWebPage> {
  late final BrowserIdentity _identity;
  WebViewEnvironment? _environment;
  InAppWebViewController? _controller;
  bool _ready = false;
  bool _preparing = false;
  String? _error;
  late String _title;
  double _progress = 0;
  bool _checkingAuthorization = false;

  Future<bool> _finishAuthorization(Uri uri) async {
    final complete = widget.completeAuthorization;
    if (complete == null || _checkingAuthorization || !_current) return false;
    _checkingAuthorization = true;
    try {
      final done = await complete(
        uri,
        CookieManager.instance(webViewEnvironment: _environment),
      );
      if (done == true && mounted && _current) {
        Navigator.of(context).pop(true);
        return true;
      }
      return false;
    } catch (e) {
      if (_current) {
        setState(() => _error = e is FormatException ? e.message : '授权未完成，请重试');
      }
      return true;
    } finally {
      _checkingAuthorization = false;
    }
  }

  @override
  void initState() {
    super.initState();
    // Plugin debug callbacks include full redirect URLs, which can contain CAS
    // tickets. Browser diagnostics must not print those URLs or JS console data.
    PlatformInAppWebViewController.debugLoggingSettings.enabled = false;
    PlatformWebViewEnvironment.debugLoggingSettings.enabled = false;
    _identity = ref.read(browserIdentityProvider);
    _title = widget.title;
    unawaited(_prepare());
  }

  bool get _current =>
      mounted && ref.read(browserIdentityProvider) == _identity;

  Future<void> _prepare() async {
    if (_preparing) return;
    _preparing = true;
    try {
      if (!isWebPageUrl(widget.url)) {
        throw const FormatException('Invalid website URL');
      }
      final environment = await ref.read(
        browserEnvironmentProvider(browserProfileName(_identity)).future,
      );
      if (!_current) return;
      _environment = environment;
      final cookies = await ref.read(idsBrowserCookiesProvider.future);
      if (!_current) return;
      final manager = CookieManager.instance(webViewEnvironment: environment);
      // Never replace a newer browser SSO session with an older HTTP session.
      if (await manager.getCookie(
            url: WebUri('https://ids.xmu.edu.cn/authserver/'),
            name: 'CASTGC',
          ) ==
          null) {
        for (final cookie in cookies) {
          if (!_current) return;
          final expires =
              cookie.expires ??
              (cookie.maxAge == null
                  ? null
                  : DateTime.now().add(Duration(seconds: cookie.maxAge!)));
          await manager.setCookie(
            url: WebUri('https://ids.xmu.edu.cn/authserver/'),
            name: cookie.name,
            value: cookie.value,
            path: cookie.path ?? '/',
            isSecure: cookie.secure,
            isHttpOnly: cookie.httpOnly,
            expiresDate: expires?.millisecondsSinceEpoch,
          );
        }
      }
      if (_current) {
        setState(() {
          _ready = true;
          _error = null;
        });
      }
    } catch (_) {
      if (_current) {
        setState(() => _error = '内置网页暂时无法启动，请重试或使用系统浏览器');
      }
    } finally {
      _preparing = false;
    }
  }

  Future<void> _external(Uri uri) async {
    try {
      if (await ref.read(websiteExternalLauncherProvider)(uri)) return;
    } catch (_) {}
    if (mounted && _current) AppToast.show(context, '无法打开系统浏览器');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(browserIdentityProvider, (_, next) {
      if (next == _identity) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final route = ModalRoute.of(context);
        if (route != null && route.isActive) {
          Navigator.of(context).removeRoute(route);
        }
      });
    });
    final p = AppPalette.of(context);
    return CampusWebFrame(
      title: _title,
      onBack: () => Navigator.of(context).pop(),
      child: Stack(
        children: [
          if (_ready)
            InAppWebView(
              webViewEnvironment: _environment,
              initialUrlRequest: URLRequest(url: WebUri(widget.url.toString())),
              initialSettings: InAppWebViewSettings(
                useShouldOverrideUrlLoading: true,
                supportMultipleWindows: true,
                javaScriptCanOpenWindowsAutomatically: false,
                isInspectable: false,
              ),
              onWebViewCreated: (controller) => _controller = controller,
              onTitleChanged: (_, title) {
                if (_current && widget.completeAuthorization == null) {
                  setState(
                    () => _title = title?.trim().isNotEmpty == true
                        ? title!
                        : widget.title,
                  );
                }
              },
              onProgressChanged: (_, value) {
                if (_current) setState(() => _progress = value / 100);
              },
              onLoadStart: (_, _) {
                if (_current) {
                  setState(() {
                    _progress = 0;
                    _error = null;
                  });
                }
              },
              onLoadStop: (_, url) async {
                final uri = Uri.tryParse(url?.toString() ?? '');
                if (uri != null && await _finishAuthorization(uri)) return;
                if (_current) setState(() => _progress = 1);
              },
              onReceivedError: (_, request, error) {
                if (_current &&
                    request.isForMainFrame == true &&
                    !error.description.contains('ERR_ABORTED')) {
                  setState(() => _error = '网页未能加载，请检查网络后重试');
                }
              },
              shouldOverrideUrlLoading: (_, action) async {
                if (!_current) return NavigationActionPolicy.CANCEL;
                final uri = Uri.tryParse(action.request.url?.toString() ?? '');
                if (uri != null && await _finishAuthorization(uri)) {
                  return NavigationActionPolicy.CANCEL;
                }
                if (uri != null && isWebPageUrl(uri)) {
                  return NavigationActionPolicy.ALLOW;
                }
                if (uri != null &&
                    const {'mailto', 'tel'}.contains(uri.scheme)) {
                  await _external(uri);
                }
                return NavigationActionPolicy.CANCEL;
              },
              onCreateWindow: (controller, action) async {
                final uri = Uri.tryParse(action.request.url?.toString() ?? '');
                if (_current && uri != null && isWebPageUrl(uri)) {
                  await controller.loadUrl(
                    urlRequest: URLRequest(url: WebUri(uri.toString())),
                  );
                }
                return false;
              },
            ),
          if (!_ready && _error == null)
            const Center(child: CircularProgressIndicator()),
          if (_ready && _progress < 1 && _error == null)
            Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(
                value: _progress == 0 ? null : _progress,
                minHeight: 2,
              ),
            ),
          if (_error != null)
            Positioned.fill(
              child: ColoredBox(
                color: p.canvas,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            AppButton(
                              label: '重试',
                              onPressed: () {
                                setState(() => _error = null);
                                if (_ready) {
                                  unawaited(_controller?.reload());
                                } else {
                                  ref.invalidate(
                                    browserEnvironmentProvider(
                                      browserProfileName(_identity),
                                    ),
                                  );
                                  unawaited(_prepare());
                                }
                              },
                            ),
                            AppButton(
                              kind: AppButtonKind.secondary,
                              label: '系统浏览器打开',
                              onPressed: () => _external(widget.url),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Full-window website chrome. The left arrow always returns to the app,
/// independent of the web page's own back/forward history.
class CampusWebFrame extends StatelessWidget {
  const CampusWebFrame({
    super.key,
    required this.title,
    required this.onBack,
    required this.child,
  });
  final String title;
  final VoidCallback onBack;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        AppTitleBar(title: title, onBack: onBack),
        Expanded(child: child),
      ],
    ),
  );
}
