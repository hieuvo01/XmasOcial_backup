// File: lib/screens/admin/story_management_screen.dart

import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../services/admin_service.dart';

class StoryManagementScreen extends StatefulWidget {
  const StoryManagementScreen({super.key});
  @override
  State<StoryManagementScreen> createState() => _StoryManagementScreenState();
}

class _StoryManagementScreenState extends State<StoryManagementScreen> {
  bool _isLoading = true;
  List<dynamic> _items = [];
  final AdminService _adminService = AdminService();
  final String _baseUrl = AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final data = await _adminService.getAllStories(context); // Đổi thành getAllReels cho màn Reel
      if (mounted) setState(() { _items = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteItem(String id) async {
    try {
      await _adminService.deleteStory(context, id); // Đổi thành deleteReel cho màn Reel
      setState(() => _items.removeWhere((item) => item['_id'] == id));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã xóa"), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi xóa"), backgroundColor: Colors.red));
    }
  }

  String? _getUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    return "$_baseUrl$url";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Quản lý Story"), centerTitle: true),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          final user = item['user'] ?? {};
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: _getUrl(user['avatarUrl']) != null ? NetworkImage(_getUrl(user['avatarUrl'])!) : null,
            ),
            title: Text(user['displayName'] ?? 'Unknown'),
            subtitle: Text("Type: ${item['type'] ?? 'image'}"),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteItem(item['_id']),
            ),
            onTap: () {
              // Có thể mở dialog xem trước ảnh Story nếu muốn
            },
          );
        },
      ),
    );
  }
}
