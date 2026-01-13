// lib/screens/auth/auth_gate.dart

import 'package:flutter/material.dart';
import 'package:flutter_maps/screens/social/social_main_screen.dart';
import 'package:flutter_maps/services/auth_service.dart';
import 'package:provider/provider.dart';

import 'login_or_register.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Dùng Consumer để lắng nghe sự thay đổi từ AuthService
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        // Nếu đã đăng nhập (token tồn tại)
        if (authService.isLoggedIn) {
          // Đi đến màn hình chính của mạng xã hội
          return const SocialMainScreen();
        }
        // Nếu chưa đăng nhập
        else {
          // Đi đến màn hình lựa chọn Đăng nhập hoặc Đăng ký
          return const LoginOrRegisterPage();
        }
      },
    );
  }
}
