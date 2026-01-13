// File: lib/screens/social/tabs/menu_tab.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/user_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/navigation_service.dart';
import '../../app_info_screen.dart';
import '../../map_screen.dart';
import '../../settings/settings_screen.dart';
import '../../games/game_center_screen.dart'; // <--- Import màn hình Game Center

class MenuTab extends StatefulWidget {
  const MenuTab({super.key});

  @override
  State<MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends State<MenuTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthService>(context, listen: false).fetchAndSetCurrentUser();
    });
  }

  // Hàm chuyển tab tiện lợi
  void _switchToTab(BuildContext context, int index) {
    final navService = Provider.of<NavigationService>(context, listen: false);
    if (navService.pageController != null) {
      navService.pageController!.jumpToPage(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lấy màu từ Theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final dividerColor = Theme.of(context).dividerColor;

    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final user = authService.user;
        if (user == null) {
          return const Center(child: CupertinoActivityIndicator());
        }

        return Scaffold(
          backgroundColor: scaffoldBgColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            elevation: 0.5,
            centerTitle: false,
            title: Text(
              'Menu',
              style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              const SizedBox(height: 16),
              _buildProfileHeader(context, user, cardColor, textColor, isDark),
              const SizedBox(height: 16),
              _buildOptionSection(context, cardColor, textColor, dividerColor),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(BuildContext context, UserModel user, Color cardColor, Color? textColor, bool isDark) {
    const defaultAvatar = 'https://upload.wikimedia.org/wikipedia/commons/8/89/Portrait_Placeholder.png';

    return GestureDetector(
      onTap: () {
        // Chuyển sang Tab Cá nhân (Index 3)
        _switchToTab(context, 3);
      },
      child: Container(
        padding: const EdgeInsets.all(16.0),
        margin: const EdgeInsets.symmetric(horizontal: 16.0),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          // Chỉ đổ bóng ở Light Mode
          boxShadow: isDark ? null : [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5)],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                  ? NetworkImage(user.avatarUrl!)
                  : const NetworkImage(defaultAvatar) as ImageProvider,
              backgroundColor: Colors.grey[200],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      user.displayName,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)
                  ),
                  const SizedBox(height: 4),
                  const Text('Xem trang cá nhân của bạn', style: TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionSection(BuildContext context, Color cardColor, Color? textColor, Color dividerColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildOptionItem(
            context,
            icon: CupertinoIcons.person_2_fill,
            iconColor: Colors.blue,
            title: 'Bạn bè',
            textColor: textColor,
            onTap: () => _switchToTab(context, 1),
          ),

          Divider(height: 1, indent: 50, color: dividerColor),

          // MỤC TRÒ CHƠI MỚI THÊM VÀO ĐÂY
          _buildOptionItem(
            context,
            icon: CupertinoIcons.game_controller_solid, // Icon tay cầm game
            iconColor: Colors.purpleAccent,
            title: 'Trò chơi',
            textColor: textColor,
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                CupertinoPageRoute(builder: (_) => const GameCenterScreen()),
              );
            },
          ),

          Divider(height: 1, indent: 50, color: dividerColor),


          _buildOptionItem(
            context,
            icon: CupertinoIcons.map_fill, // Icon bản đồ
            iconColor: Colors.green,
            title: 'Bản đồ',
            textColor: textColor,
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                CupertinoPageRoute(builder: (_) => const MapScreen()),
              );
            },
          ),

          Divider(height: 1, indent: 50, color: dividerColor),

          _buildOptionItem(
            context,
            icon: CupertinoIcons.settings_solid,
            iconColor: Colors.grey,
            title: 'Cài đặt & quyền riêng tư',
            textColor: textColor,
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                CupertinoPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),

          Divider(height: 1, indent: 50, color: dividerColor),
          _buildOptionItem(
            context,
            icon: CupertinoIcons.info_circle_fill,
            iconColor: Colors.orangeAccent,
            title: 'Thông tin ứng dụng',
            textColor: textColor,
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                CupertinoPageRoute(builder: (_) => const AppInfoScreen()),
              );
            },
          ),
          Divider(height: 1, indent: 50, color: dividerColor),
          _buildOptionItem(
            context,
            icon: Icons.logout,
            iconColor: Colors.red,
            title: 'Đăng xuất',
            textColor: Colors.red,
            onTap: () {
              Provider.of<AuthService>(context, listen: false).signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOptionItem(
      BuildContext context, {
        required IconData icon,
        required Color iconColor,
        required String title,
        required VoidCallback onTap,
        Color? textColor,
      }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: iconColor, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: textColor)),
      trailing: const Icon(CupertinoIcons.right_chevron, size: 16, color: Colors.grey),
    );
  }
}
