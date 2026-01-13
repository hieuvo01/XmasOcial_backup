// lib/screens/auth/login_or_register.dart

import 'package:flutter/material.dart';
import 'package:flutter_maps/screens/auth/register_page.dart';
import 'package:flutter_maps/screens/auth/login_screen.dart';


class LoginOrRegisterPage extends StatefulWidget {
  const LoginOrRegisterPage({super.key});

  @override
  State<LoginOrRegisterPage> createState() => _LoginOrRegisterPageState();
}

class _LoginOrRegisterPageState extends State<LoginOrRegisterPage> {
  // Ban đầu, hiển thị trang đăng nhập
  bool showLoginPage = true;

  // Hàm để chuyển đổi giữa 2 trang
  void togglePages() {
    setState(() {
      showLoginPage = !showLoginPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (showLoginPage) {
      // Nếu `showLoginPage` là true, hiển thị LoginPage và truyền hàm `togglePages` vào
      // ***** SỬA TÊN CLASS Ở ĐÂY *****
      return LoginScreen(onTap: togglePages); // <-- ĐỔI TÊN CLASS
    } else {
      // Ngược lại, hiển thị RegisterPage và cũng truyền hàm `togglePages` vào
      return RegisterPage(onTap: togglePages);
    }
  }
}