// File: lib/models/notification_model.dart

import 'post_model.dart';
import 'user_model.dart';

class NotificationModel {
  final String id;
  final UserModel sender;
  final String type;
  bool isRead;
  final DateTime createdAt;

  // CÁC TRƯỜNG DỮ LIỆU LIÊN KẾT
  final Post? post;
  final String? comment; // Dùng chung cho Comment content và Admin Message
  final String? targetPostId;
  final String? storyId;

  NotificationModel({
    required this.id,
    required this.sender,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.post,
    this.comment,
    this.targetPostId,
    this.storyId,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json, {String? baseUrl}) {
    // 1. Xử lý Post & Lấy targetPostId
    Post? parsedPost;
    String? tempPostId;

    if (json['post'] != null) {
      if (json['post'] is Map<String, dynamic>) {
        tempPostId = json['post']['_id'];
        try {
          parsedPost = Post.fromJson(json['post'], baseUrl: baseUrl);
        } catch (e) {
          // Bỏ qua lỗi parse post
        }
      } else if (json['post'] is String) {
        tempPostId = json['post'];
      }
    }

    // 2. Xử lý Sender
    UserModel senderObj;
    try {
      senderObj = UserModel.fromJson(json['sender'] as Map<String, dynamic>, baseUrl: baseUrl);
    } catch(e) {
      senderObj = UserModel(
          id: 'unknown',
          displayName: 'Hệ thống', // Fallback name an toàn hơn
          username: 'system',
          email: '',
          friends: [],
          sentFriendRequests: [],
          receivedFriendRequests: [],
          avatarUrl: null
      );
    }

    // 3. Xử lý createdAt
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['createdAt'] as String);
    } catch (e) {
      parsedDate = DateTime.now();
    }

    // 4. Xử lý Nội dung (QUAN TRỌNG: Gộp cả Comment và Message Admin)
    String? contentToShow;

    // A. Kiểm tra nếu là thông báo hệ thống/admin (Có title & message)
    if (['system', 'alert', 'promotion', 'update'].contains(json['type'])) {
      String title = json['title'] ?? '';
      String msg = json['message'] ?? '';

      if (title.isNotEmpty && msg.isNotEmpty) {
        contentToShow = "$title: $msg";
      } else {
        contentToShow = msg.isNotEmpty ? msg : title;
      }
    }
    // B. Nếu không phải hệ thống, kiểm tra comment thông thường
    else if (json['comment'] != null) {
      if (json['comment'] is Map) {
        contentToShow = json['comment']['content'];
      } else if (json['comment'] is String) {
        contentToShow = json['comment'];
      }
    }

    // 5. Xử lý Story
    String? tempStoryId;
    if (json['story'] != null) {
      if (json['story'] is Map) {
        tempStoryId = json['story']['_id'];
      } else {
        tempStoryId = json['story'].toString();
      }
    }

    return NotificationModel(
      id: json['_id'] as String? ?? '',
      sender: senderObj,
      type: json['type'] as String? ?? 'unknown',
      isRead: json['isRead'] as bool? ?? false,
      createdAt: parsedDate,
      post: parsedPost,
      targetPostId: tempPostId,
      comment: contentToShow, // Gán nội dung đã xử lý vào đây
      storyId: tempStoryId,
    );
  }
}
