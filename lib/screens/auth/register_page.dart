// File: lib/screens/auth/register_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';


class RegisterPage extends StatefulWidget {
  final void Function()? onTap;
  const RegisterPage({super.key, required this.onTap});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // State quản lý ẩn/hiện mật khẩu
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Helper: Regex check password mạnh
  bool _isPasswordStrong(String password) {
    // Tối thiểu 8 ký tự, 1 hoa, 1 thường, 1 số
    final regex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$');
    return regex.hasMatch(password);
  }

  // Helper: Regex check Username (chỉ chữ, số, gạch dưới, không dấu cách)
  bool _isValidUsername(String username) {
    final regex = RegExp(r'^[a-zA-Z0-9_]+$');
    return regex.hasMatch(username);
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Đăng ký thất bại'),
        content: Text(message),
        actions: <Widget>[
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(ctx).pop(),
          )
        ],
      ),
    );
  }

  void _submit() async {
    // 1. Ẩn bàn phím ngay lập tức
    FocusScope.of(context).unfocus();

    // 2. Kiểm tra tính hợp lệ của Form
    if (!_formKey.currentState!.validate()) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    setState(() { _isLoading = true; });

    try {
      // 3. Gọi API đăng ký tài khoản mới
      await authService.register(
        displayName: _displayNameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // 4. Quan trọng: Đăng xuất để xóa mọi token cũ trong bộ nhớ (nếu có)
      await authService.signOut();

      if (!mounted) return;
      setState(() { _isLoading = false; });

      // 5. Hiển thị thông báo thành công (Snack-bar)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🎉 Đăng ký thành công! Bạn có thể quay lại để đăng nhập."),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );

      // 6. 🔥 XÓA DỮ LIỆU FORM (Thay vì chuyển hướng)
      // Việc xóa form giúp người dùng biết là thao tác đã hoàn tất
      // và tránh việc họ nhấn đăng ký lại lần nữa gây lỗi trùng email/username.
      _displayNameController.clear();
      _usernameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();

      // Reset trạng thái validation (xóa các dòng báo đỏ lỗi)
      _formKey.currentState?.reset();

    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; });
        // Hiển thị lỗi từ Backend (ví dụ: User đã tồn tại)
        _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFF0F2F5);
    final appBarBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryText = isDark ? Colors.white : Colors.black;
    final secondaryText = isDark ? Colors.grey[400] : Colors.black87;
    final iconColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(CupertinoIcons.clear, color: iconColor),
          onPressed: widget.onTap,
        ),
        title: Text('Tạo tài khoản', style: TextStyle(color: primaryText, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Image.asset(
                  'assets/images/app_logo.png',
                  height: 100, // Trang đăng ký nhiều ô nhập nên để logo nhỏ hơn xíu (80-100) cho đỡ chật
                  width: 100,
                  fit: BoxFit.contain,
                ),
                Text('Nhanh chóng và dễ dàng.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: secondaryText)),
                const SizedBox(height: 16),

                // 1. Tên hiển thị
                TextFormField(
                  controller: _displayNameController,
                  style: TextStyle(color: primaryText),
                  decoration: _buildInputDecoration('Tên hiển thị', isDark, icon: Icons.person_outline),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Vui lòng nhập tên của bạn' : null,
                ),
                const SizedBox(height: 12),

                // 2. Username (Thêm validate chặt chẽ)
                TextFormField(
                  controller: _usernameController,
                  style: TextStyle(color: primaryText),
                  decoration: _buildInputDecoration('Username (viết liền, không dấu)', isDark, icon: Icons.alternate_email),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Vui lòng nhập username';
                    if (value.contains(' ')) return 'Username không được chứa khoảng trắng';
                    if (!_isValidUsername(value)) return 'Chỉ được dùng chữ cái, số và gạch dưới (_)';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // 3. Email
                TextFormField(
                  controller: _emailController,
                  style: TextStyle(color: primaryText),
                  decoration: _buildInputDecoration('Email', isDark, icon: Icons.email_outlined),
                  keyboardType: TextInputType.emailAddress,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Vui lòng nhập email';
                    // Regex email chặt chẽ hơn
                    if (!RegExp(r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+').hasMatch(value)) return 'Email không hợp lệ';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // 4. Mật khẩu (Có nút ẩn hiện + Validate mạnh)
                TextFormField(
                  controller: _passwordController,
                  style: TextStyle(color: primaryText),
                  decoration: _buildInputDecoration(
                      'Mật khẩu mới',
                      isDark,
                      icon: Icons.lock_outline,
                      isPassword: true,
                      obscureText: _obscurePassword,
                      onToggle: () => setState(() => _obscurePassword = !_obscurePassword)
                  ),
                  obscureText: _obscurePassword,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
                    if (!_isPasswordStrong(value)) return 'Mật khẩu yếu: Cần 8 ký tự, 1 hoa, 1 thường, 1 số';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // 5. Xác nhận mật khẩu
                TextFormField(
                  controller: _confirmPasswordController,
                  style: TextStyle(color: primaryText),
                  decoration: _buildInputDecoration(
                      'Xác nhận mật khẩu',
                      isDark,
                      icon: Icons.lock_reset,
                      isPassword: true,
                      obscureText: _obscureConfirmPassword,
                      onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)
                  ),
                  obscureText: _obscureConfirmPassword,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Vui lòng xác nhận mật khẩu';
                    if (value != _passwordController.text) return 'Mật khẩu không khớp';
                    return null;
                  },
                ),

                const SizedBox(height: 24),
                Text(
                  'Bằng cách nhấn vào Đăng ký, bạn đồng ý với Điều khoản, Chính sách dữ liệu và Chính sách cookie của chúng tôi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                _isLoading
                    ? Center(child: CupertinoActivityIndicator(color: isDark ? Colors.white : null))
                    : CupertinoButton(
                  color: Colors.green.shade600,
                  onPressed: _submit,
                  child: const Text('Đăng ký', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Hàm tạo Decoration đã nâng cấp thêm icon và nút ẩn hiện pass
  InputDecoration _buildInputDecoration(
      String labelText,
      bool isDark,
      {
        IconData? icon,
        bool isPassword = false,
        bool obscureText = false,
        VoidCallback? onToggle
      }
      ) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      prefixIcon: icon != null ? Icon(icon, color: isDark ? Colors.grey[400] : Colors.grey) : null,
      suffixIcon: isPassword
          ? IconButton(
        icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: isDark ? Colors.grey[400] : Colors.grey
        ),
        onPressed: onToggle,
      )
          : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey.shade400)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey.shade400)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: isDark ? Colors.blue.shade400 : Colors.blue.shade700, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: const BorderSide(color: Colors.red, width: 1)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: const BorderSide(color: Colors.red, width: 2)),
    );
  }
}
