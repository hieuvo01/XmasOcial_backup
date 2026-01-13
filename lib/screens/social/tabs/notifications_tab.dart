// File: lib/screens/social/tabs/notifications_tab.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

// Import các Model
import '../../../models/notification_model.dart';
import '../../../models/story_model.dart';
import '../../../models/user_model.dart';

// Import các Service
import '../../../services/notification_service.dart';
import '../../../services/post_service.dart';
import '../../../services/story_service.dart';

// Import các màn hình
import '../../post_detail_screen.dart';
import '../user_profile_screen.dart';
import '../story_viewer_screen.dart';

class NotificationsTab extends StatefulWidget {
  const NotificationsTab({super.key});

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('vi', timeago.ViMessages());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData(context);
    });
  }

  Future<void> _fetchData(BuildContext context) async {
    if (mounted) {
      await Provider.of<NotificationService>(context, listen: false)
          .fetchNotifications();
    }
  }

  Future<void> _handleRefresh() async {
    await Provider.of<NotificationService>(context, listen: false).fetchNotifications();
  }

  // ===== HÀM XỬ LÝ ĐIỀU HƯỚNG (ĐÃ FIX) =====
  void _handleNotificationTap(NotificationModel notification) async {
    // 1. Đánh dấu đã đọc (Chạy ngầm, không await để UI nhanh hơn)
    if (!notification.isRead) {
      Provider.of<NotificationService>(context, listen: false)
          .markAsRead(notification.id)
          .catchError((e) => print("Lỗi markRead: $e"));
    }

    // === CASE 1: STORY ===
    if (notification.type == 'react_story' && notification.storyId != null) {
      // A. Hiện thông báo đang kiểm tra
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Đang kiểm tra tin..."),
          duration: Duration(seconds: 1), // Tăng thời gian lên xíu
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(bottom: 100.0, left: 16.0, right: 16.0),
        ),
      );

      try {
        final storyService = Provider.of<StoryService>(context, listen: false);
        // Gọi API (Service đã try-catch nên sẽ trả về null nếu lỗi)
        final Story? story = await storyService.getStoryById(notification.storyId!);

        if (!mounted) return;

        if (story != null) {
          // B1. Có story -> Chuyển trang
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          final group = UserStoryGroup(user: story.user, stories: [story]);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => StoryViewerScreen(storyGroups: [group], initialGroupIndex: 0),
            ),
          );
        } else {
          // B2. Null -> Xóa thông báo
          print("Story is null -> Deleting notification");
          _handleItemDeleted(notification.id, "Story này đã bị xóa.");
        }
      } catch (e) {
        print("UI Error Story: $e");
        if (mounted) _handleItemDeleted(notification.id, "Story này đã bị xóa.");
      }
      return;
    }

    // === CASE 2: POST / COMMENT ===
    if (notification.post != null || notification.targetPostId != null) {
      final postId = notification.post?.id ?? notification.targetPostId;

      if (postId != null) {
        // A. Hiện thông báo
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Đang kiểm tra bài viết..."),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(bottom: 100.0, left: 16.0, right: 16.0),
          ),
        );

        try {
          final postService = Provider.of<PostService>(context, listen: false);
          // Gọi API (Service đã try-catch nên sẽ trả về null nếu lỗi)
          final post = await postService.getPostById(postId);

          if (!mounted) return;

          if (post != null) {
            // C. Có bài -> Chuyển trang
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => PostDetailScreen(postId: postId)),
            );
          } else {
            // D. Null -> Xóa thông báo
            print("Post is null -> Deleting notification");
            _handleItemDeleted(notification.id, "Bài viết này đã bị xóa.");
          }
        } catch (e) {
          print("UI Error Post: $e");
          if (mounted) _handleItemDeleted(notification.id, "Không thể tải bài viết.");
        }
      }
      return;
    }

    // === CASE 3: FRIEND REQUEST ===
    else if (notification.type == 'friend_request' || notification.type == 'accept_friend') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => UserProfileScreen(userId: notification.sender.id)),
      );
    }
  }


  // Hàm phụ trợ: Xử lý khi bài viết/story bị xóa
  void _handleItemDeleted(String notificationId, String message) {
    // 1. Hiện thông báo cho user biết
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 2),
        // 👇👇👇 THÊM 2 DÒNG NÀY ĐỂ NÂNG CAO LÊN 👇👇👇
        behavior: SnackBarBehavior.floating, // Kiểu nổi
        margin: const EdgeInsets.only(
            bottom: 120.0, // Nâng lên 80px (đủ để né bottom bar)
            left: 16.0,
            right: 16.0
        ),
        // 👆👆👆
      ),
    );

    // 2. Xóa thông báo đó khỏi danh sách luôn cho sạch
    Provider.of<NotificationService>(context, listen: false)
        .removeNotificationLocal(notificationId);
  }



  // ===== HÀM DỊCH LOẠI THÔNG BÁO THÀNH TEXT =====
  // ===== HÀM DỊCH LOẠI THÔNG BÁO THÀNH TEXT =====
  TextSpan _buildNotificationContent(NotificationModel notification, Color? textColor) {
    // 1. Xử lý thông báo hệ thống (System, Alert, Promotion...)
    // Admin gửi tin nhắn thì hiển thị trực tiếp nội dung tin nhắn đó
    if (['system', 'alert', 'promotion', 'update'].contains(notification.type)) {
      // Trong Model, mình đã map Title: Message vào field 'comment' rồi
      // Hoặc hiển thị message trực tiếp nếu model hỗ trợ
      return TextSpan(
        style: TextStyle(color: textColor, fontSize: 16),
        children: [
          // Tiêu đề đậm (Sender Name lúc này là "Hệ thống" hoặc "Admin")
          TextSpan(
            text: "${notification.sender.displayName}: ",
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
          ),
          // Nội dung tin nhắn
          TextSpan(text: notification.comment ?? "Bạn có một thông báo mới"),
        ],
      );
    }

    // 2. Xử lý thông báo tương tác (User to User)
    String contentText;
    switch (notification.type) {
      case 'like_post':
      case 'like':
        contentText = ' đã thích bài viết của bạn.';
        break;
      case 'like_comment':
        contentText = ' đã thích bình luận của bạn.';
        break;
      case 'comment_post':
      case 'comment':
        contentText = ' đã bình luận về bài viết của bạn.';
        break;
      case 'reply_comment':
        contentText = ' đã trả lời bình luận của bạn.';
        break;
      case 'react_story':
        contentText = ' đã bày tỏ cảm xúc về tin của bạn.';
        break;
      case 'friend_request':
        contentText = ' đã gửi cho bạn một lời mời kết bạn.';
        break;
      case 'accept_friend':
        contentText = ' đã chấp nhận lời mời kết bạn của bạn.';
        break;
      default:
        contentText = ' đã tương tác với bạn.';
    }

    return TextSpan(
      style: TextStyle(color: textColor, fontSize: 16),
      children: [
        TextSpan(
          text: notification.sender.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        TextSpan(text: contentText),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    // Lấy màu từ Theme
    final scaffoldBgColor = Theme.of(context).scaffoldBackgroundColor;
    final appBarBgColor = Theme.of(context).appBarTheme.backgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final dividerColor = Theme.of(context).dividerColor;

    return Scaffold(
      backgroundColor: scaffoldBgColor, // SỬA: Màu nền động
      appBar: AppBar(
        title: Text('Thông báo',
            style: TextStyle(
                color: textColor, // SỬA: Màu chữ tiêu đề động
                fontSize: 24,
                fontWeight: FontWeight.bold)),
        backgroundColor: appBarBgColor, // SỬA: Màu nền AppBar động
        elevation: 0.5,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: Colors.blue),
            tooltip: 'Đánh dấu đã đọc tất cả',
            onPressed: () {
              Provider.of<NotificationService>(context, listen: false).markAllAsRead();
            },
          )
        ],
      ),
      body: Consumer<NotificationService>(
        builder: (context, notificationService, child) {
          if (notificationService.isLoading && notificationService.notifications.isEmpty) {
            return const Center(child: CupertinoActivityIndicator());
          }

          if (notificationService.notifications.isEmpty) {
            return RefreshIndicator(
              onRefresh: _handleRefresh,
              child: Stack(
                children: [
                  ListView(),
                  Center(
                    child: Text('Bạn chưa có thông báo nào.', style: TextStyle(color: textColor)), // SỬA: Màu chữ
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _handleRefresh,
            color: CupertinoColors.activeBlue,
            child: ListView.separated(
              separatorBuilder: (context, index) => Divider(height: 1, indent: 80, thickness: 0.5, color: dividerColor), // SỬA: Màu divider
              itemCount: notificationService.notifications.length,
              itemBuilder: (context, index) {
                final notification = notificationService.notifications[index];
                return _buildNotificationItem(notification, textColor);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(NotificationModel notification, Color? textColor) {
    // Logic màu nền: Đã đọc = màu card, Chưa đọc = Xanh nhạt (opacity thấp để hợp cả sáng/tối)
    final readColor = Theme.of(context).cardColor;
    final unreadColor = Colors.blue.withOpacity(0.1); // Màu xanh rất nhạt

    return Container(
      color: notification.isRead ? readColor : unreadColor,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        onTap: () => _handleNotificationTap(notification),

        // Tìm đoạn leading: CircleAvatar trong hàm _buildNotificationItem
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: ['system', 'alert', 'promotion'].contains(notification.type)
              ? Colors.orange.withOpacity(0.1) // Màu nền cho System
              : Colors.grey.shade200,

          backgroundImage: (notification.sender.avatarUrl != null && notification.sender.avatarUrl!.isNotEmpty)
              ? NetworkImage(notification.sender.avatarUrl!)
              : null,

          child: (notification.sender.avatarUrl == null || notification.sender.avatarUrl!.isEmpty)
              ? (['system', 'alert', 'promotion'].contains(notification.type)
              ? const Icon(Icons.campaign, color: Colors.deepOrange, size: 28) // Icon Loa cho System
              : const Icon(CupertinoIcons.person_fill, color: Colors.grey, size: 28)) // Icon người mặc định
              : null,
        ),


        // Nội dung
        title: Text.rich(
          _buildNotificationContent(notification, textColor),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),

        // Thời gian
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            timeago.format(notification.createdAt, locale: 'vi'),
            style: TextStyle(
              // Đã đọc: màu xám, Chưa đọc: màu xanh
                color: notification.isRead ? Colors.grey[600] : Colors.blue[700],
                fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                fontSize: 13
            ),
          ),
        ),

        // Chấm xanh
        trailing: !notification.isRead
            ? Container(
          margin: const EdgeInsets.only(left: 10),
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
        )
            : null,
        isThreeLine: true,
      ),
    );
  }
}
