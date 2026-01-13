// File: lib/screens/auth/forgot_password_screen.dart

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Controller
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passController = TextEditingController();

  // State
  int _step = 1; // 1: Nhập Email, 2: Nhập OTP & Pass mới
  bool _isLoading = false;

  // Bước 1: Gửi yêu cầu OTP
  Future<void> _sendOtp() async {
    if (_emailController.text.isEmpty || !_emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email không hợp lệ")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/api/users/forgot-password');
      print("📡 Đang gửi yêu cầu tới: $url"); // Log để kiểm tra URL

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailController.text.trim()}),
      ).timeout(const Duration(seconds: 60)); // 🔥 Tăng lên 60 giây để đợi Render khởi động// ⏱️ Thêm timeout 10 giây

      print("📡 Status Code: ${response.statusCode}");
      print("📡 Response Body: ${response.body}");

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? "Mã đã gửi!")));
        setState(() => _step = 2);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? "Lỗi từ server")));
      }
    } on TimeoutException catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kết nối quá hạn. Vui lòng kiểm tra Server!")));
    } catch (e) {
      print("❌ Lỗi cụ thể: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Bước 2: Đặt lại mật khẩu
  Future<void> _resetPassword() async {
    if (_otpController.text.length < 6 || _passController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập đủ thông tin")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/api/users/reset-password');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'otp': _otpController.text.trim(),
          'password': _passController.text.trim()
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Thành công -> Quay về màn hình Login
        if (mounted) {
          showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("Thành công"),
                content: const Text("Mật khẩu đã được đổi. Vui lòng đăng nhập lại."),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.pop(ctx); // Đóng Dialog
                        Navigator.pop(context); // Đóng ForgotScreen về Login
                      },
                      child: const Text("OK")
                  )
                ],
              )
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? "Lỗi đổi mật khẩu")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Quên mật khẩu")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock_reset, size: 80, color: Colors.blue),
            const SizedBox(height: 20),

            if (_step == 1) ...[
              const Text("Nhập email để nhận mã OTP:", style: TextStyle(fontSize: 16)),
              const SizedBox(height: 10),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _sendOtp,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("GỬI MÃ OTP", style: TextStyle(fontSize: 16)),
              ),
            ] else ...[
              Text("Đã gửi mã đến: ${_emailController.text}", style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              TextField(
                controller: _otpController,
                decoration: const InputDecoration(
                  labelText: "Nhập mã OTP (6 số)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.vpn_key),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _passController,
                decoration: const InputDecoration(
                  labelText: "Mật khẩu mới",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _resetPassword,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16), backgroundColor: Colors.green),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("ĐỔI MẬT KHẨU", style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
              TextButton(
                  onPressed: () => setState(() => _step = 1),
                  child: const Text("Gửi lại mã?")
              )
            ]
          ],
        ),
      ),
    );
  }
}
