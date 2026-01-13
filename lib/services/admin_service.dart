// File: lib/services/admin_service.dart

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../models/user_model.dart'; // Đảm bảo import UserModel nếu dùng
import '../models/post_model.dart';
import 'auth_service.dart';

class AdminService with ChangeNotifier {
  final Dio _dio = Dio();
  final String _baseUrl = AppConfig.baseUrl;

  // Helper để lấy Header chứa Token
  Options _getAuthOptions(BuildContext context) {
    final token = Provider.of<AuthService>(context, listen: false).token;
    return Options(headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    });
  }

  // ============================================
  // 1. QUẢN LÝ NGƯỜI DÙNG (USER)
  // ============================================

  // Lấy danh sách tất cả user (Trả về List<dynamic> để linh hoạt hoặc UserModel tùy bro)
  Future<List<dynamic>> getAllUsers(BuildContext context) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/api/users',
        options: _getAuthOptions(context),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Không thể tải danh sách người dùng');
      }
    } catch (e) {
      print("❌ Lỗi AdminService getAllUsers: $e");
      // Trả về list rỗng để UI không bị crash
      return [];
    }
  }

  // Xóa user theo ID
  Future<void> deleteUser(BuildContext context, String userId) async {
    try {
      await _dio.delete(
        '$_baseUrl/api/users/$userId',
        options: _getAuthOptions(context),
      );
    } catch (e) {
      print("❌ Lỗi AdminService deleteUser: $e");
      throw Exception('Xóa người dùng thất bại');
    }
  }

  // Cập nhật thông tin User (Admin Edit - Bao gồm cả đổi Role)
  Future<void> updateUser(BuildContext context, String userId, Map<String, dynamic> data) async {
    try {
      await _dio.put(
        '$_baseUrl/api/users/$userId/admin-update',
        data: data,
        options: _getAuthOptions(context),
      );
    } catch (e) {
      print("❌ Lỗi AdminService updateUser: $e");
      throw Exception('Cập nhật thất bại');
    }
  }

  // 👇 MỚI: Khóa User (Block)
  Future<void> blockUser(BuildContext context, String id) async {
    try {
      await _dio.put(
        '$_baseUrl/api/users/$id/block',
        options: _getAuthOptions(context),
      );
    } catch (e) {
      print("❌ Lỗi blockUser: $e");
      throw Exception('Khóa thất bại');
    }
  }

  // 👇 MỚI: Mở khóa User (Unblock)
  Future<void> unblockUser(BuildContext context, String id) async {
    try {
      await _dio.put(
        '$_baseUrl/api/users/$id/block', // Gọi cùng endpoint vì backend dùng toggle
        options: _getAuthOptions(context),
      );
    } catch (e) {
      print("❌ Lỗi unblockUser: $e");
      throw Exception('Mở khóa thất bại');
    }
  }

  // Hàm cũ: Cập nhật Role riêng lẻ (Nếu cần giữ lại tương thích code cũ)
  Future<void> updateUserRole(BuildContext context, String userId, String newRole) async {
    try {
      await _dio.put(
        '$_baseUrl/api/users/$userId/role',
        data: {'role': newRole},
        options: _getAuthOptions(context),
      );
    } catch (e) {
      print("❌ Lỗi AdminService updateUserRole: $e");
      throw Exception('Cập nhật quyền thất bại');
    }
  }

  // ============================================
  // 2. QUẢN LÝ BÀI VIẾT (POST)
  // ============================================

  Future<List<Post>> getAllPosts(BuildContext context) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/api/posts/admin/all',
        options: _getAuthOptions(context),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => Post.fromJson(json, baseUrl: _baseUrl)).toList();
      } else {
        throw Exception('Không thể tải danh sách bài viết');
      }
    } catch (e) {
      print("❌ Lỗi AdminService getAllPosts: $e");
      rethrow;
    }
  }

  Future<void> deletePost(BuildContext context, String postId) async {
    try {
      await _dio.delete(
        '$_baseUrl/api/posts/admin/$postId',
        options: _getAuthOptions(context),
      );
    } catch (e) {
      print("❌ Lỗi AdminService deletePost: $e");
      throw Exception('Xóa bài viết thất bại');
    }
  }

  Future<void> updatePost(BuildContext context, String postId, String newContent) async {
    try {
      await _dio.put(
        '$_baseUrl/api/posts/admin/$postId',
        data: {'content': newContent},
        options: _getAuthOptions(context),
      );
    } catch (e) {
      print("❌ Lỗi AdminService updatePost: $e");
      throw Exception('Cập nhật bài viết thất bại');
    }
  }

  // ============================================
  // 3. THỐNG KÊ DASHBOARD
  // ============================================

  Future<Map<String, dynamic>> getDashboardStats(BuildContext context) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/api/users/admin/stats',
        options: _getAuthOptions(context),
      );
      return response.data;
    } catch (e) {
      print("❌ Lỗi AdminService getDashboardStats: $e");
      return {'users': 0, 'posts': 0, 'comments': 0};
    }
  }

  // ============================================
  // 4. QUẢN LÝ BÌNH LUẬN (COMMENTS)
  // ============================================

  Future<List<dynamic>> getAllComments(BuildContext context) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/api/comments/admin/all',
        options: _getAuthOptions(context),
      );
      return response.data;
    } catch (e) {
      print("❌ Lỗi AdminService getAllComments: $e");
      return [];
    }
  }

  Future<void> updateComment(BuildContext context, String commentId, String newContent) async {
    try {
      await _dio.put(
        '$_baseUrl/api/comments/admin/$commentId',
        data: {'content': newContent},
        options: _getAuthOptions(context),
      );
    } catch (e) {
      print("❌ Lỗi AdminService updateComment: $e");
      throw Exception('Sửa bình luận thất bại');
    }
  }

  Future<void> deleteComment(BuildContext context, String commentId) async {
    try {
      await _dio.delete(
        '$_baseUrl/api/comments/admin/$commentId',
        options: _getAuthOptions(context),
      );
    } catch (e) {
      print("❌ Lỗi AdminService deleteComment: $e");
      throw Exception('Xóa bình luận thất bại');
    }
  }

  // ============================================
  // 5. QUẢN LÝ STORIES
  // ============================================
  Future<List<dynamic>> getAllStories(BuildContext context) async {
    try {
      final response = await _dio.get('$_baseUrl/api/stories/admin/all', options: _getAuthOptions(context));
      return response.data;
    } catch (e) {
      print("❌ Lỗi AdminService getAllStories: $e");
      return [];
    }
  }

  Future<void> deleteStory(BuildContext context, String storyId) async {
    try {
      await _dio.delete('$_baseUrl/api/stories/admin/$storyId', options: _getAuthOptions(context));
    } catch (e) {
      print("❌ Lỗi deleteStory: $e");
    }
  }

  // ============================================
  // 6. QUẢN LÝ REELS
  // ============================================
  Future<List<dynamic>> getAllReels(BuildContext context) async {
    try {
      final response = await _dio.get('$_baseUrl/api/reels/admin/all', options: _getAuthOptions(context));
      return response.data;
    } catch (e) {
      print("❌ Lỗi AdminService getAllReels: $e");
      return [];
    }
  }

  Future<void> deleteReel(BuildContext context, String reelId) async {
    try {
      await _dio.delete('$_baseUrl/api/reels/admin/$reelId', options: _getAuthOptions(context));
    } catch (e) {
      print("❌ Lỗi deleteReel: $e");
    }
  }

  // ============================================
  // 7. QUẢN LÝ AI CHARACTERS
  // ============================================

  Future<List<dynamic>> getAllAICharacters(BuildContext context) async {
    try {
      final response = await _dio.get('$_baseUrl/api/ai/admin/characters', options: _getAuthOptions(context));
      return response.data;
    } catch (e) {
      print("❌ Lỗi AdminService getAllAICharacters: $e");
      return [];
    }
  }

  Future<void> createAICharacter(BuildContext context, Map<String, dynamic> data) async {
    try {
      await _dio.post('$_baseUrl/api/ai/admin/characters', data: data, options: _getAuthOptions(context));
    } catch (e) {
      print("❌ Lỗi createAICharacter: $e");
      throw Exception('Tạo thất bại');
    }
  }

  Future<void> updateAICharacter(BuildContext context, String id, Map<String, dynamic> data) async {
    try {
      await _dio.put('$_baseUrl/api/ai/admin/characters/$id', data: data, options: _getAuthOptions(context));
    } catch (e) {
      print("❌ Lỗi updateAICharacter: $e");
      throw Exception('Cập nhật thất bại');
    }
  }

  Future<void> deleteAICharacter(BuildContext context, String id) async {
    try {
      await _dio.delete('$_baseUrl/api/ai/admin/characters/$id', options: _getAuthOptions(context));
    } catch (e) {
      print("❌ Lỗi deleteAICharacter: $e");
      throw Exception('Xóa thất bại');
    }
  }

  // ============================================
  // 8. QUẢN LÝ THÔNG BÁO (NOTIFICATION)
  // ============================================

  Future<List<dynamic>> getNotificationHistory(BuildContext context) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/api/notifications/admin/history',
        options: _getAuthOptions(context),
      );
      return response.data;
    } catch (e) {
      print("❌ Lỗi getNotificationHistory: $e");
      return [];
    }
  }

  Future<void> sendNotification(BuildContext context, String title, String message, String type) async {
    try {
      await _dio.post(
        '$_baseUrl/api/notifications/admin/send',
        data: {'title': title, 'message': message, 'type': type},
        options: _getAuthOptions(context),
      );
    } catch (e) {
      print("❌ Lỗi sendNotification: $e");
      throw Exception('Gửi thông báo thất bại');
    }
  }

  Future<void> deleteNotification(BuildContext context, String id) async {
    try {
      await _dio.delete(
        '$_baseUrl/api/notifications/admin/$id',
        options: _getAuthOptions(context),
      );
    } catch (e) {
      print("❌ Lỗi deleteNotification: $e");
      throw Exception('Xóa thông báo thất bại');
    }
  }
}
