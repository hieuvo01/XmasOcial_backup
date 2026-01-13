// File: lib/screens/admin/comment_management_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/app_config.dart'; // Import config để lấy BaseURL xử lý ảnh
import '../../services/admin_service.dart';

class CommentManagementScreen extends StatefulWidget {
  const CommentManagementScreen({super.key});

  @override
  State<CommentManagementScreen> createState() => _CommentManagementScreenState();
}

class _CommentManagementScreenState extends State<CommentManagementScreen> {
  bool _isLoading = true;
  List<dynamic> _comments = [];
  final AdminService _adminService = AdminService();
  final String _baseUrl = AppConfig.baseUrl; // Lấy BaseURL

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    try {
      final comments = await _adminService.getAllComments(context);
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIC XÓA ---
  void _confirmDelete(String commentId) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Xóa bình luận?"),
        content: const Text("Bình luận này sẽ bị xóa vĩnh viễn."),
        actions: [
          CupertinoDialogAction(child: const Text("Hủy"), onPressed: () => Navigator.pop(ctx)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("Xóa"),
            onPressed: () {
              Navigator.pop(ctx);
              _executeDelete(commentId);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _executeDelete(String commentId) async {
    try {
      await _adminService.deleteComment(context, commentId);
      setState(() {
        _comments.removeWhere((c) => c['_id'] == commentId);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã xóa"), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi xóa"), backgroundColor: Colors.red));
    }
  }

  // --- LOGIC SỬA (MỚI) ---
  void _showEditDialog(dynamic comment) {
    final TextEditingController contentController = TextEditingController(text: comment['content']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Sửa bình luận"),
        content: TextField(
          controller: contentController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Nhập nội dung mới...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Hủy"),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            child: const Text("Lưu"),
            onPressed: () {
              Navigator.pop(ctx);
              _executeUpdate(comment['_id'], contentController.text);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _executeUpdate(String commentId, String newContent) async {
    if (newContent.trim().isEmpty) return;
    try {
      await _adminService.updateComment(context, commentId, newContent);

      // Update UI
      setState(() {
        final index = _comments.indexWhere((c) => c['_id'] == commentId);
        if (index != -1) {
          _comments[index]['content'] = newContent;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã cập nhật"), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi cập nhật"), backgroundColor: Colors.red));
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    return DateFormat('dd/MM HH:mm').format(DateTime.parse(dateStr));
  }

  // Helper xử lý URL ảnh
  String? _getAvatarUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    return "$_baseUrl$url"; // Ghép base url nếu là path tương đối
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Quản lý Bình luận"), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _comments.isEmpty
          ? const Center(child: Text("Chưa có bình luận nào."))
          : ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _comments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final cmt = _comments[index];

          // ✅ FIX LỖI: Backend trả về 'author', không phải 'user'
          final author = cmt['author'] ?? {};
          final post = cmt['post'];

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: User Info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundImage: _getAvatarUrl(author['avatarUrl']) != null
                            ? NetworkImage(_getAvatarUrl(author['avatarUrl'])!)
                            : null,
                        child: _getAvatarUrl(author['avatarUrl']) == null
                            ? const Icon(Icons.person, size: 14)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        author['displayName'] ?? 'Unknown', // ✅ Lấy tên đúng
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(cmt['createdAt']),
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Nội dung Comment
                  Text(
                    cmt['content'] ?? '',
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 8),

                  // Footer: Post context & Action buttons
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.article, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            post != null
                                ? "Post: ${post['content'] ?? '[Hình ảnh]'}"
                                : "Bài viết gốc đã bị xóa",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey[700], fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ),

                        // Nút Sửa (Mới)
                        InkWell(
                          onTap: () => _showEditDialog(cmt),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Icon(Icons.edit, color: Colors.blue, size: 20),
                          ),
                        ),

                        // Nút Xóa
                        InkWell(
                          onTap: () => _confirmDelete(cmt['_id']),
                          child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
