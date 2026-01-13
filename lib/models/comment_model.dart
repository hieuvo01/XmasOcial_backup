// Dán toàn bộ code này vào file: lib/models/comment_model.dart

import 'package:flutter_maps/models/reaction_model.dart';
import 'package:flutter_maps/models/user_model.dart';

class Comment {
  final String id;
  final String content;
  final UserModel author;
  final String post;
  final List<ReactionModel> reactions;
  final String createdAt;
  final List<Comment> replies;

  // ===== BƯỚC 1: THÊM TRƯỜNG `parentId` CÒN THIẾU VÀO ĐÂY =====
  final String? parentId; // ID của comment cha, có thể null.
  // =========================================================

  Comment({
    required this.id,
    required this.content,
    required this.author,
    required this.post,
    required this.reactions,
    required this.createdAt,
    required this.replies,
    this.parentId, // Thêm vào constructor
  });

  factory Comment.fromJson(Map<String, dynamic> json, {String? baseUrl}) {
    // ---- Parse các trường cơ bản ----
    final authorJson = json['author'];
    final author = (authorJson != null && authorJson is Map<String, dynamic>)
        ? UserModel.fromJson(authorJson, baseUrl: baseUrl)
        : UserModel.anonymous();

    var reactionsFromJson = json['reactions'] as List? ?? [];
    List<ReactionModel> reactionList = reactionsFromJson
        .map((r) => ReactionModel.fromJson(r as Map<String, dynamic>))
        .toList();

    // ---- Parse danh sách REPLIES (logic của bạn đã đúng) ----
    var repliesFromJson = json['replies'] as List? ?? [];
    List<Comment> replyList = [];
    if (repliesFromJson.isNotEmpty) {
      replyList = repliesFromJson
          .map((replyJson) =>
          Comment.fromJson(replyJson as Map<String, dynamic>, baseUrl: baseUrl))
          .toList();
    }
    // --------------------------------------------------------

    return Comment(
      id: json['_id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      author: author,
      post: json['post'] as String? ?? '',
      reactions: reactionList,
      createdAt: json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      replies: replyList,
      // ===== BƯỚC 2: PARSE `parentId` TỪ JSON =====
      parentId: json['parentId'] as String?, // Lấy parentId từ JSON
      // ===========================================
    );
  }

  // ===== BƯỚC 3: SỬA LẠI HÀM `copyWith` ĐỂ BAO GỒM `parentId` =====
  Comment copyWith({
    String? id,
    String? content,
    UserModel? author,
    String? post,
    List<ReactionModel>? reactions,
    String? createdAt,
    List<Comment>? replies,
    String? parentId, // Thêm tham số parentId
  }) {
    return Comment(
      id: id ?? this.id,
      content: content ?? this.content,
      author: author ?? this.author,
      post: post ?? this.post,
      reactions: reactions ?? this.reactions,
      createdAt: createdAt ?? this.createdAt,
      replies: replies ?? this.replies,
      parentId: parentId ?? this.parentId, // Gán giá trị cho parentId
    );
  }
}
