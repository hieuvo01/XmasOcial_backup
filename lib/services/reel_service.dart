import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/reel_model.dart';
import 'auth_service.dart';

class ReelService with ChangeNotifier {
  AuthService? _authService;
  final Dio _dio = Dio();
  String? get _baseUrl => _authService?.baseUrl;

  List<Reel> reels = [];
  bool isLoading = false;
  int _currentPage = 1;

  ReelService(this._authService) {
    _configureDio();
  }

  void updateAuth(AuthService auth) {
    _authService = auth;
    _configureDio();
  }

  void _configureDio() {
    _dio.options.baseUrl = '${_baseUrl ?? ''}/api';
    if (_authService?.token != null) {
      _dio.options.headers['Authorization'] = 'Bearer ${_authService!.token}';
    }
  }

  Future<void> fetchReels({bool loadMore = false}) async {
    if (isLoading) return;

    if (!loadMore) {
      _currentPage = 1;
    }

    isLoading = true;
    notifyListeners();

    try {
      final response = await _dio.get('/reels?page=$_currentPage');
      final List<dynamic> data = response.data;

      List<Reel> newReels = data.map((json) => Reel.fromJson(json, baseUrl: _baseUrl)).toList();

      if (loadMore) {
        reels.addAll(newReels);
      } else {
        reels = newReels;
      }

      if (newReels.isNotEmpty) {
        _currentPage++;
      }

    } catch (e) {
      print("Lỗi tải Reels: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // 🔥 HÀM MỚI: Tạo Reel bằng link Cloudinary
  Future<bool> createReelDirect({
    required String videoUrl,
    String? description,
    String? thumbnailUrl,
  }) async {
    try {
      isLoading = true;
      notifyListeners();

      // Gửi JSON body thay vì FormData
      await _dio.post(
        '/reels/create-direct',
        data: {
          "videoUrl": videoUrl,
          "description": description ?? "",
          "thumbnailUrl": thumbnailUrl ?? "",
        },
      );

      await fetchReels(loadMore: false); // Refresh lại danh sách
      return true;
    } catch (e) {
      print("Lỗi createReelDirect: $e");
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // --- CÁC HÀM TƯƠNG TÁC GIỮ NGUYÊN ---
  Future<bool> likeReel(String reelId) async {
    try {
      await _dio.put('/reels/$reelId/like');
      return true;
    } catch (e) {
      print("Lỗi Like Reel: $e");
      return false;
    }
  }

  Future<List<dynamic>> getComments(String reelId) async {
    try {
      final response = await _dio.get('/reels/$reelId/comments');
      return response.data as List<dynamic>;
    } catch (e) {
      print("Lỗi lấy comment: $e");
      return [];
    }
  }

  Future<dynamic> addComment(String reelId, String text) async {
    try {
      final response = await _dio.post(
        '/reels/$reelId/comments',
        data: {'text': text},
      );
      return response.data;
    } catch (e) {
      print("Lỗi gửi comment: $e");
      return null;
    }
  }
}
