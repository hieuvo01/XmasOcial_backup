// Dán toàn bộ code này vào file: lib/models/post_model.dart

import 'package:flutter_maps/models/reaction_model.dart';
import 'package:flutter_maps/models/user_model.dart';
import 'comment_model.dart';

class Post {
  final String id;
  String content;

  // 👇👇👇 THAY ĐỔI: Thay imageUrl (String) bằng mediaUrls (List) 👇👇👇
  // Code cũ: final String? imageUrl;
  final List<String> mediaUrls;
  // 👆👆👆

  final UserModel author;
  final List<ReactionModel> reactions;
  final List<Comment> comments;
  final DateTime createdAt;
  int commentCount;

  Post({
    required this.id,
    required this.content,
    required this.mediaUrls, // Cập nhật constructor
    required this.author,
    required this.reactions,
    required this.comments,
    required this.createdAt,
    required this.commentCount,
  });

  // Getter hỗ trợ để code cũ đỡ lỗi (lấy ảnh đầu tiên nếu có)
  String? get imageUrl => mediaUrls.isNotEmpty ? mediaUrls.first : null;

  Post copyWith({
    String? id,
    String? content,
    List<String>? mediaUrls,
    UserModel? author,
    List<ReactionModel>? reactions,
    List<Comment>? comments,
    DateTime? createdAt,
    int? commentCount,
  }) {
    return Post(
      id: id ?? this.id,
      content: content ?? this.content,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      author: author ?? this.author,
      reactions: reactions ?? this.reactions,
      comments: comments ?? this.comments,
      createdAt: createdAt ?? this.createdAt,
      commentCount: commentCount ?? this.commentCount,
    );
  }

  Post.clone(Post post)
      : this(
    id: post.id,
    content: post.content,
    mediaUrls: List<String>.from(post.mediaUrls),
    author: post.author,
    createdAt: post.createdAt,
    commentCount: post.commentCount,
    reactions: List<ReactionModel>.from(post.reactions),
    comments: List<Comment>.from(post.comments),
  );

  factory Post.fromJson(Map<String, dynamic> json, {String? baseUrl}) {
    var commentsFromJson = json['comments'] as List? ?? [];
    List<Comment> commentList =
    commentsFromJson.map((c) => Comment.fromJson(c, baseUrl: baseUrl)).toList();

    // 👇👇👇 LOGIC PARSE MẢNG MEDIA 👇👇👇
    List<String> parsedMedia = [];

    // 1. Kiểm tra trường 'media' mới (dạng mảng)
    if (json['media'] != null && json['media'] is List) {
      parsedMedia = (json['media'] as List).map((item) {
        String url = item.toString();
        if (baseUrl != null && url.startsWith('/')) {
          return baseUrl + url;
        }
        return url;
      }).toList();
    }
    // 2. Fallback: Nếu không có 'media', thử lấy 'imageUrl' cũ (để hỗ trợ bài viết cũ)
    else if (json['imageUrl'] != null && json['imageUrl'].toString().isNotEmpty) {
      String url = json['imageUrl'].toString();
      if (baseUrl != null && url.startsWith('/')) {
        parsedMedia.add(baseUrl + url);
      } else {
        parsedMedia.add(url);
      }
    }
    // 👆👆👆

    var reactionsFromJson = json['reactions'] as List?;
    List<ReactionModel> reactionList =
        reactionsFromJson?.map((i) => ReactionModel.fromJson(i)).toList() ?? [];

    DateTime parsedDate;
    try {
      final dateString = json['createdAt'] as String?;
      if (dateString != null && dateString.isNotEmpty) {
        parsedDate = DateTime.parse(dateString);
      } else {
        parsedDate = DateTime.now();
      }
    } catch (e) {
      parsedDate = DateTime.now();
    }

    return Post(
      id: json['_id'] as String? ?? '',
      content: json['content'] as String? ?? '[Nội dung không có sẵn]',
      mediaUrls: parsedMedia, // Gán list mới parse được
      author: (json['author'] != null && json['author'] is Map<String, dynamic>)
          ? UserModel.fromJson(json['author'] as Map<String, dynamic>,
          baseUrl: baseUrl)
          : UserModel.anonymous(),
      reactions: reactionList,
      comments: commentList,
      createdAt: parsedDate,
      commentCount: json['commentCount'] ?? 0,
    );
  }
}
