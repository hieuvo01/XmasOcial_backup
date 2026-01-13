// File: lib/services/story_service.dart

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/story_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

class StoryService with ChangeNotifier {
  AuthService? _authService;
  final Dio _dio = Dio();
  final Dio _cloudinaryDio = Dio();

  String? get _baseUrl => _authService?.baseUrl;

  List<UserStoryGroup> storyGroups = [];
  bool isLoading = false;
  String? error;

  StoryService(this._authService) {
    _configureDio();
  }

  void _configureDio() {
    _dio.options.baseUrl = '${_baseUrl ?? ''}/api';
    _dio.options.connectTimeout = const Duration(seconds: 180);
    _dio.options.receiveTimeout = const Duration(seconds: 180);

    _dio.interceptors.clear();
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_authService?.token != null) {
            options.headers['Authorization'] = 'Bearer ${_authService!.token}';
          }
          return handler.next(options);
        },
      ),
    );
  }

  void updateAuth(AuthService auth) {
    _authService = auth;
    _configureDio();
  }

  Future<void> fetchStories() async {
    if (isLoading) return;
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final response = await _dio.get('/stories/feed');
      final List<dynamic> data = response.data;
      final currentUserId = _authService?.user?.id;

      storyGroups = data.map((json) => UserStoryGroup.fromJson(
          json,
          baseUrl: _baseUrl,
          currentUserId: currentUserId
      )).toList();

    } catch (e) {
      debugPrint('Lỗi fetch stories: $e');
      error = "Không thể tải bảng tin story.";
      storyGroups = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // --- HÀM UPLOAD TRỰC TIẾP LÊN CLOUDINARY (Đã fix resourceType cho audio) ---
  Future<String?> _uploadDirectToCloudinary(File file, String resourceType) async {
    try {
      debugPrint("🔍 Đang lấy chữ ký Cloudinary từ Server...");
      final signResponse = await _dio.get('/config/cloudinary-signature');
      final String apiKey = signResponse.data['apiKey'];
      final String cloudName = signResponse.data['cloudName'];
      final String signature = signResponse.data['signature'];
      final int timestamp = signResponse.data['timestamp'];
      final String folder = signResponse.data['folder'] ?? 'xmasocial_direct';

      // 🔥 Cloudinary quy định Audio thuộc resource_type: 'video'
      String finalResourceType = resourceType;
      if (file.path.endsWith('.mp3') || file.path.endsWith('.m4a')) {
        finalResourceType = 'video';
      }

      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
        'api_key': apiKey,
        'timestamp': timestamp,
        'signature': signature,
        'folder': folder,
      });

      debugPrint("☁️ Bắt đầu đẩy file ($finalResourceType) lên Cloudinary...");
      final response = await _cloudinaryDio.post(
          'https://api.cloudinary.com/v1_1/$cloudName/$finalResourceType/upload',
          data: formData,
          options: Options(
            sendTimeout: const Duration(seconds: 180),
            receiveTimeout: const Duration(seconds: 180),
          )
      );

      debugPrint("✅ Đẩy lên Cloudinary thành công.");
      return response.data['secure_url'];
    } catch (e) {
      debugPrint("❌ Lỗi upload Cloudinary: $e");
      return null;
    }
  }

  // Hàm tải nhạc tạm thời từ Deezer về máy
  Future<File?> _downloadMusic(String url) async {
    try {
      debugPrint("🎵 Đang tải nhạc từ Deezer về máy...");
      final tempDir = await getTemporaryDirectory();
      final path = p.join(tempDir.path, "temp_music_${DateTime.now().millisecondsSinceEpoch}.mp3");
      await Dio().download(url, path);
      return File(path);
    } catch (e) {
      debugPrint("❌ Lỗi tải nhạc: $e");
      return null;
    }
  }

  Future<void> createStory({
    String? text,
    File? mediaFile,
    required String mediaType,
    String? musicUrl,
    String? musicName,
    String? style,
  }) async {
    File? fileToProcess = mediaFile;
    File? tempMusicFile;

    try {
      isLoading = true;
      notifyListeners();

      String? finalMediaUrl;
      String? finalCloudMusicUrl;

      // 1. XỬ LÝ NHẠC: Tải từ Deezer và đẩy lên Cloudinary
      if (musicUrl != null && musicUrl.isNotEmpty && musicUrl.startsWith('http')) {
        tempMusicFile = await _downloadMusic(musicUrl);
        if (tempMusicFile != null) {
          finalCloudMusicUrl = await _uploadDirectToCloudinary(tempMusicFile, 'video');
          debugPrint("✅ Nhạc đã lên Cloudinary: $finalCloudMusicUrl");
        }
      }

      // 2. XỬ LÝ MEDIA (Ảnh/Video)
      if (mediaType != 'text' && mediaFile != null) {
        if (mediaType == 'image') {
          debugPrint("📸 Đang nén ảnh...");
          final tempDir = await getTemporaryDirectory();
          final targetPath = p.join(tempDir.path, "compressed_${DateTime.now().millisecondsSinceEpoch}.jpg");
          final compressedXFile = await FlutterImageCompress.compressAndGetFile(
            mediaFile.absolute.path, targetPath, quality: 70,
          );
          if (compressedXFile != null) fileToProcess = File(compressedXFile.path);
        }

        finalMediaUrl = await _uploadDirectToCloudinary(
            fileToProcess!,
            mediaType == 'video' ? 'video' : 'image'
        );
      }

      // 3. GỬI VỀ DATABASE (Dùng link Cloudinary thay vì link Deezer)
      String finalEndpoint = (mediaType == 'text') ? '/stories/text' : '/stories/create-direct';

      Map<String, dynamic> storyData = {
        'mediaType': mediaType,
        'text': text,
        'style': style ?? 'gradient_blue',
        'musicUrl': finalCloudMusicUrl ?? musicUrl, // Ưu tiên link vĩnh viễn
        'musicName': musicName,
        if (mediaType != 'text') 'mediaUrl': finalMediaUrl,
      };

      await _dio.post(finalEndpoint, data: storyData);
      await fetchStories();

    } catch (e) {
      debugPrint("🔥 Lỗi đăng Story: $e");
      throw Exception('Không thể đăng tin.');
    } finally {
      isLoading = false;
      notifyListeners();
      // Dọn dẹp file tạm
      if (fileToProcess != null && fileToProcess.path.contains("compressed_")) {
        fileToProcess.delete().catchError((e) => null);
      }
      if (tempMusicFile != null) {
        tempMusicFile.delete().catchError((e) => null);
      }
    }
  }

  // --- Các hàm Reaction / View / Delete giữ nguyên ---
  Future<void> reactToStory(String storyId, String reactionType) async {
    try {
      await _dio.post('/stories/$storyId/react', data: {'type': reactionType});
    } catch (e) { throw Exception("Không thể bày tỏ cảm xúc."); }
  }

  Future<void> markAsViewed(String storyId) async {
    try { await _dio.post('/stories/$storyId/view'); } catch (e) { debugPrint("Lỗi view: $e"); }
  }

  Future<Story?> getStoryById(String storyId) async {
    try {
      final response = await _dio.get('/stories/$storyId');
      final currentUserId = _authService?.user?.id;
      return Story.fromJson(response.data, baseUrl: _baseUrl, currentUserId: currentUserId);
    } catch (e) { return null; }
  }

  Future<void> deleteStory(String storyId) async {
    try {
      await _dio.delete('/stories/$storyId');
      fetchStories();
    } catch (e) { throw Exception("Xóa thất bại."); }
  }

  Future<List<UserModel>> getStoryViewers(String storyId) async {
    try {
      final response = await _dio.get('/stories/$storyId/viewers');
      final List<dynamic> data = response.data;
      return data.map((json) => UserModel.fromJson(json, baseUrl: _baseUrl)).toList();
    } catch (e) { throw Exception("Không thể tải người xem."); }
  }

  // --- Bổ sung tại vị trí <caret> ---
  /// Cập nhật thông tin của một story cụ thể trong danh sách hiện tại
  Future<void> refreshSingleStory(String storyId) async {
    final updatedStory = await getStoryById(storyId);
    if (updatedStory != null) {
      bool found = false;
      for (var group in storyGroups) {
        final index = group.stories.indexWhere((s) => s.id == storyId);
        if (index != -1) {
          group.stories[index] = updatedStory;
          found = true;
          break;
        }
      }
      if (found) {
        notifyListeners();
      }
    }
  }
}
