// File: lib/models/story_model.dart

import 'package:flutter_maps/models/user_model.dart';

enum MediaType { text, image, video }

class Reaction {
  final UserModel user;
  final String type;

  Reaction({required this.user, required this.type});

  factory Reaction.fromJson(Map<String, dynamic> json, {String? baseUrl}) {
    UserModel userObj;

    if (json['user'] is Map<String, dynamic>) {
      userObj = UserModel.fromJson(json['user'], baseUrl: baseUrl);
    } else {
      userObj = UserModel(
        id: json['user'].toString(),
        username: 'Unknown',
        displayName: 'Người dùng',
        email: '',
        friends: [],
        sentFriendRequests: [],
        receivedFriendRequests: [],
        avatarUrl: null,
      );
    }

    return Reaction(
      user: userObj,
      type: json['type'] ?? 'like',
    );
  }
}

class Story {
  final String id;
  final UserModel user;
  final String? mediaUrl;
  final MediaType mediaType;
  final DateTime createdAt;
  final List<String> viewerIds;
  final String? text;
  final String? style;

  final String? musicUrl;
  final String? musicName; // <--- MỚI: Thêm trường này

  final List<Reaction> reactions;
  bool isViewed;

  Story({
    required this.id,
    required this.user,
    this.mediaUrl,
    required this.mediaType,
    required this.createdAt,
    required this.viewerIds,
    this.text,
    this.style,

    this.musicUrl,
    this.musicName, // <--- MỚI: Thêm vào constructor

    this.reactions = const [],
    this.isViewed = false,
  });

  factory Story.fromJson(Map<String, dynamic> json, {String? baseUrl, UserModel? author, String? currentUserId}) {
    UserModel userObj;
    if (author != null) {
      userObj = author;
    } else if (json['user'] != null) {
      if (json['user'] is Map<String, dynamic>) {
        userObj = UserModel.fromJson(json['user'], baseUrl: baseUrl);
      } else {
        userObj = UserModel(
            id: json['user'].toString(),
            username: '', displayName: '', email: '', friends: [],
            sentFriendRequests: [], receivedFriendRequests: [], avatarUrl: null
        );
      }
    } else {
      throw Exception("Story missing user data");
    }

    String? processedMediaUrl;
    if (json['mediaUrl'] != null) {
      if (json['mediaUrl'].toString().startsWith('http')) {
        processedMediaUrl = json['mediaUrl'];
      } else {
        processedMediaUrl = '$baseUrl/${json['mediaUrl']}'.replaceAll(RegExp(r'(?<!:)/+'), '/');
      }
    }

    var reactionsList = json['reactions'] as List? ?? [];
    List<Reaction> parsedReactions = reactionsList
        .map((r) => Reaction.fromJson(r, baseUrl: baseUrl))
        .toList();

    List<String> viewers = (json['viewerIds'] as List?)?.map((e) => e.toString()).toList() ?? [];

    bool viewedStatus = false;
    if (currentUserId != null) {
      viewedStatus = viewers.contains(currentUserId);
    }

    return Story(
      id: json['_id'],
      user: userObj,
      mediaUrl: processedMediaUrl,
      mediaType: _parseMediaType(json['mediaType']),
      createdAt: DateTime.parse(json['createdAt']),
      viewerIds: viewers,
      text: json['text'],
      style: json['style'],

      musicUrl: json['musicUrl'],
      musicName: json['musicName'], // <--- MỚI: Lấy từ JSON

      reactions: parsedReactions,
      isViewed: viewedStatus,
    );
  }

  static MediaType _parseMediaType(String? type) {
    if (type == 'video') return MediaType.video;
    if (type == 'text') return MediaType.text;
    return MediaType.image;
  }
}

class UserStoryGroup {
  final UserModel user;
  final List<Story> stories;

  UserStoryGroup({required this.user, required this.stories});

  factory UserStoryGroup.fromJson(Map<String, dynamic> json, {String? baseUrl, String? currentUserId}) {
    UserModel userObj;
    if (json['user'] is Map<String, dynamic>) {
      userObj = UserModel.fromJson(json['user'], baseUrl: baseUrl);
    } else {
      userObj = UserModel(id: 'unknown', username: '', displayName: '', email: '', friends: [], sentFriendRequests: [], receivedFriendRequests: [], avatarUrl: null);
    }

    var list = json['stories'] as List;
    List<Story> storyList = list.map((i) => Story.fromJson(i, baseUrl: baseUrl, author: userObj, currentUserId: currentUserId)).toList();

    return UserStoryGroup(user: userObj, stories: storyList);
  }
}
