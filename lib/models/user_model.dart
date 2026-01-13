// File: lib/models/user_model.dart

class UserModel {
  final String id;
  final String displayName;
  final String username;
  final String email;
  final String? avatarUrl;
  final String? coverUrl;
  final String? bio;
  final String? location;
  final DateTime? birthDate;
  final String? website;
  final DateTime? lastActive;
  final List<UserModel> friends;
  final List<String> sentFriendRequests;
  final List<String> receivedFriendRequests;
  final DateTime? createdAt;

  // 1. CÁC BIẾN TRẠNG THÁI & PHÂN QUYỀN
  final bool isOnline;
  final bool isAdmin;
  final String role;

  String get name => displayName;

  UserModel({
    required this.id,
    required this.displayName,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.coverUrl,
    this.bio,
    this.location,
    this.birthDate,
    this.website,
    this.lastActive,
    this.createdAt,
    required this.friends,
    required this.sentFriendRequests,
    required this.receivedFriendRequests,

    // 2. DEFAULT VALUES
    this.isOnline = false,
    this.isAdmin = false,
    this.role = 'user',
  });

  factory UserModel.fromJson(Map<String, dynamic> json, {String? baseUrl}) {
    List<String> _mapToStringList(dynamic list) {
      if (list is List) {
        return list.map((item) => item.toString()).toList();
      }
      return [];
    }

    // 🔥 Hàm helper xử lý URL thông minh (Fix lỗi 404 avatar/cover)
    String? _formatUrl(String? url, String? base) {
      if (url == null || url.isEmpty) return null;
      // Nếu link đã là link tuyệt đối (Cloudinary https://...) thì giữ nguyên
      if (url.startsWith('http')) return url;
      // Nếu không có baseUrl thì trả về link gốc
      if (base == null) return url;

      // Nếu link là link tương đối (ví dụ: /uploads/avatar...) thì cộng thêm baseUrl
      if (url.startsWith('/')) {
        return '$base$url';
      } else {
        return '$base/$url';
      }
    }

    try {
      final avatarRaw = json['avatarUrl'] as String? ?? json['avatar_url'] as String?;
      String? finalAvatarUrl = _formatUrl(avatarRaw, baseUrl);

      final coverRaw = json['coverUrl'] as String?;
      String? finalCoverUrl = _formatUrl(coverRaw, baseUrl);

      List<UserModel> parsedFriends = [];
      if (json['friends'] != null && json['friends'] is List) {
        final friendList = json['friends'] as List;
        for (var friendData in friendList) {
          if (friendData is Map<String, dynamic>) {
            parsedFriends.add(UserModel.fromJson(friendData, baseUrl: baseUrl));
          }
        }
      }

      String parsedRole = json['role'] ?? 'user';
      if (json['role'] == null && json['isAdmin'] == true) {
        parsedRole = 'admin';
      }

      return UserModel(
        id: json['_id'] as String? ?? json['id'] as String? ?? '',
        displayName: json['displayName'] as String? ?? 'Người dùng',
        username: json['username'] as String? ?? 'no_username',
        email: json['email'] as String? ?? 'no_email',
        avatarUrl: finalAvatarUrl,
        coverUrl: finalCoverUrl,
        bio: json['bio'] as String?,
        location: json['location'] as String?,
        website: json['website'] as String?,
        birthDate: json['birthDate'] != null
            ? DateTime.tryParse(json['birthDate'].toString())
            : null,
        lastActive: json['lastActive'] != null
            ? DateTime.tryParse(json['lastActive'].toString())
            : null,
        friends: parsedFriends,
        sentFriendRequests: _mapToStringList(json['sentFriendRequests']),
        receivedFriendRequests: _mapToStringList(json['receivedFriendRequests']),
        isOnline: json['isOnline'] ?? false,
        isAdmin: json['isAdmin'] ?? (parsedRole == 'admin'),
        role: parsedRole,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'].toString())
            : null,
      );
    } catch (e) {
      print('--- LỖI PARSE USER JSON: $e ---');
      throw Exception('Không thể phân tích dữ liệu người dùng.');
    }
  }

  factory UserModel.anonymous() {
    return UserModel(
      id: 'anonymous_user_id',
      displayName: 'Người dùng ẩn danh',
      username: 'anonymous',
      email: '',
      avatarUrl: null,
      coverUrl: null,
      bio: null,
      location: null,
      birthDate: null,
      website: null,
      lastActive: null,
      friends: [],
      sentFriendRequests: [],
      receivedFriendRequests: [],
      isOnline: false,
      isAdmin: false,
      role: 'user',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'displayName': displayName,
      'username': username,
      'email': email,
      'avatarUrl': avatarUrl,
      'coverUrl': coverUrl,
      'bio': bio,
      'location': location,
      'website': website,
      'birthDate': birthDate?.toIso8601String(),
      'lastActive': lastActive?.toIso8601String(),
      'friends': friends.map((friend) => friend.id).toList(),
      'sentFriendRequests': sentFriendRequests,
      'receivedFriendRequests': receivedFriendRequests,
      'isOnline': isOnline,
      'isAdmin': isAdmin,
      'role': role,
    };
  }

  UserModel copyWith({
    String? id,
    String? displayName,
    String? username,
    String? email,
    String? avatarUrl,
    String? coverUrl,
    String? bio,
    String? location,
    DateTime? birthDate,
    String? website,
    DateTime? lastActive,
    List<UserModel>? friends,
    List<String>? sentFriendRequests,
    List<String>? receivedFriendRequests,
    bool? isOnline,
    bool? isAdmin,
    String? role,
  }) {
    return UserModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      birthDate: birthDate ?? this.birthDate,
      website: website ?? this.website,
      lastActive: lastActive ?? this.lastActive,
      friends: friends ?? this.friends,
      sentFriendRequests: sentFriendRequests ?? this.sentFriendRequests,
      receivedFriendRequests: receivedFriendRequests ?? this.receivedFriendRequests,
      isOnline: isOnline ?? this.isOnline,
      isAdmin: isAdmin ?? this.isAdmin,
      role: role ?? this.role,
    );
  }
}
