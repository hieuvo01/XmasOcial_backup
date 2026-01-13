// File: lib/screens/settings/settings_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../admin/admin_dashboard_screen.dart';
import '../admin/manager_dashboard_screen.dart';
import 'change_password_screen.dart';
import 'two_factor_screen.dart'; //

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Lấy theme hiện tại để check màu nền
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Lấy User để check quyền Admin
    final authService = Provider.of<AuthService>(context);
    final user = authService.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Cài đặt & Quyền riêng tư"),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: isDark ? null : Colors.grey[100],
      body: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            children: [

              // =================================================
              // SECTION 0: QUẢN TRỊ VIÊN
              // =================================================
              if (user != null && (user.isAdmin || user.role == 'moderator')) ...[
                _buildSectionTitle("Quản trị hệ thống"),
                _buildSectionContainer(
                  context,
                  children: [
                    _buildListTile(
                      // Đổi Icon và Màu sắc dựa trên Role cho chuyên nghiệp
                      icon: user.isAdmin ? Icons.admin_panel_settings : Icons.manage_accounts,
                      iconColor: user.isAdmin ? Colors.purpleAccent : Colors.teal,

                      // Đổi Tiêu đề dựa trên Role
                      title: user.isAdmin ? "Dashboard Quản Trị" : "Dashboard Quản Lý",
                      subtitle: user.isAdmin
                          ? "Toàn quyền quản lý hệ thống"
                          : "Kiểm duyệt nội dung & người dùng",

                      onTap: () {
                        if (user.isAdmin) {
                          // Nếu là Admin xịn -> Vào Admin Dashboard
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
                          );
                        } else {
                          // Nếu là Manager -> Vào Manager Dashboard
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ManagerDashboardScreen()),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],


              // --- SECTION 1: GIAO DIỆN ---
              _buildSectionTitle("Giao diện"),
              _buildSectionContainer(
                context,
                children: [
                  SwitchListTile(
                    title: const Text("Chế độ tối", style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: const Text("Giao diện nền tối giảm mỏi mắt"),
                    secondary: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                      child: const Icon(Icons.dark_mode, color: Colors.white, size: 20),
                    ),
                    value: themeService.isDarkMode,
                    onChanged: (val) {
                      themeService.toggleTheme(val);
                    },
                    activeColor: CupertinoColors.activeBlue,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // --- SECTION 2: BẢO MẬT ---
              _buildSectionTitle("Bảo mật"),
              _buildSectionContainer(
                context,
                children: [
                  _buildListTile(
                    icon: Icons.lock_outline,
                    iconColor: Colors.teal,
                    title: "Đổi mật khẩu",
                    onTap: () {
                      // 👇 2. SỬA ĐOẠN NÀY
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),

                  // 👇 2. SỬA CHỖ NÀY: MỞ MÀN HÌNH 2FA
                  _buildListTile(
                    icon: Icons.security,
                    iconColor: Colors.orange,
                    title: "Xác thực 2 lớp (2FA)",
                    subtitle: "Tăng cường bảo mật cho tài khoản",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const TwoFactorScreen()),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // --- SECTION 3: TÀI KHOẢN ---
              _buildSectionTitle("Tài khoản"),
              _buildSectionContainer(
                context,
                children: [
                  _buildListTile(
                    icon: Icons.logout,
                    iconColor: Colors.red,
                    title: "Đăng xuất",
                    textColor: Colors.red,
                    onTap: () {
                      _showLogoutConfirm(context);
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // --- WIDGETS HELPER (Giữ nguyên) ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }

  Widget _buildSectionContainer(BuildContext context, {required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: isDark ? null : Border(
          top: BorderSide(color: Colors.grey[300]!),
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: iconColor.withOpacity(0.15), shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: textColor)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
    );
  }

  void _showLogoutConfirm(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Đăng xuất"),
        content: const Text("Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này?"),
        actions: [
          CupertinoDialogAction(
            child: const Text("Hủy"),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("Đăng xuất"),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Đóng SettingsScreen
              Provider.of<AuthService>(context, listen: false).signOut();
            },
          ),
        ],
      ),
    );
  }
}
