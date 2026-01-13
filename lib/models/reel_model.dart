// File: lib/models/reel_model.dart

import 'user_model.dart';

class Reel {
  final String id;
  final String videoUrl;
  final String? thumbnailUrl;
  final String description;
  final UserModel user;
  final int likeCount;
  final int commentCount;
  final bool isExternal; // Check xem là video Pexels hay User up
  final List<String> likes;
  Reel({
    required this.id,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.description,
    required this.user,
    this.likeCount = 0,
    this.commentCount = 0,
    required this.likes,
    this.isExternal = false,
  });

  factory Reel.fromJson(Map<String, dynamic> json, {String? baseUrl}) {
    // Xử lý user object
    UserModel userObj;
    if (json['user'] != null) {
      // Nếu là Pexels (isExternal = true) thì user structure có thể khác chút
      // nhưng ở Backend mình đã map lại cho giống rồi nên cứ parse bình thường
      userObj = UserModel.fromJson(json['user'], baseUrl: baseUrl);
    } else {
      userObj = UserModel(id: 'unknown', username: 'Pexels', displayName: 'Pexels Video', email: '', friends: [], sentFriendRequests: [], receivedFriendRequests: [], avatarUrl: null);
    }

    // Xử lý URL video (Nếu là Pexels thì link full rồi, nếu local thì nối baseUrl)
    String vidUrl = json['videoUrl'];
    if (!vidUrl.startsWith('http') && baseUrl != null) {
      vidUrl = '$baseUrl/$vidUrl'.replaceAll(RegExp(r'(?<!:)/+'), '/');
    }

    return Reel(
      id: json['_id'] ?? '',
      videoUrl: vidUrl,
      thumbnailUrl: json['thumbnailUrl'],
      description: json['description'] ?? '',
      user: userObj,
      likeCount: (json['likes'] as List?)?.length ?? 0,
      commentCount: (json['comments'] as List?)?.length ?? 0,
      isExternal: json['isExternal'] ?? false,
      likes: json['likes'] != null
          ? List<String>.from(json['likes'].map((x) => x.toString()))
          : [],
    );
  }
}
