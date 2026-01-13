// Dán toàn bộ code này vào file: lib/models/reaction_model.dart

import './user_model.dart'; // <-- QUAN TRỌNG: Import UserModel để có thể sử dụng

class ReactionModel {
  // ===== SỬA BƯỚC 1: Thay đổi kiểu dữ liệu của 'user' =====
  final UserModel user; // Đổi từ 'final String user;' thành 'final UserModel user;'
  // ========================================================

  final String type; // 'like', 'love', ...

  ReactionModel({
    required this.user,
    required this.type
  });

  factory ReactionModel.fromJson(Map<String, dynamic> json) {
    // ===== SỬA BƯỚC 2: Cập nhật logic parse JSON =====
    // Giờ đây chúng ta mong đợi 'user' là một object đầy đủ từ server
    // và dùng UserModel.fromJson để parse nó.
    return ReactionModel(
      user: (json['user'] != null && json['user'] is Map<String, dynamic>)
          ? UserModel.fromJson(json['user'])
          : UserModel.anonymous(), // Nếu user null, trả về một user ẩn danh để tránh lỗi
      type: json['type'] as String? ?? 'like',
    );
    // ====================================================
  }

  // Hàm copyWith được cập nhật để phù hợp với kiểu UserModel mới
  ReactionModel copyWith({
    UserModel? user,
    String? type,
  }) {
    return ReactionModel(
      user: user ?? this.user,
      type: type ?? this.type,
    );
  }
}
