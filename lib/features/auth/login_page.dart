import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:xmu_rollcall/core/network/tron_endpoints.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';

/// WebView OAuth login; falls back to cookie paste when WebView is unavailable.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  WebViewController? _controller;
  bool _webViewFailed = false;
  bool _finishing = false;
  int _progress = 0;
  final _cookieCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bootWebView();
  }

  @override
  void dispose() {
    _cookieCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootWebView() async {
    // webview_flutter: Android / iOS / macOS. Windows/Linux → cookie fallback.
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      setState(() => _webViewFailed = true);
      return;
    }

    try {
      await WebViewCookieManager().clearCookies();
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent(TronEndpoints.userAgent)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (p) {
              if (mounted) setState(() => _progress = p);
            },
            onNavigationRequest: (req) {
              if (_handleCallback(req.url)) {
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
            onPageStarted: (url) => _handleCallback(url),
            onPageFinished: (url) => _handleCallback(url),
            onWebResourceError: (_) {
              if (mounted) setState(() => _webViewFailed = true);
            },
          ),
        );
      await controller.loadRequest(TronEndpoints.oauthAuthorizeUri());
      if (!mounted) return;
      setState(() => _controller = controller);
    } catch (_) {
      if (mounted) setState(() => _webViewFailed = true);
    }
  }

  bool _handleCallback(String url) {
    if (_finishing) return true;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final isCallback = uri.host.contains('c-mobile.xmu.edu.cn') &&
        uri.path.contains('identity-web-login-callback');
    final code = uri.queryParameters['code'];
    if (!isCallback || code == null || code.isEmpty) return false;
    _finishing = true;
    _finishWithCode(code);
    return true;
  }

  Future<void> _finishWithCode(String code) async {
    try {
      await ref.read(authControllerProvider.notifier).completeOAuthCode(code);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登录失败：$e')),
      );
      setState(() {
        _finishing = false;
        _webViewFailed = true;
      });
    }
  }

  Future<void> _openInBrowser() async {
    final uri = TronEndpoints.oauthAuthorizeUri();
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _submitCookies() async {
    final raw = _cookieCtrl.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请粘贴 Cookie')),
      );
      return;
    }
    try {
      await ref.read(authControllerProvider.notifier).importCookies(raw);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('会话无效：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final loading = auth.status == AuthStatus.loading || _finishing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('登录畅课'),
        actions: [
          if (!_webViewFailed)
            TextButton(
              onPressed: () => setState(() => _webViewFailed = true),
              child: const Text('改用 Cookie'),
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : _webViewFailed
              ? _buildFallback(context)
              : _controller == null
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        if (_progress < 100)
                          LinearProgressIndicator(value: _progress / 100),
                        Expanded(child: WebViewWidget(controller: _controller!)),
                      ],
                    ),
    );
  }

  Widget _buildFallback(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '当前平台未使用内嵌 WebView。可在浏览器完成 IDS 登录后，从开发者工具复制 `lnt.xmu.edu.cn` 的 Cookie 粘贴到下方。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _openInBrowser,
          icon: const Icon(Icons.open_in_browser),
          label: const Text('打开授权页'),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _cookieCtrl,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Cookie',
            hintText: 'name=value; name2=value2',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _submitCookies,
          child: const Text('导入并验证会话'),
        ),
        if (ref.watch(authControllerProvider).errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            ref.watch(authControllerProvider).errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}
