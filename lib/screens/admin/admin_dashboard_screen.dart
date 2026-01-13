// File: lib/screens/admin/admin_dashboard_screen.dart

import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import 'ai_character_management_screen.dart';
import 'user_management_screen.dart';
import 'post_management_screen.dart';
import 'comment_management_screen.dart';
import 'story_management_screen.dart';
import 'reel_management_screen.dart';
import 'notification_management_screen.dart'; // 👈 IMPORT MỚI
// import 'report_management_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // Biến lưu trạng thái thống kê
  Map<String, dynamic> _stats = {
    'users': 0,
    'posts': 0,
    'comments': 0,
  };
  bool _isLoading = true;

  final AdminService _adminService = AdminService();

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _adminService.getDashboardStats(context);
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Lỗi load stats: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        titleTextStyle: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textColor),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadStats();
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              Text(
                "Tổng quan hệ thống",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 16),

              // --- GRID MENU ---
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  // 1. USERS
                  _buildDashboardCard(
                    context,
                    title: "Người dùng",
                    count: "${_stats['users'] ?? 0}",
                    icon: Icons.people_alt_rounded,
                    color: Colors.blueAccent,
                    cardColor: cardColor,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen())).then((_) => _loadStats()),
                  ),

                  // 2. POSTS
                  _buildDashboardCard(
                    context,
                    title: "Bài viết",
                    count: "${_stats['posts'] ?? 0}",
                    icon: Icons.article_rounded,
                    color: Colors.orangeAccent,
                    cardColor: cardColor,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PostManagementScreen())).then((_) => _loadStats()),
                  ),

                  // 3. COMMENTS
                  _buildDashboardCard(
                    context,
                    title: "Bình luận",
                    count: "${_stats['comments'] ?? 0}",
                    icon: Icons.comment_rounded,
                    color: Colors.purpleAccent,
                    cardColor: cardColor,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CommentManagementScreen())).then((_) => _loadStats()),
                  ),

                  // 4. STORIES
                  _buildDashboardCard(
                    context,
                    title: "Stories (Tin)",
                    count: "Quản lý",
                    icon: Icons.history_edu,
                    color: Colors.pinkAccent,
                    cardColor: cardColor,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StoryManagementScreen())),
                  ),

                  // 5. REELS
                  _buildDashboardCard(
                    context,
                    title: "Reels (Video)",
                    count: "Quản lý",
                    icon: Icons.video_library_rounded,
                    color: Colors.redAccent,
                    cardColor: cardColor,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReelManagementScreen())),
                  ),

                  // 6. AI CHARACTERS
                  _buildDashboardCard(
                    context,
                    title: "Nhân vật AI",
                    count: "Bot",
                    icon: Icons.smart_toy_rounded,
                    color: Colors.teal,
                    cardColor: cardColor,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AICharacterManagementScreen())),
                  ),

                  // 7. NOTIFICATIONS (MỚI 👇)
                  _buildDashboardCard(
                    context,
                    title: "Thông báo",
                    count: "System",
                    icon: Icons.notifications_active_rounded,
                    color: Colors.deepOrangeAccent,
                    cardColor: cardColor,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationManagementScreen())),
                  ),

                  // 8. REPORTS (Coming Soon)
                  _buildDashboardCard(
                    context,
                    title: "Báo cáo",
                    count: "Sắp có",
                    icon: Icons.flag_rounded,
                    color: Colors.grey, // Đổi màu xám cho biết chưa active
                    cardColor: cardColor,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tính năng đang phát triển")));
                    },
                  ),

                ],
              ),

              const SizedBox(height: 24),

              // --- LIST MENU ---
              Text(
                "Cài đặt hệ thống",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  children: [
                    _buildListTile(icon: Icons.settings_applications, color: Colors.grey, title: "Cấu hình chung", onTap: () {}),
                    Divider(height: 1, indent: 50, color: Colors.grey.withOpacity(0.2)),
                    _buildListTile(icon: Icons.history, color: Colors.grey, title: "Nhật ký hoạt động (Logs)", onTap: () {}),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context, {required String title, required String count, required IconData icon, required Color color, required Color cardColor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
                Icon(Icons.arrow_forward, size: 16, color: Colors.grey[400]),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(count, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                const SizedBox(height: 4),
                Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile({required IconData icon, required Color color, required String title, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
    );
  }
}
