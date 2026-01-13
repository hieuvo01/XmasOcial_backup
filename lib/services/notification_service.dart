// Dán toàn bộ code này vào file: lib/services/notification_service.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import 'auth_service.dart';

class NotificationService with ChangeNotifier {
  AuthService? _authService;
  final Dio _dio = Dio();

  String? get _baseUrl => _authService?.baseUrl;

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;
  int _unreadCount = 0;

  NotificationService(this._authService) {
    _configureDio();
  }

  // Getters
  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _unreadCount;

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

  // ===== SỬA LỖI QUAN TRỌNG Ở ĐÂY =====
  // Hàm này được gọi tự động từ main.dart mỗi khi trạng thái đăng nhập thay đổi
  void updateAuth(AuthService newAuthService) {
    _authService = newAuthService;
    _configureDio();

    if (_authService?.user != null) {
      // 1. Nếu vừa Đăng nhập: Tải thông báo ngay lập tức
      // (Không cần đợi UI gọi, service tự làm)
      fetchNotifications();
    } else {
      // 2. Nếu vừa Đăng xuất: Xóa sạch dữ liệu cũ ngay lập tức
      clearNotifications();
    }
  }
  // ====================================

  void clearNotifications() {
    _notifications = []; // Reset list
    _unreadCount = 0;    // Reset count
    _error = null;
    _isLoading = false;
    notifyListeners(); // Báo cho UI biết để xóa giao diện cũ
  }

  // ===== SỬA LẠI FETCH NOTIFICATIONS ĐỂ CẬP NHẬT CHẤM ĐỎ =====
  Future<void> fetchNotifications() async {
    // Nếu chưa đăng nhập thì không tải
    if (_authService?.user == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners(); // Cập nhật trạng thái loading

    try {
      final response = await _dio.get('/notifications');
      final List<dynamic> data = response.data;
      // ===== THÊM DÒNG NÀY ĐỂ DEBUG =====
      print("DATA THÔNG BÁO TỪ SERVER: $data");
      // ==================================
      _notifications = data
          .map((item) => NotificationModel.fromJson(item, baseUrl: _baseUrl))
          .toList();

      // Quan trọng: Tính toán lại số lượng chưa đọc ngay sau khi tải
      _updateUnreadCount();

    } on DioException catch (e) {
      _error = 'Lỗi tải thông báo: ${e.response?.statusCode ?? e.message}';
      // Nếu lỗi, có thể giữ lại list cũ hoặc clear tùy logic, ở đây tôi giữ list cũ
    } finally {
      _isLoading = false;
      notifyListeners(); // Quan trọng: Báo cho UI render lại (hiện chấm đỏ)
    }
  }

  Future<void> markAsRead(String notificationId) async {
    if (_authService?.user == null) return;

    // Optimistic Update: Cập nhật UI trước cho mượt
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index].isRead = true;
      _updateUnreadCount(); // Tính lại số lượng
      notifyListeners();
    }

    try {
      await _dio.put('/notifications/$notificationId/mark-read');
    } catch (e) {
      print("Lỗi markAsRead: $e");
      // Nếu lỗi server thì có thể revert lại UI (tùy chọn)
    }
  }

  // Hàm tính số lượng chưa đọc
  void _updateUnreadCount() {
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    // Không cần notifyListeners ở đây vì hàm gọi nó đã gọi rồi
  }

  // Thêm hàm đánh dấu tất cả đã đọc (nếu cần)
  Future<void> markAllAsRead() async {
    if (_authService?.user == null) return;

    // UI Update
    for (var n in _notifications) {
      n.isRead = true;
    }
    _updateUnreadCount();
    notifyListeners();

    try {
      await _dio.put('/notifications/mark-all-read');
    } catch (e) {
      print("Lỗi markAllAsRead: $e");
    }
  }


  // Hàm xóa thông báo khỏi danh sách (Local Only hoặc gọi API xóa thật nếu muốn)
  void removeNotificationLocal(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }
}
