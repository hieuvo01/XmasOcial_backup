// File: lib/screens/settings/change_password_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_config.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _isLoading = false;

  // Trạng thái ẩn/hiện password cho từng ô
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  // Hàm lấy token
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  // 👇 HÀM CHECK ĐỘ MẠNH MẬT KHẨU (Nâng cấp)
  bool _isPasswordStrong(String password) {
    // Regex: Tối thiểu 8 ký tự, ít nhất 1 chữ thường, 1 chữ hoa, 1 số
    // Nếu muốn bắt buộc ký tự đặc biệt thì thêm (?=.*[@$!%*?&])
    final regex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$');
    return regex.hasMatch(password);
  }

  Future<void> _changePassword() async {
    // Lấy giá trị và cắt khoảng trắng thừa
    final oldPass = _oldPassController.text.trim();
    final newPass = _newPassController.text.trim();
    final confirmPass = _confirmPassController.text.trim();

    // 1. Validate Rỗng
    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập đầy đủ thông tin")),
      );
      return;
    }

    // 2. Validate Khớp lệnh
    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mật khẩu xác nhận không khớp")),
      );
      return;
    }

    // 3. Validate Trùng mật khẩu cũ (Nên chặn luôn từ client)
    if (newPass == oldPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mật khẩu mới không được trùng với mật khẩu cũ")),
      );
      return;
    }

    // 4. Validate Độ mạnh (Logic mới)
    if (!_isPasswordStrong(newPass)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Mật khẩu mới phải có ít nhất 8 ký tự, bao gồm chữ hoa và số."),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await _getToken();
      if (token == null) return;

      final url = Uri.parse('${AppConfig.baseUrl}/api/users/profile/password');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'oldPassword': oldPass,
          'newPassword': newPass,
        }),
      );

      final data = jsonDecode(response.body);

      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Đổi mật khẩu thành công!")),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? "Lỗi đổi mật khẩu")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi kết nối: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Đổi mật khẩu")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Ô nhập Pass cũ
            _buildPasswordField(
              label: "Mật khẩu hiện tại",
              controller: _oldPassController,
              obscureText: _obscureOld,
              onToggleVisibility: () => setState(() => _obscureOld = !_obscureOld),
            ),
            const SizedBox(height: 16),

            // Ô nhập Pass mới
            _buildPasswordField(
              label: "Mật khẩu mới",
              controller: _newPassController,
              obscureText: _obscureNew,
              onToggleVisibility: () => setState(() => _obscureNew = !_obscureNew),
              helperText: "Tối thiểu 8 ký tự, gồm chữ hoa và số",
            ),
            const SizedBox(height: 16),

            // Ô nhập Confirm Pass
            _buildPasswordField(
              label: "Xác nhận mật khẩu mới",
              controller: _confirmPassController,
              obscureText: _obscureConfirm,
              onToggleVisibility: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading ? null : _changePassword,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("CẬP NHẬT MẬT KHẨU"),
            ),
          ],
        ),
      ),
    );
  }

  // Widget TextField có nút ẩn/hiện password
  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    String? helperText,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText, // Hiển thị gợi ý dưới input
        helperStyle: const TextStyle(color: Colors.grey, fontSize: 12),
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.lock_outline),
        // Nút con mắt
        suffixIcon: IconButton(
          icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggleVisibility,
        ),
      ),
    );
  }
}
