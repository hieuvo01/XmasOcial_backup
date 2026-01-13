// File: lib/services/auth_service.dart

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/user_model.dart';
import '../screens/auth/github_webview.dart'; // Đảm bảo đúng path GithubLoginWebView

class AuthService with ChangeNotifier {
  final Dio _dio = Dio();

  // Lấy BaseURL từ AppConfig (đã chứa link ngrok)
  final String _baseUrl = AppConfig.baseUrl;

  String get baseUrl => _baseUrl;
  UserModel? _user; // Biến này đã mutable, rất tốt!
  String? _token;

  String? get token => _token;
  UserModel? get user => _user;
  bool get isLoggedIn => _token != null;

  // 👇 SỬA Ở ĐÂY: Lấy cấu hình từ AppConfig thay vì hardcode
  // (Đảm bảo bro đã thêm githubClientId và githubRedirectUri vào AppConfig như bước trước)
  final String _githubClientId = AppConfig.githubClientId;
  final String _githubRedirectUri = AppConfig.githubRedirectUri;

  // ⚠️ Nếu bro lỡ chưa thêm vào AppConfig thì bỏ comment dòng dưới và dán link ngrok vào:
  // final String _githubRedirectUri = 'https://abcd-1234.ngrok-free.app/api/auth/github/callback';

  Future<void> loginWithGitHub(BuildContext context) async {
    try {
      // 1. URL này giữ nguyên (Redirect URI vẫn là link Ngrok của backend)
      final url = Uri.https('github.com', '/login/oauth/authorize', {
        'client_id': _githubClientId,
        'redirect_uri': _githubRedirectUri,
        'scope': 'user:email',
      });

      print("Opening WebView: $url");

      // 2. Mở WebView
      final code = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => GithubLoginWebView(
            authUrl: url.toString(),
            // redirectUri: ... -> XÓA DÒNG NÀY ĐI
          ),
        ),
      );

      // 3. Xử lý kết quả trả về từ màn hình WebView
      if (code == null) {
        throw Exception("Bạn đã hủy đăng nhập");
      }

      print("Đã lấy được code: $code");

      // 4. Gửi code lên Backend (Giữ nguyên)
      final response = await _dio.post(
        '$_baseUrl/api/users/github',
        data: {'code': code},
      );

      // 5. Lưu token (Giữ nguyên)
      await _saveAndNotify(response.data);

    } catch (e) {
      print("GitHub Login Error: $e");
      if (e is DioException) {
        throw Exception(e.response?.data['message'] ?? 'Lỗi server');
      }
      throw Exception(e.toString()); // Show lỗi trực tiếp
    }
  }

  // 🔥 PHƯƠNG THỨC MỚI ĐỂ CẬP NHẬT TOÀN BỘ ĐỐI TƯỢNG USER 🔥
  void updateCurrentUser(UserModel? newUser) {
    if (_user != newUser) {
      _user = newUser;
      notifyListeners(); // Thông báo cho các widget đang lắng nghe
    }
  }

  // Kiểm tra xem user có phải Quản lý/Moderator không
  bool get isModerator => _user?.role == 'moderator' || _user?.role == 'admin';
  bool get isAdmin => _user?.role == 'admin';

  // 🔥 PHƯƠNG THỨC MỚI ĐỂ CẬP NHẬT TỪNG PHẦN CỦA USER (dùng cho avatar/cover/bio) 🔥
  void updateCurrentUserDetails({String? avatarUrl, String? coverUrl, String? displayName, String? bio}) {
    if (_user != null) {
      _user = _user!.copyWith(
        avatarUrl: avatarUrl ?? _user!.avatarUrl,
        coverUrl: coverUrl ?? _user!.coverUrl,
        displayName: displayName ?? _user!.displayName,
        bio: bio ?? _user!.bio,
      );
      notifyListeners(); // Thông báo cho các widget đang lắng nghe
    }
  }

  // --- CÁC HÀM DƯỚI GIỮ NGUYÊN (HOẶC ĐÃ SỬA BỞI BRO) ---

  // 1. TỰ ĐỘNG ĐĂNG NHẬP
  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('jwt_token')) return false;

    _token = prefs.getString('jwt_token');
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      try {
        _user = UserModel.fromJson(jsonDecode(userDataString), baseUrl: _baseUrl);
        // Gọi hàm này để update thông tin mới nhất (như avatar, tên...) từ server
        fetchAndSetCurrentUser();
        return true;
      } catch (e) {
        await signOut();
        return false;
      }
    } else {
      await signOut();
      return false;
    }
  }

  // 2. RELOAD USER
  Future<void> fetchAndSetCurrentUser() async {
    if (_user == null || _token == null) return;
    try {
      final response = await _dio.get(
        '$_baseUrl/api/users/profile',
        options: Options(headers: {'Authorization': 'Bearer $_token'}),
      );
      final updatedUser = UserModel.fromJson(response.data, baseUrl: _baseUrl);
      _user = updatedUser; // Cập nhật trực tiếp _user ở đây
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('user_data', json.encode(updatedUser.toJson()));
      notifyListeners();
    } catch (e) {
      print('❌ Lỗi fetch user: $e');
    }
  }

  // Hàm cập nhật Profile (Tên hiển thị & Bio)
  Future<void> updateProfile({required String displayName, required String bio}) async {
    // 1. Kiểm tra token trực tiếp từ biến _token có sẵn trong class
    if (_token == null) throw Exception("Chưa đăng nhập");

    try {
      // 2. Dùng Dio để gọi API (Thay vì http) cho đồng bộ với các hàm khác
      final response = await _dio.put(
        '$_baseUrl/api/users/profile', // Route user tự update
        options: Options(headers: {
          'Authorization': 'Bearer $_token', // Dùng biến _token trực tiếp
        }),
        data: {
          'displayName': displayName,
          'bio': bio,
        },
      );

      // 3. Cập nhật lại dữ liệu User trong AppState
      // (Lưu ý: response.data của Dio là Map json luôn, không cần jsonDecode)
      final updatedUser = UserModel.fromJson(response.data, baseUrl: _baseUrl);
      _user = updatedUser; // Cập nhật trực tiếp _user ở đây

      // Cập nhật lại vào SharedPreferences để lần sau vào app vẫn còn data mới
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', json.encode(_user!.toJson()));

      notifyListeners(); // Báo cho UI biết để vẽ lại

    } on DioException catch (e) {
      // Xử lý lỗi chuẩn kiểu Dio
      throw Exception(e.response?.data['message'] ?? "Lỗi cập nhật hồ sơ");
    }
  }


  // CẬP NHẬT LAST ACTIVE
  Future<void> updateLastActive() async {
    if (_user == null || _token == null) return;
    try {
      await _dio.put(
        '$_baseUrl/api/users/${_user!.id}/last-active',
        options: Options(headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        }),
        data: json.encode({'lastActive': DateTime.now().toIso8601String()}),
      );
      _user = _user!.copyWith(lastActive: DateTime.now()); // Cập nhật trực tiếp _user ở đây
      notifyListeners();
    } catch (e) {}
  }

  // HELPER LƯU TOKEN
  Future<void> _saveAndNotify(Map<String, dynamic> responseData) async {
    _token = responseData['token'];
    Map<String, dynamic> userData;
    if (responseData.containsKey('user') && responseData['user'] != null) {
      userData = responseData['user'];
    } else {
      userData = Map<String, dynamic>.from(responseData);
      userData.remove('token');
    }
    _user = UserModel.fromJson(userData, baseUrl: _baseUrl); // Cập nhật trực tiếp _user ở đây

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', _token!);
    await prefs.setString('user_data', jsonEncode(_user!.toJson()));
    notifyListeners();
    updateLastActive(); // Không cần await để UI phản hồi nhanh hơn
  }

  // 3. ĐĂNG NHẬP
  Future<void> signIn(String email, String password) async {
    try {
      debugPrint("🚀 [Auth] Đang gửi yêu cầu đăng nhập: $email");

      final response = await _dio.post(
        '$_baseUrl/api/auth/login',
        data: {'email': email, 'password': password},
      );

      debugPrint("✅ [Auth] Server trả về data: ${response.data}");

      if (response.data['token'] == null) {
        debugPrint("❌ [Auth] Lỗi: Server không trả về Token!");
        throw Exception("Server không trả về mã truy cập");
      }

      await _saveAndNotify(response.data);
      debugPrint("🎉 [Auth] Đã lưu Token và thông báo UI thành công");

    } on DioException catch (e) {
      debugPrint("❌ [Auth] Dio Error: ${e.type}");
      debugPrint("📄 [Auth] Response data: ${e.response?.data}");

      String errorMsg = e.response?.data['message'] ?? 'Đăng nhập thất bại';
      throw Exception(errorMsg);
    } catch (e) {
      debugPrint("❌ [Auth] Lỗi không xác định: $e");
      rethrow;
    }
  }

  // 4. ĐĂNG KÝ
  Future<void> register({
    required String displayName,
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      await _dio.post(
        '$_baseUrl/api/users',
        data: {
          'displayName': displayName,
          'username': username,
          'email': email,
          'password': password,
        },
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Lỗi không xác định từ server');
    }
  }

  // 5. ĐĂNG XUẤT
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // 👈 Xóa sạch toàn bộ thay vì xóa từng cái cho chắc ăn
    _token = null;
    _user = null;
    notifyListeners();
  }
}