// File: lib/screens/admin/reel_management_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../../services/admin_service.dart';

class ReelManagementScreen extends StatefulWidget {
  const ReelManagementScreen({super.key});

  @override
  State<ReelManagementScreen> createState() => _ReelManagementScreenState();
}

class _ReelManagementScreenState extends State<ReelManagementScreen> {
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
      final data = await _adminService.getAllReels(context);
      if (mounted) {
        setState(() {
          _items = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteItem(String id) async {
    try {
      await _adminService.deleteReel(context, id);
      setState(() => _items.removeWhere((item) => item['_id'] == id));
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã xóa"), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lỗi xóa"), backgroundColor: Colors.red));
    }
  }

  // Hàm confirm trước khi xóa
  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xóa Reel?"),
        content: const Text("Hành động này không thể hoàn tác."),
        actions: [
          TextButton(
            child: const Text("Hủy"),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: const Text("Xóa", style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteItem(id);
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    return DateFormat('dd/MM HH:mm').format(DateTime.parse(dateStr));
  }

  String? _getUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    return "$_baseUrl$url";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Quản lý Reels"), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(child: Text("Không có Reel nào."))
          : ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          final user = item['user'] ?? {};

          // Xử lý thumbnail (Reel thường là video, ở đây mình dùng icon đại diện
          // hoặc nếu backend có trả về thumbnail image thì dùng _getUrl(item['thumbnail']))

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.play_circle_fill,
                    color: Colors.redAccent, size: 30),
              ),
              title: Text(
                item['description'] ?? 'Không có mô tả',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Row(
                children: [
                  CircleAvatar(
                    radius: 8,
                    backgroundImage: _getUrl(user['avatarUrl']) != null
                        ? NetworkImage(_getUrl(user['avatarUrl'])!)
                        : null,
                    child: _getUrl(user['avatarUrl']) == null
                        ? const Icon(Icons.person, size: 10)
                        : null,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "${user['displayName'] ?? 'Unknown'} • ${_formatDate(item['createdAt'])}",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmDelete(item['_id']),
              ),
              onTap: () {
                // Tương lai: Có thể mở trình phát video xem trước
              },
            ),
          );
        },
      ),
    );
  }
}
