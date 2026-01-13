// File: lib/screens/auth/github_webview.dart

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class GithubLoginWebView extends StatefulWidget {
  final String authUrl;
  // Bỏ redirectUri ở đây đi vì mình check cứng trong code rồi
  const GithubLoginWebView({super.key, required this.authUrl});

  @override
  State<GithubLoginWebView> createState() => _GithubLoginWebViewState();
}

class _GithubLoginWebViewState extends State<GithubLoginWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36") // Fake user agent để GitHub không chặn
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            print("WebView đang load: ${request.url}"); // In log để debug

            // 👇 LOGIC MỚI: Bắt bất kỳ link nào có chứa "code="
            if (request.url.contains("code=")) {
              final uri = Uri.parse(request.url);
              final code = uri.queryParameters['code'];

              if (code != null) {
                print("✅ Đã bắt được code: $code");
                // Đóng WebView và trả về code
                if (mounted) {
                  Navigator.of(context).pop(code);
                }
                return NavigationDecision.prevent; // Chặn không cho load tiếp
              }
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Đăng nhập GitHub")),
      body: WebViewWidget(controller: _controller),
    );
  }
}
