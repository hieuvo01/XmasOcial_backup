// File: lib/screens/admin/notification_management_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/admin_service.dart';

class NotificationManagementScreen extends StatefulWidget {
  const NotificationManagementScreen({super.key});

  @override
  State<NotificationManagementScreen> createState() => _NotificationManagementScreenState();
}

class _NotificationManagementScreenState extends State<NotificationManagementScreen> {
  bool _isLoading = true;
  List<dynamic> _notifications = [];
  final AdminService _adminService = AdminService();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    // API này giờ đã trả về cả System Noti và User Interaction Noti
    final data = await _adminService.getNotificationHistory(context);
    if (mounted) {
      setState(() {
        _notifications = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteItem(String id) async {
    try {
      await _adminService.deleteNotification(context, id);
      setState(() => _notifications.removeWhere((item) => item['_id'] == id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã xóa"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lỗi xóa"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- DIALOG SOẠN TIN NHẮN SYSTEM (Giữ nguyên) ---
  void _showComposeDialog() {
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    String selectedType = 'system';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Gửi thông báo hệ thống"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: "Tiêu đề", hintText: "VD: Bảo trì"),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: msgCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: "Nội dung", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(labelText: "Loại"),
                      items: const [
                        DropdownMenuItem(value: 'system', child: Text('📡 Hệ thống')),
                        DropdownMenuItem(value: 'promotion', child: Text('🎁 Khuyến mãi')),
                        DropdownMenuItem(value: 'alert', child: Text('⚠️ Cảnh báo')),
                        DropdownMenuItem(value: 'update', child: Text('📲 Cập nhật App')),
                      ],
                      onChanged: (val) => setStateDialog(() => selectedType = val!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(child: const Text("Hủy"), onPressed: () => Navigator.pop(ctx)),
                ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.isEmpty || msgCtrl.text.isEmpty) return;
                    try {
                      Navigator.pop(ctx);
                      await _adminService.sendNotification(context, titleCtrl.text, msgCtrl.text, selectedType);
                      _fetchData();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã gửi"), backgroundColor: Colors.green));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi gửi"), backgroundColor: Colors.red));
                    }
                  },
                  child: const Text("Gửi"),
                ),
              ],
            );
          }
      ),
    );
  }

  // --- LOGIC HIỂN THỊ ICON VÀ MÀU SẮC ĐA DẠNG HƠN ---
  Map<String, dynamic> _getDisplayInfo(String type) {
    switch (type) {
      case 'system':
        return {'icon': Icons.rss_feed, 'color': Colors.blue};
      case 'alert':
        return {'icon': Icons.warning_amber_rounded, 'color': Colors.red};
      case 'promotion':
        return {'icon': Icons.card_giftcard, 'color': Colors.orange};
      case 'update':
        return {'icon': Icons.system_update, 'color': Colors.green};
      case 'like':
      case 'like_post':
      case 'reaction':
        return {'icon': Icons.favorite, 'color': Colors.pink};
      case 'comment':
      case 'comment_post':
      case 'reply_comment':
        return {'icon': Icons.comment, 'color': Colors.blueAccent};
      case 'friend_request':
        return {'icon': Icons.person_add, 'color': Colors.teal};
      case 'react_story':
        return {'icon': Icons.history_edu, 'color': Colors.purple};
      default:
        return {'icon': Icons.notifications, 'color': Colors.grey};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quản lý tất cả Thông báo"),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showComposeDialog,
        icon: const Icon(Icons.add_alert),
        label: const Text("Gửi System Noti"),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? const Center(child: Text("Không có thông báo nào"))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _notifications.length,
        itemBuilder: (ctx, index) {
          final item = _notifications[index];

          // 1. Xử lý Date
          DateTime date;
          try {
            date = DateTime.parse(item['createdAt']);
          } catch (e) {
            date = DateTime.now();
          }

          // 2. Lấy thông tin cơ bản
          final type = item['type'] ?? 'unknown';
          final senderName = item['sender']?['displayName'] ?? 'Unknown User';
          final recipientName = item['recipient']?['displayName'] ?? 'Tất cả (All)';

          // 3. Xây dựng nội dung hiển thị (Title & Body)
          String title = "";
          String body = "";

          // A. Nhóm System Notification (Admin gửi)
          if (['system', 'alert', 'promotion', 'update'].contains(type)) {
            title = item['title'] ?? 'Thông báo hệ thống';
            body = item['message'] ?? '';
          }
          // B. Nhóm Tương tác User (User gửi)
          else {
            // Lấy nội dung comment (nếu có) - Xử lý an toàn cả Map và String
            String commentContent = '...';
            if (item['comment'] != null) {
              if (item['comment'] is Map) {
                commentContent = item['comment']['content'] ?? '...';
              } else {
                commentContent = item['comment'].toString();
              }
            }

            // Xử lý từng loại cụ thể
            if (type == 'like_post' || type == 'like') {
              title = "$senderName đã thích một bài viết";
              body = "Của người dùng: $recipientName";
            }
            else if (type == 'comment_post' || type == 'comment') {
              title = "$senderName đã bình luận bài viết";
              body = "Nội dung: \"$commentContent\"\nĐến: $recipientName";
            }
            else if (type == 'reply_comment') {
              title = "$senderName đã trả lời một bình luận";
              body = "Nội dung: \"$commentContent\"\nĐến: $recipientName";
            }
            else if (type == 'friend_request') {
              title = "$senderName đã gửi lời mời kết bạn";
              body = "Đến: $recipientName";
            }
            else if (type == 'accept_friend') {
              title = "$senderName đã chấp nhận lời mời kết bạn";
              body = "Của: $recipientName";
            }
            else if (type == 'react_story') {
              title = "$senderName đã thả cảm xúc vào Story";
              body = "Của: $recipientName";
            }
            // Trường hợp còn lại (fallback)
            else {
              title = "$senderName đã thực hiện: $type";
              body = "Đến: $recipientName";
            }
          }

          // 4. Lấy Icon & Màu
          final displayInfo = _getDisplayInfo(type);

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: (displayInfo['color'] as Color).withOpacity(0.1),
                child: Icon(displayInfo['icon'], color: displayInfo['color'], size: 20),
              ),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(DateFormat('dd/MM HH:mm').format(date.toLocal()), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                        child: Text(type, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                      )
                    ],
                  )
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deleteItem(item['_id']),
              ),
            ),
          );
        },
      ),
    );
  }

}
