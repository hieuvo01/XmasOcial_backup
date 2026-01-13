// Dán vào file: lib/services/social_search_service.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import 'auth_service.dart';

class SocialSearchService with ChangeNotifier {
  final AuthService _authService;
  final Dio _dio = Dio();

  // Getter lấy baseUrl từ AuthService
  String? get _baseUrl => _authService.baseUrl;

  // Trạng thái tìm kiếm
  bool _isLoading = false;
  String? _error;
  List<UserModel> _users = [];
  List<Post> _posts = [];

  // Getters cho UI
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<UserModel> get users => _users;
  List<Post> get posts => _posts;

  SocialSearchService(this._authService) {
    _configureDio();
  }

  void _configureDio() {
    _dio.options.baseUrl = '${_baseUrl ?? ''}/api';
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);

    _dio.interceptors.clear();
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_authService.token != null) {
            options.headers['Authorization'] = 'Bearer ${_authService.token}';
          }
          return handler.next(options);
        },
      ),
    );
  }

  // ===== HÀM TÌM KIẾM CHÍNH =====
  Future<void> searchUsersAndPosts(String query) async {
    if (query.trim().isEmpty) {
      clearResults();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners(); // Báo UI hiện loading

    try {
      // Gọi API Backend: GET /api/users/search?q=keyword
      final response = await _dio.get('/users/search', queryParameters: {'q': query});
      final Map<String, dynamic> data = response.data;

      // 1. Parse Users
      final List<dynamic> usersData = data['users'] ?? [];
      _users = usersData
          .map((userData) => UserModel.fromJson(userData, baseUrl: _baseUrl))
          .toList();

      // 2. Parse Posts
      final List<dynamic> postsData = data['posts'] ?? [];
      _posts = postsData
          .map((postData) => Post.fromJson(postData, baseUrl: _baseUrl))
          .toList();

    } on DioException catch (e) {
      _error = "Lỗi tìm kiếm: ${e.response?.statusCode ?? e.message}";
      // Nếu lỗi thì xóa kết quả cũ
      _users = [];
      _posts = [];
    } catch (e) {
      _error = "Đã xảy ra lỗi không xác định";
      print("Social Search Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners(); // Báo UI cập nhật kết quả
    }
  }

  // Hàm xóa kết quả khi thoát hoặc xóa text field
  void clearResults() {
    _users = [];
    _posts = [];
    _error = null;
    notifyListeners();
  }
}
