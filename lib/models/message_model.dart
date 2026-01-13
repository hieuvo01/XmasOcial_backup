// File: lib/models/message_model.dart

import 'user_model.dart';

class Message {
  final String id;
  final UserModel sender;
  final String content;
  final String? type;
  final DateTime createdAt;
  bool isRead;
  String? reaction;

  // --- 1. BIẾN HỨNG CỜ THU HỒI ---
  final bool isRecalled;

  // --- 2. BIẾN CHO TÍNH NĂNG REPLY (TRẢ LỜI) ---
  final Message? replyTo; // <--- MỚI THÊM

  Message({
    required this.id,
    required this.sender,
    required this.content,
    this.type = 'text',
    required this.createdAt,
    this.isRead = false,
    this.reaction,
    this.isRecalled = false,
    this.replyTo, // <--- MỚI THÊM VÀO CONSTRUCTOR
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['_id'] ?? '',
      sender: (json['sender'] is Map)
          ? UserModel.fromJson(json['sender'])
          : UserModel.anonymous(),
      content: json['content'] ?? '',
      type: json['type'] ?? 'text',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      isRead: json['isRead'] ?? false,
      reaction: json['reaction'],

      // --- MAP DỮ LIỆU TỪ SERVER ---
      isRecalled: json['isRecalled'] ?? false,

      // --- MAP DỮ LIỆU REPLY ---
      // Kiểm tra nếu server trả về object replyTo (đã populate) thì parse nó
      replyTo: (json['replyTo'] != null && json['replyTo'] is Map)
          ? Message.fromJson(json['replyTo'])
          : null,
    );
  }
}

// Model cho cuộc trò chuyện
class Conversation {
  final String id;
  final List<UserModel> participants;
  final Message? lastMessage;
  final int unreadCount;
  final DateTime updatedAt;

  // --- 3. BIẾN LƯU THEME CỦA CUỘC TRÒ CHUYỆN ---
  final String? themeId;
  final String? quickReaction;
  final Map<String, String> nicknames;

  Conversation({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.unreadCount = 0,
    required this.updatedAt,
    this.themeId,
    this.quickReaction,
    this.nicknames = const {},
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    var list = json['participants'] as List? ?? [];
    List<UserModel> participantList = list.map((i) {
      if (i is Map<String, dynamic>) {
        return UserModel.fromJson(i);
      }
      return UserModel.anonymous();
    }).toList();

    return Conversation(
      id: json['_id'] ?? '',
      participants: participantList,
      lastMessage: json['lastMessage'] != null
          ? Message.fromJson(json['lastMessage'])
          : null,
      unreadCount: json['unreadCount'] ?? 0,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),

      // --- LẤY THEME ID TỪ SERVER ---
      themeId: json['themeId'],
      quickReaction: json['quickReaction'],
      nicknames: json['nicknames'] != null
          ? Map<String, String>.from(json['nicknames'])
          : {},
    );
  }
}
