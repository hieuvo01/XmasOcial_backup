// File: lib/screens/social/tabs/profile_tab.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // Import Material để dùng Theme
import 'package:provider/provider.dart';

import '../../../services/auth_service.dart';
import '../user_profile_screen.dart';

class ProfileTab extends StatelessWidget {
  final ScrollController scrollController;
  const ProfileTab({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    // Lấy màu nền từ Theme để phần Loading không bị trắng toác trong Dark Mode
    final scaffoldBgColor = Theme.of(context).scaffoldBackgroundColor;

    return Consumer<AuthService>(
      builder: (context, authService, child) {
        // Nếu chưa đăng nhập hoặc đang tải, hiển thị loading trên nền đúng theme
        if (authService.user == null) {
          return Container(
            color: scaffoldBgColor,
            child: const Center(child: CupertinoActivityIndicator()),
          );
        }

        // Khi đã có user, trả về trực tiếp màn hình UserProfileScreen
        return UserProfileScreen(userId: authService.user!.id);
      },
    );
  }
}
