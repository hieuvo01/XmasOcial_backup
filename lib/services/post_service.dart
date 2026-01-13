// File: lib/services/post_service.dart

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
//  THÊM CÁC IMPORTS MỚI
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_image_compress/flutter_image_compress.dart';


import '../models/comment_model.dart';
import '../models/post_model.dart';
import '../models/reaction_model.dart';
import 'auth_service.dart';

class PostService with ChangeNotifier {
  AuthService? _authService;
  final Dio _dio = Dio();
  final Dio _cloudinaryDio = Dio(); // Dio riêng để upload Cloudinary 🔥
  String? get _baseUrl => _authService?.baseUrl;

  List<Post> posts = [];
  bool isLoading = false;
  String? error;

  PostService(this._authService) {
    _configureDio();
  }

  void _configureDio() {
    _dio.options.baseUrl = '${_baseUrl ?? ''}/api';
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);

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

  // 🔥 HÀM UPLOAD TRỰC TIẾP LÊN CLOUDINARY (CÓ THỂ DÙNG CHUNG CHO CÁC SERVICE) 🔥
  Future<String?> uploadDirectToCloudinary(File file, String resourceType, {String folder = 'xmasocial_posts'}) async {
    try {
      // 1. Lấy thông tin cấu hình và chữ ký từ Server của bro
      final signResponse = await _dio.get('/config/cloudinary-signature');
      final String apiKey = signResponse.data['apiKey'];
      final String cloudName = signResponse.data['cloudName'];
      final String signature = signResponse.data['signature'];
      final int timestamp = signResponse.data['timestamp'];
      final String dynamicFolder = signResponse.data['folder'] ?? folder; // Dùng folder mặc định nếu server không gửi

      // 2. Tạo FormData để gửi thẳng cho Cloudinary
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
        'api_key': apiKey,
        'timestamp': timestamp,
        'signature': signature,
        'folder': dynamicFolder,
      });

      debugPrint("☁️ Bắt đầu đẩy file trực tiếp lên Cloudinary ($resourceType)...");
      final response = await _cloudinaryDio.post(
          'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload',
          data: formData,
          onSendProgress: (sent, total) {
            debugPrint("📤 Cloudinary Progress: ${(sent / total * 100).toStringAsFixed(0)}%");
          },
          options: Options(
            sendTimeout: const Duration(seconds: 180), // Tăng timeout cho Cloudinary upload
            receiveTimeout: const Duration(seconds: 180),
          )
      );

      debugPrint("✅ Đẩy lên Cloudinary thành công.");
      return response.data['secure_url']; // Trả về link https
    } catch (e) {
      debugPrint("❌ Lỗi upload trực tiếp Cloudinary: $e");
      if (e is DioException && e.response != null) {
        debugPrint("Cloudinary API Response (Error): ${e.response?.data}");
      }
      return null;
    }
  }


  // ===== BẮT ĐẦU CÁC HÀM SERVICE =====

  // ... (các hàm fetchPosts, fetchPostsByUser giữ nguyên) ...

  Future<void> fetchPosts({bool forceRefresh = true}) async {
    if (isLoading) return;
    isLoading = true;
    if (forceRefresh) {
      error = null;
    }
    notifyListeners();

    try {
      final response = await _dio.get('/posts/feed');
      final List<dynamic> postData = response.data;
      posts = postData.map((json) => Post.fromJson(json, baseUrl: _baseUrl)).toList();
      error = null;
    } catch (e) {
      print('Lỗi khi fetch posts: $e');
      error = "Không thể tải bài viết. Vui lòng thử lại.";
      posts = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Post>> fetchPostsByUser(String userId) async {
    try {
      final response = await _dio.get('/posts/user/$userId');
      final List<dynamic> postData = response.data;
      return postData.map((json) => Post.fromJson(json, baseUrl: _baseUrl)).toList();
    } catch (e) {
      print('Lỗi khi fetch posts của user $userId: $e');
      return [];
    }
  }

  Future<Post> createPost(String content, {List<File>? mediaFiles}) async {
    try {
      List<String> mediaUrls = []; // Danh sách các URL từ Cloudinary
      if (mediaFiles != null && mediaFiles.isNotEmpty) {
        debugPrint("📸 Đang upload media cho bài viết lên Cloudinary...");
        for (var file in mediaFiles) {
          // Nén ảnh trước khi upload (nếu là ảnh)
          File? fileToProcess = file;
          String resourceType = 'image'; // Mặc định là ảnh
          if (file.path.endsWith('.mp4') || file.path.endsWith('.mov') || file.path.endsWith('.avi')) {
            resourceType = 'video';
          } else if (file.path.endsWith('.jpg') || file.path.endsWith('.jpeg') || file.path.endsWith('.png')) {
            final tempDir = await getTemporaryDirectory();
            final targetPath = p.join(tempDir.path, "compressed_post_${DateTime.now().millisecondsSinceEpoch}.jpg");
            final compressedXFile = await FlutterImageCompress.compressAndGetFile(
                file.absolute.path, targetPath, quality: 80
            );
            if (compressedXFile != null) fileToProcess = File(compressedXFile.path);
          }

          // Upload từng file lên Cloudinary
          final url = await uploadDirectToCloudinary(fileToProcess!, resourceType, folder: 'xmasocial_posts');
          if (url != null) {
            mediaUrls.add(url);
          } else {
            debugPrint("⚠️ Bỏ qua file lỗi: ${file.path}");
          }

          // Xóa file tạm nếu có
          if (fileToProcess != null && fileToProcess.path.contains("compressed_post_")) {
            try {
              await fileToProcess.delete();
            } catch (e) {
              debugPrint("Không thể xóa file tạm của bài viết: $e");
            }
          }
        }
      }

      // Gửi request POST về Server Backend (chỉ với URL từ Cloudinary)
      var postData = {
        'content': content,
        if (mediaUrls.isNotEmpty) 'mediaUrls': mediaUrls, // Gửi danh sách URLs
      };

      debugPrint("📝 Đang gửi thông tin bài viết về Database: $postData");
      final response = await _dio.post('/posts/create-direct', data: postData); // Endpoint mới 🔥

      final newPost = Post.fromJson(response.data, baseUrl: _baseUrl);
      posts.insert(0, newPost);
      notifyListeners();
      return newPost;
    } catch (e) {
      debugPrint('Lỗi khi tạo bài viết: $e');
      throw Exception('Không thể tạo bài viết.');
    }
  }

  Future<Post> updatePost(String postId, String newContent) async {
    try {
      final response = await _dio.put(
        '/posts/$postId',
        data: {'content': newContent},
      );
      return Post.fromJson(response.data, baseUrl: _baseUrl);
    } catch (e) {
      print('Lỗi cập nhật bài viết: $e');
      throw Exception('Failed to update post');
    }
  }

  // 👇 Đã sửa thành Future<Post?> và return null khi lỗi
  Future<Post?> getPostById(String postId) async {
    try {
      final response = await _dio.get('/posts/$postId');
      return Post.fromJson(response.data, baseUrl: _baseUrl);
    } catch (e) {
      print('Lỗi khi lấy post by id (có thể đã bị xóa): $e');
      return null;
    }
  }

  Future<Post> reactToPost(String postId, String? reactionType) async {
    final Map<String, dynamic> data = {'type': reactionType};
    try {
      final response = await _dio.post('/posts/$postId/react', data: data);
      final updatedPost = Post.fromJson(response.data, baseUrl: _baseUrl);
      final index = posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        posts[index] = updatedPost;
        notifyListeners();
      }
      return updatedPost;
    } catch (e) {
      print('Lỗi khi react to post: $e');
      throw Exception('Không thể bày tỏ cảm xúc.');
    }
  }

  Future<List<ReactionModel>> getPostReactions(String postId) async {
    try {
      final response = await _dio.get('/posts/$postId/reactions');
      final data = response.data as List;
      return data.map((reactionJson) => ReactionModel.fromJson(reactionJson)).toList();
    } catch (e) {
      print('Lỗi khi lấy reactions của post: $e');
      return [];
    }
  }

  // 👇 Sửa thành Future<Post?>
  Future<Post?> createComment(String postId, String content, {String? parentCommentId}) async {
    try {
      await _dio.post(
        '/posts/$postId/comments',
        data: {'content': content, 'parentId': parentCommentId},
      );
      // Gọi getPostById (có thể null nếu post vừa bị xóa tức thì)
      final updatedPost = await getPostById(postId);

      if (updatedPost != null) {
        final index = posts.indexWhere((p) => p.id == postId);
        if (index != -1) {
          posts[index] = updatedPost;
          notifyListeners();
        }
      }
      return updatedPost;
    } catch (e) {
      print('Lỗi khi tạo comment: $e');
      throw Exception('Không thể gửi bình luận.');
    }
  }

  Future<void> deleteComment(String postId, String commentId) async {
    try {
      await _dio.delete('/posts/$postId/comments/$commentId');

      final updatedPost = await getPostById(postId);

      if (updatedPost != null) {
        final index = posts.indexWhere((p) => p.id == postId);
        if (index != -1) {
          posts[index] = updatedPost;
          notifyListeners();
        }
      }
    } catch (e) {
      print('Lỗi khi xoá comment: $e');
      throw Exception('Không thể xoá bình luận.');
    }
  }

  Future<Comment> reactToComment(String commentId, String? reactionType) async {
    try {
      final response = await _dio.post(
        '/comments/$commentId/react',
        data: {'type': reactionType},
      );
      return Comment.fromJson(response.data, baseUrl: _baseUrl);
    } catch (e) {
      print('Lỗi khi react to comment: $e');
      throw Exception('Không thể bày tỏ cảm xúc với bình luận.');
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      final response = await _dio.delete('/posts/$postId');
      if (response.statusCode == 200) {
        await fetchPosts(forceRefresh: true);
      }
    } catch (e) {
      print('Lỗi xóa bài viết: $e');
      throw Exception('Không thể xóa bài viết. Vui lòng thử lại.');
    }
  }
}