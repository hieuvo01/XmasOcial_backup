// File: lib/screens/auth/login_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  final void Function()? onTap;
  // 👇 MỚI: Nhận email từ trang đăng ký
  final String? prefilledEmail;

  const LoginScreen({
    super.key,
    required this.onTap,
    this.prefilledEmail
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  // 👇 MỚI: Biến loading riêng cho GitHub
  bool _isLoadingGitHub = false;

  @override
  void initState() {
    super.initState();
    // 👇 MỚI: Nếu có email truyền vào thì điền sẵn
    if (widget.prefilledEmail != null) {
      _emailController.text = widget.prefilledEmail!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Đăng nhập thất bại'),
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

  // Xử lý đăng nhập thường
  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    setState(() { _isLoading = true; });

    try {
      await authService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      // AuthGate tự chuyển màn hình
    } catch (e) {
      _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  // 👇 MỚI: Xử lý đăng nhập GitHub
  void _handleGitHubLogin() async {
    setState(() => _isLoadingGitHub = true);
    try {
      // Gọi hàm loginWithGitHub bên AuthService (bro nhớ thêm hàm này vào Service như hướng dẫn trước nhé)
      await Provider.of<AuthService>(context, listen: false).loginWithGitHub(context);
      // AuthGate sẽ tự chuyển màn hình khi isLoggedIn = true
    } catch (e) {
      _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoadingGitHub = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceSize = MediaQuery.of(context).size;

    // --- DARK MODE COLORS ---
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFF0F2F5);
    final textColor = isDark ? Colors.white70 : Colors.grey[700];
    final logoColor = isDark ? Colors.blue.shade400 : Colors.blue.shade700;

    // Màu cho nút GitHub (Trắng/Đen tương phản nền)
    final githubBtnColor = isDark ? Colors.white : Colors.black;
    final githubTextColor = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Image.asset(
                    'assets/images/app_logo.png',
                    height: 120, // Chỉnh độ cao tùy ý bro (thường 100-150 là đẹp)
                    width: 120,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Kết nối với bạn bè và thế giới xung quanh bạn.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: textColor),
                  ),
                  const SizedBox(height: 48),

                  // ===== FORM EMAIL =====
                  TextFormField(
                    controller: _emailController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: _buildInputDecoration('Email hoặc số điện thoại', isDark),
                    keyboardType: TextInputType.emailAddress,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Vui lòng nhập email';
                      if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) return 'Vui lòng nhập một email hợp lệ';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // ===== FORM PASSWORD =====
                  TextFormField(
                    controller: _passwordController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: _buildInputDecoration('Mật khẩu', isDark),
                    obscureText: true,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
                      if (value.length < 6) return 'Mật khẩu phải có ít nhất 6 ký tự';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // ===== NÚT ĐĂNG NHẬP =====
                  _isLoading
                      ? Center(child: CupertinoActivityIndicator(color: isDark ? Colors.white : null))
                      : CupertinoButton(
                    color: logoColor,
                    onPressed: _submit,
                    child: const Text('Đăng nhập', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),

                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                      );
                    },
                    child: Text('Quên mật khẩu?', style: TextStyle(color: logoColor)),
                  ),

                  const SizedBox(height: 16),

                  // 👇 MỚI: NÚT GITHUB LOGIN
                  _isLoadingGitHub
                      ? Center(child: CupertinoActivityIndicator(color: isDark ? Colors.white : null))
                      : SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: githubBtnColor,
                        foregroundColor: githubTextColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      // Nếu bro có font_awesome_flutter thì dùng: Icon(FontAwesomeIcons.github)
                      icon: const Icon(Icons.code), // Tạm dùng icon code tượng trưng cho GitHub
                      label: const Text(
                        "Đăng nhập bằng GitHub",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      onPressed: _handleGitHubLogin,
                    ),
                  ),

                  SizedBox(height: deviceSize.height * 0.05),

                  // ===== DIVIDER HOẶC =====
                  Row(
                    children: [
                      Expanded(child: Divider(thickness: 1, color: isDark ? Colors.grey[800] : Colors.grey[300])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text('HOẶC', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                      ),
                      Expanded(child: Divider(thickness: 1, color: isDark ? Colors.grey[800] : Colors.grey[300])),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ===== NÚT TẠO TÀI KHOẢN =====
                  CupertinoButton(
                    color: Colors.green.shade600,
                    onPressed: widget.onTap,
                    child: const Text('Tạo tài khoản mới', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String labelText, bool isDark) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey.shade400)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey.shade400)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: isDark ? Colors.blue.shade400 : Colors.blue.shade700, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: const BorderSide(color: Colors.red, width: 1)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: const BorderSide(color: Colors.red, width: 2)),
    );
  }
}
