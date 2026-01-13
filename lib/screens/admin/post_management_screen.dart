// File: lib/screens/admin/post_management_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Để format ngày tháng cho đẹp
import '../../models/post_model.dart';
import '../../services/admin_service.dart';

class PostManagementScreen extends StatefulWidget {
  const PostManagementScreen({super.key});

  @override
  State<PostManagementScreen> createState() => _PostManagementScreenState();
}

class _PostManagementScreenState extends State<PostManagementScreen> {
  bool _isLoading = true;
  List<Post> _posts = []; // Dùng class Post chuẩn
  final AdminService _adminService = AdminService();

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  // 1. Hàm tải dữ liệu
  Future<void> _fetchPosts() async {
    try {
      final posts = await _adminService.getAllPosts(context);
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi tải bài viết: $e")),
        );
      }
    }
  }

  // 2. Hàm xác nhận xóa
  void _confirmDelete(String postId) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Xóa bài viết?"),
        content: const Text("Hành động này sẽ xóa vĩnh viễn bài viết khỏi hệ thống."),
        actions: [
          CupertinoDialogAction(
            child: const Text("Hủy"),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("Xóa"),
            onPressed: () async {
              Navigator.pop(ctx);
              _executeDelete(postId);
            },
          ),
        ],
      ),
    );
  }

  // 3. Hàm thực thi xóa
  Future<void> _executeDelete(String postId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await _adminService.deletePost(context, postId);

      // Xóa thành công thì xóa luôn trên UI cho mượt
      setState(() {
        _posts.removeWhere((p) => p.id == postId);
      });

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text("Đã xóa bài viết"), backgroundColor: Colors.green),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text("Lỗi xóa bài viết"), backgroundColor: Colors.red),
      );
    }
  }

  // 4. (MỚI) Hiển thị Dialog sửa bài viết
  void _showEditDialog(Post post) {
    final TextEditingController contentController = TextEditingController(text: post.content);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Chỉnh sửa bài viết"),
        content: TextField(
          controller: contentController,
          maxLines: 5,
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
            child: const Text("Lưu thay đổi"),
            onPressed: () {
              Navigator.pop(ctx); // Đóng dialog
              _executeUpdate(post, contentController.text);
            },
          ),
        ],
      ),
    );
  }

  // 5. (MỚI) Thực thi cập nhật bài viết
  Future<void> _executeUpdate(Post post, String newContent) async {
    if (newContent.trim().isEmpty) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      // Gọi Service cập nhật (API Backend đã tạo)
      await _adminService.updatePost(context, post.id, newContent);

      // Cập nhật lại UI ngay lập tức
      setState(() {
        final index = _posts.indexWhere((p) => p.id == post.id);
        if (index != -1) {
          // Dùng copyWith để tạo bản sao mới với nội dung đã sửa
          _posts[index] = _posts[index].copyWith(content: newContent);
        }
      });

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text("Cập nhật thành công"), backgroundColor: Colors.green),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text("Lỗi cập nhật bài viết"), backgroundColor: Colors.red),
      );
    }
  }

  // Helper format ngày
  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quản lý Bài viết"),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
          ? const Center(child: Text("Không có bài viết nào."))
          : ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _posts.length,
        separatorBuilder: (ctx, i) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final post = _posts[index];
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Header: Avatar + Tên + Nút Xóa/Sửa ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: post.author.avatarUrl != null
                            ? NetworkImage(post.author.avatarUrl!)
                            : null,
                        onBackgroundImageError: (_, __) {},
                        child: post.author.avatarUrl == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.author.displayName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              _formatDate(post.createdAt),
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      // Nút Sửa (MỚI)
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        tooltip: 'Sửa nội dung',
                        onPressed: () => _showEditDialog(post),
                      ),
                      // Nút Xóa
                      IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        tooltip: 'Xóa bài này',
                        onPressed: () => _confirmDelete(post.id),
                      ),
                    ],
                  ),

                  const Divider(),

                  // --- Nội dung Text ---
                  if (post.content.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        post.content,
                        style: const TextStyle(fontSize: 15),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                  // --- Nội dung Ảnh (Nếu có) ---
                  if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        post.imageUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, _, __) => Container(
                          height: 200,
                          color: Colors.grey[300],
                          child: const Center(child: Icon(Icons.broken_image)),
                        ),
                      ),
                    ),

                  // --- Footer: Thống kê Like/Comment ---
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.thumb_up_alt_outlined, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text("${post.reactions.length}", style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(width: 16),
                      Icon(Icons.comment_outlined, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      // Số bình luận này giờ đã đúng nhờ API backend dùng aggregate
                      Text("${post.commentCount}", style: TextStyle(color: Colors.grey[600])),
                    ],
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
