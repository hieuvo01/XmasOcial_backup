// File: lib/screens/settings/two_factor_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_config.dart';

class TwoFactorScreen extends StatefulWidget {
  const TwoFactorScreen({super.key});

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  String? qrCodeBase64;
  String? secretKey;
  final TextEditingController _otpController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _generate2FA();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  // 1. Gọi API lấy QR Code
  Future<void> _generate2FA() async {
    setState(() => isLoading = true);
    try {
      final token = await _getToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Bạn chưa đăng nhập!")),
          );
        }
        return;
      }

      final url = Uri.parse('${AppConfig.baseUrl}/api/users/2fa/generate');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            String rawQr = data['qrCode'].toString();
            if (rawQr.contains(',')) {
              qrCodeBase64 = rawQr.split(',').last;
            } else {
              qrCodeBase64 = rawQr;
            }
            secretKey = data['secret'];
          });
        }
      } else {
        print("Lỗi generate: ${response.body}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // 2. Gọi API xác thực OTP
  Future<void> _verifyOTP() async {
    if (_otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập 6 số")),
      );
      return;
    }

    try {
      final token = await _getToken();
      if (token == null) return;

      final url = Uri.parse('${AppConfig.baseUrl}/api/users/2fa/verify');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'token': _otpController.text,
          'secret': secretKey,
        }),
      );

      final data = jsonDecode(response.body);
      if (mounted) {
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Thành công! Đã bật 2FA")),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("❌ Mã sai rồi bro ơi!")),
          );
        }
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lấy thông tin theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final cardColor = Theme.of(context).cardColor;

    return Scaffold(
      appBar: AppBar(title: const Text("Bảo mật 2 lớp (2FA)")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              "Quét mã này bằng ứng dụng Google Authenticator:",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: textColor),
            ),
            const SizedBox(height: 20),

            // Hiển thị QR Code
            isLoading
                ? const CircularProgressIndicator()
                : qrCodeBase64 != null
                ? Container(
              // ⚠️ QUAN TRỌNG: Thêm nền trắng để QR code luôn quét được
              // kể cả khi app đang ở Dark Mode
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ]
              ),
              child: Image.memory(
                base64Decode(qrCodeBase64!),
                width: 200,
                height: 200,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                const Text("Lỗi hiển thị ảnh", style: TextStyle(color: Colors.black)),
              ),
            )
                : Text("Không tải được mã QR", style: TextStyle(color: textColor)),

            const SizedBox(height: 24),

            if (secretKey != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  // Dùng màu card của theme hoặc màu xám nhẹ linh hoạt
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.white24 : Colors.grey[300]!,
                    )
                ),
                child: Column(
                  children: [
                    Text(
                      "Mã nhập thủ công:",
                      style: TextStyle(fontSize: 14, color: textColor?.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      secretKey!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.primary, // Dùng màu chính của App
                          letterSpacing: 1.2
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 30),
            Text("Nhập 6 số từ ứng dụng:", style: TextStyle(color: textColor)),
            const SizedBox(height: 10),

            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: TextStyle(fontSize: 24, letterSpacing: 10, color: textColor),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey[400]!),
                ),
                hintText: "000000",
                hintStyle: TextStyle(color: Colors.grey[500]),
                counterText: "", // Ẩn số đếm ký tự
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _verifyOTP,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  // Nút dùng màu Primary của theme, chữ màu tương phản
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)
                  )
              ),
              child: const Text("KÍCH HOẠT", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
