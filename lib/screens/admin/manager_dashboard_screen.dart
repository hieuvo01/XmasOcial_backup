// File: lib/screens/admin/manager_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'ai_character_management_screen.dart';
import 'user_management_screen.dart';
import 'comment_management_screen.dart';
import 'story_management_screen.dart';
import 'reel_management_screen.dart';
import 'notification_management_screen.dart';

class ManagerDashboardScreen extends StatelessWidget {
  const ManagerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    const primaryColor = Colors.teal;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text("Manager Panel"),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Banner Chào mừng ---
            _buildWelcomeBanner(primaryColor),
            const SizedBox(height: 24),

            Text(
              "Danh mục quản lý",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),

            // --- Menu dạng List Card ---
            _buildMenuItem(
              context,
              title: "Quản lý Người dùng",
              subtitle: "Xem danh sách và trạng thái (Chỉ xem)",
              icon: Icons.people_alt_rounded,
              iconColor: Colors.blueGrey,
              cardColor: cardColor,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserManagementScreen(isReadOnly: true)),
              ),
            ),

            _buildMenuItem(
              context,
              title: "Quản lý Bình luận",
              subtitle: "Kiểm duyệt và xóa bình luận vi phạm",
              icon: Icons.comment_rounded,
              iconColor: Colors.purple,
              cardColor: cardColor,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CommentManagementScreen()),
              ),
            ),

            _buildMenuItem(
              context,
              title: "Thông báo hệ thống",
              subtitle: "Gửi thông báo mới đến người dùng",
              icon: Icons.notifications_active_rounded,
              iconColor: Colors.deepOrange,
              cardColor: cardColor,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationManagementScreen()),
              ),
            ),

            _buildMenuItem(
              context,
              title: "Quản lý Stories & Reels",
              subtitle: "Kiểm duyệt tin và video ngắn",
              icon: Icons.video_collection_rounded,
              iconColor: Colors.pink,
              cardColor: cardColor,
              onTap: () => _showMediaMenu(context),
            ),

            _buildMenuItem(
              context,
              title: "Nhân vật AI (Bots)",
              subtitle: "Cấu hình và quản lý các AI Models",
              icon: Icons.smart_toy_rounded,
              iconColor: Colors.teal,
              cardColor: cardColor,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AICharacterManagementScreen()),
              ),
            ),

            const SizedBox(height: 30),
            Center(
              child: Text(
                "Phiên bản quản lý 1.0.0",
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color iconColor,
        required Color cardColor,
        required VoidCallback onTap,
      }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 26),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      ),
    );
  }

  void _showMediaMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.history_edu, color: Colors.pink),
              title: const Text("Quản lý Stories"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const StoryManagementScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library, color: Colors.red),
              title: const Text("Quản lý Reels"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ReelManagementScreen()));
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            "XmasOcial Manager",
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6),
          Text(
            "Hệ thống kiểm duyệt nội dung cộng đồng.",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
