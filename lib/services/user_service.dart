// Dán toàn bộ code này vào file: lib/services/user_service.dart

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart'; // Import này cần cho debugPrint
import 'package:flutter_image_compress/flutter_image_compress.dart'; // Để nén ảnh
import 'package:path_provider/path_provider.dart'; // Để lấy thư mục tạm
import 'package:path/path.dart' as p; // Để xử lý đường dẫn

import '../models/user_model.dart';
import 'auth_service.dart';

class UserService {
  AuthService? _authService;
  final Dio _dio = Dio();
  final Dio _cloudinaryDio = Dio(); // Dio riêng để upload Cloudinary
  // `baseUrl` bây giờ sẽ là `http://...` (không có /api)
  String? get _baseUrl => _authService?.baseUrl;

  UserService(this._authService) {
    _configureDio();
  }

  void _configureDio() {
    // Thiết lập Dio với baseUrl đã có /api
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

  // 🔥 HÀM UPLOAD TRỰC TIẾP LÊN CLOUDINARY (DÙNG CHUNG CHO CÁC SERVICE) 🔥
  // Có thể đặt hàm này ở một file tiện ích riêng nếu muốn chia sẻ giữa các service
  Future<String?> uploadDirectToCloudinary(File file, String resourceType, {String folder = 'xmasocial'}) async {
    try {
      // 1. Lấy thông tin cấu hình và chữ ký từ Server của bro
      debugPrint("🔍 Đang lấy chữ ký Cloudinary từ Server...");
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

      debugPrint("☁️ Bắt đầu đẩy file trực tiếp lên Cloudinary ($resourceType) cho folder: $dynamicFolder...");
      final response = await _cloudinaryDio.post(
          'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload',
          data: formData,
          onSendProgress: (sent, total) {
            debugPrint("📤 Cloudinary Progress: ${(sent / total * 100).toStringAsFixed(0)}%");
          },
          options: Options(
            sendTimeout: const Duration(seconds: 180), // Tăng timeout
            receiveTimeout: const Duration(seconds: 180),
          )
      );

      debugPrint("✅ Đẩy lên Cloudinary thành công.");
      return response.data['secure_url']; // Trả về link https
    } on DioException catch (e) {
      debugPrint("❌ Lỗi upload trực tiếp Cloudinary: $e");
      if (e.response != null) {
        debugPrint("Cloudinary API Response (Error): ${e.response?.data}");
      }
      return null;
    } catch (e) {
      debugPrint("❌ Lỗi không xác định khi upload Cloudinary: $e");
      return null;
    }
  }


  // ===== CÁC HÀM API ĐÃ ĐƯỢC CHUẨN HÓA (KHÔNG CÒN LỖI /api/api) =====

  Future<UserModel> getUserById(String userId) async {
    try {
      // Chỉ cần gọi đường dẫn con, không cần /api
      final response = await _dio.get('/users/$userId');
      // Truyền vào baseUrl gốc (không có /api) để model xử lý ảnh cho đúng
      return UserModel.fromJson(response.data, baseUrl: _baseUrl);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Lỗi không xác định.');
    }
  }

  Future<void> sendFriendRequest(String userId) async {
    try {
      await _dio.post('/friends/send-request/$userId');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Đã xảy ra lỗi.');
    }
  }

  Future<void> acceptFriendRequest(String senderId) async {
    try {
      await _dio.post('/friends/accept-request/$senderId');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Đã xảy ra lỗi.');
    }
  }

  Future<void> rejectFriendRequest(String senderId) async {
    try {
      await _dio.post('/friends/reject-request/$senderId');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Đã xảy ra lỗi.');
    }
  }

  Future<void> unfriendUser(String friendId) async {
    try {
      await _dio.post('/friends/unfriend/$friendId');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Đã xảy ra lỗi.');
    }
  }

  // 🔥 CẬP NHẬT HÀM updateAvatar ĐỂ UPLOAD TRỰC TIẾP LÊN CLOUDINARY 🔥
  Future<UserModel> updateAvatar(File imageFile) async {
    File? fileToProcess = imageFile; // Khởi tạo với file gốc

    try {
      debugPrint("📸 Đang nén và upload avatar lên Cloudinary...");

      // Nén ảnh avatar trước khi upload
      final tempDir = await getTemporaryDirectory();
      final targetPath = p.join(tempDir.path, "compressed_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg");

      final compressedXFile = await FlutterImageCompress.compressAndGetFile(
          imageFile.absolute.path, targetPath, quality: 85 // Chất lượng cao hơn một chút cho avatar
      );

      if (compressedXFile != null) {
        fileToProcess = File(compressedXFile.path); // Cập nhật fileToProcess nếu nén thành công
      }

      final avatarUrl = await uploadDirectToCloudinary(fileToProcess!, 'image', folder: 'xmasocial_avatars');

      if (avatarUrl == null) {
        throw Exception("Không thể upload ảnh đại diện lên Cloudinary.");
      }

      // Gửi URL đã có về Backend
      debugPrint("📝 Đang gửi URL avatar về Database: $avatarUrl");
      final response = await _dio.put('/users/profile/avatar', data: {'avatarUrl': avatarUrl}); // 🔥 Endpoint mới 🔥

      // Cập nhật người dùng hiện tại thông qua AuthService
      if (_authService?.user?.id != null) { // Chỉ cập nhật nếu _authService và user không null
        _authService?.updateCurrentUserDetails(avatarUrl: avatarUrl); // 🔥 SỬA Ở ĐÂY 🔥
      }

      debugPrint("✅ Cập nhật ảnh đại diện thành công.");
      return UserModel.fromJson(response.data, baseUrl: _baseUrl); // Trả về UserModel đã cập nhật
    } on DioException catch (e) {
      debugPrint('Lỗi khi cập nhật avatar: ${e.response?.data ?? e.message}');
      throw Exception(e.response?.data['message'] ?? 'Không thể cập nhật ảnh đại diện.');
    } catch (e) {
      debugPrint('Lỗi không xác định khi cập nhật avatar: $e');
      throw Exception('Không thể cập nhật ảnh đại diện: $e');
    } finally {
      // Dọn dẹp file tạm nếu có
      if (fileToProcess != null && fileToProcess.path.contains("compressed_avatar_")) {
        try {
          if (await fileToProcess.exists()) { // Kiểm tra sự tồn tại trước khi xóa
            await fileToProcess.delete();
          }
        } catch (e) {
          debugPrint("Không thể xóa file avatar tạm: $e");
        }
      }
    }
  }

  // 🔥 THÊM HÀM CẬP NHẬT ẢNH BÌA NẾU BRO CÓ NÚT "CẬP NHẬT ẢNH BÌA" TRÊN UI 🔥
  Future<void> updateCoverPhoto(File coverFile) async {
    File? fileToProcess = coverFile; // Khởi tạo với file gốc

    try {
      debugPrint("📸 Đang nén và upload ảnh bìa lên Cloudinary...");

      // Nén ảnh bìa trước khi upload
      final tempDir = await getTemporaryDirectory();
      final targetPath = p.join(tempDir.path, "compressed_cover_${DateTime.now().millisecondsSinceEpoch}.jpg");

      final compressedXFile = await FlutterImageCompress.compressAndGetFile(
          coverFile.absolute.path, targetPath, quality: 80
      );

      if (compressedXFile != null) {
        fileToProcess = File(compressedXFile.path); // Cập nhật fileToProcess nếu nén thành công
      }

      final coverUrl = await uploadDirectToCloudinary(fileToProcess!, 'image', folder: 'xmasocial_covers');

      if (coverUrl == null) {
        throw Exception("Không thể upload ảnh bìa lên Cloudinary.");
      }

      // Gửi URL đã có về Backend
      debugPrint("📝 Đang gửi URL ảnh bìa về Database: $coverUrl");
      await _dio.put('/users/profile/cover', data: {'coverUrl': coverUrl}); // 🔥 Endpoint mới 🔥

      // Cập nhật người dùng hiện tại thông qua AuthService
      if (_authService?.user?.id != null) { // Chỉ cập nhật nếu _authService và user không null
        _authService?.updateCurrentUserDetails(coverUrl: coverUrl); // 🔥 SỬA Ở ĐÂY 🔥
      }

      debugPrint("✅ Cập nhật ảnh bìa thành công.");
    } on DioException catch (e) {
      debugPrint('Lỗi khi cập nhật ảnh bìa: ${e.response?.data ?? e.message}');
      throw Exception(e.response?.data['message'] ?? 'Không thể cập nhật ảnh bìa.');
    } catch (e) {
      debugPrint('Lỗi không xác định khi cập nhật ảnh bìa: $e');
      throw Exception('Không thể cập nhật ảnh bìa: $e');
    } finally {
      // Dọn dẹp file tạm nếu có
      if (fileToProcess != null && fileToProcess.path.contains("compressed_cover_")) {
        try {
          if (await fileToProcess.exists()) { // Kiểm tra sự tồn tại trước khi xóa
            await fileToProcess.delete();
          }
        } catch (e) {
          debugPrint("Không thể xóa file ảnh bìa tạm: $e");
        }
      }
    }
  }


  Future<List<UserModel>> fetchUserSuggestions() async {
    try {
      final response = await _dio.get('/users/suggestions');
      final List<dynamic> data = response.data;
      return data
      // Truyền vào baseUrl gốc để xử lý ảnh
          .map((item) => UserModel.fromJson(item, baseUrl: _baseUrl))
          .toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Lỗi mạng hoặc server.');
    }
  }

  // 🔥 Thêm hàm updateProfile nếu bro chưa có, hoặc cập nhật nếu có rồi 🔥
  Future<void> updateProfile({
    String? displayName,
    String? bio,
  }) async {
    try {
      final response = await _dio.put('/users/profile', data: {
        if (displayName != null) 'displayName': displayName,
        if (bio != null) 'bio': bio,
      });
      final updatedUser = UserModel.fromJson(response.data, baseUrl: _baseUrl);
      // Cập nhật user trong AuthService
      _authService?.updateCurrentUser(updatedUser); // 🔥 SỬA Ở ĐÂY 🔥
      // notifyListeners(); // Nếu UserService là ChangeNotifier
    } on DioException catch (e) {
      debugPrint('Lỗi cập nhật profile: ${e.response?.data ?? e.message}');
      throw Exception(e.response?.data['message'] ?? 'Không thể cập nhật thông tin cá nhân.');
    } catch (e) {
      debugPrint('Lỗi không xác định khi cập nhật profile: $e');
      throw Exception('Không thể cập nhật thông tin cá nhân.');
    }
  }
}