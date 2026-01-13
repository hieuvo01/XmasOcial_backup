import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// ignore: library_prefixes
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../models/message_model.dart';
import 'auth_service.dart';
import 'user_service.dart'; // 👈 Import UserService
import 'local_notification_service.dart';

class MessageService with ChangeNotifier {
  AuthService? _authService;
  final Dio _dio = Dio();
  IO.Socket? _socket;

  IO.Socket? get socket => _socket;
  String? get _baseUrl => _authService?.baseUrl;

  List<Conversation> conversations = [];
  Map<String, List<Message>> messagesCache = {};
  bool isLoading = false;

  List<Message> get messages => [];

  MessageService(this._authService) {
    _configureDio();
  }

  void updateAuth(AuthService auth) {
    _authService = auth;
    _configureDio();
    if (_authService?.token != null) {
      _initSocket();
    }
  }

  void _configureDio() {
    _dio.options.baseUrl = '${_baseUrl ?? ''}/api';
    if (_authService?.token != null) {
      _dio.options.headers['Authorization'] = 'Bearer ${_authService!.token}';
    }
  }

  // --- SOCKET.IO SETUP ---
  void _initSocket() {
    if (_baseUrl == null || _authService?.token == null) return;
    if (_socket != null && _socket!.connected) _socket!.disconnect();

    _socket = IO.io(_baseUrl, IO.OptionBuilder()
        .setTransports(['websocket'])
        .setExtraHeaders({'Authorization': 'Bearer ${_authService!.token}'})
        .enableAutoConnect()
        .build());

    _socket!.onConnect((_) {
      print('✅ Socket Connected');
      _socket!.emit('join', _authService!.user!.id);
    });

    _socket!.on('new_message', (data) {
      final conversationId = data['conversationId'];
      final message = Message.fromJson(data['message']);

      if (messagesCache.containsKey(conversationId)) {
        if (messagesCache[conversationId]!.any((m) => m.id == message.id)) return;
        messagesCache[conversationId]!.insert(0, message);
        notifyListeners();
      }
      _updateConversationList(conversationId, message);
    });

    _socket!.on('message_read', (data) {
      final conversationId = data['conversationId'];
      if (messagesCache.containsKey(conversationId)) {
        for (var msg in messagesCache[conversationId]!) { msg.isRead = true; }
        notifyListeners();
      }
    });
  }

  // --- CÁC HÀM QUẢN LÝ CONVERSATION ---

  Future<String?> getConversationId(String targetUserId) async {
    try {
      final response = await _dio.post('/conversations', data: {'targetId': targetUserId});
      return response.data['_id'];
    } catch (e) { return null; }
  }

  Future<void> fetchConversations() async {
    isLoading = true; notifyListeners();
    try {
      final response = await _dio.get('/conversations');
      final List<dynamic> data = response.data;
      conversations = data.map((json) => Conversation.fromJson(json)).toList();
    } finally { isLoading = false; notifyListeners(); }
  }

  Future<void> fetchMessages(String conversationId) async {
    if (!messagesCache.containsKey(conversationId)) messagesCache[conversationId] = [];
    try {
      final response = await _dio.get('/conversations/$conversationId/messages');
      final List<dynamic> data = response.data;
      messagesCache[conversationId] = data.map((json) => Message.fromJson(json)).toList();
      notifyListeners();
    } catch (e) { print("Lỗi tải tin nhắn: $e"); }
  }

  // --- CÁC HÀM GỬI TIN NHẮN (DÙNG CLOUDINARY) ---

  Future<void> sendMessage(String conversationId, String content, {String type = 'text', String? replyToId}) async {
    try {
      final Map<String, dynamic> data = {'content': content, 'type': type};
      if (replyToId != null) data['replyTo'] = replyToId;

      final response = await _dio.post('/conversations/$conversationId/messages', data: data);
      _socket?.emit('send_message', {'conversationId': conversationId, 'type': type, 'message': response.data});
    } catch (e) { print("Lỗi gửi tin: $e"); }
  }

  Future<void> sendImageMessage(BuildContext context, String conversationId, String filePath) async {
    try {
      final userService = Provider.of<UserService>(context, listen: false);
      // 🔥 Gọi hàm public (không có dấu _)
      final String? cloudUrl = await userService.uploadDirectToCloudinary(File(filePath), 'image', folder: 'xmasocial_chat');
      if (cloudUrl != null) {
        await sendMessage(conversationId, cloudUrl, type: 'image');
      }
    } catch (e) { debugPrint("❌ Lỗi gửi ảnh: $e"); }
  }

  Future<void> sendAudioMessage(BuildContext context, String conversationId, String filePath) async {
    try {
      final userService = Provider.of<UserService>(context, listen: false);
      // 🔥 SỬA: Đã bỏ dấu gạch dưới _ để gọi hàm public
      final String? cloudUrl = await userService.uploadDirectToCloudinary(File(filePath), 'video', folder: 'xmasocial_chat');
      if (cloudUrl != null) {
        await sendMessage(conversationId, cloudUrl, type: 'audio');
      }
    } catch (e) { debugPrint("❌ Lỗi gửi ghi âm: $e"); }
  }

  // --- CÁC HÀM CÀI ĐẶT & TƯƠNG TÁC ---

  // 🔥 BỔ SUNG: Hàm thả cảm xúc vào tin nhắn
  Future<void> reactToMessage(String conversationId, String messageId, String? reaction) async {
    try {
      await _dio.put('/conversations/$conversationId/messages/$messageId/react', data: {
        'reaction': reaction
      });
    } catch (e) {
      print("Lỗi reaction: $e");
    }
  }

  Future<void> recallMessage(String conversationId, String messageId) async {
    try {
      final response = await _dio.delete('/conversations/$conversationId/messages/$messageId');
      if (response.statusCode == 200) {
        _socket?.emit('delete_message', {'conversationId': conversationId, 'messageId': messageId});
      }
    } catch (e) { print("❌ Lỗi thu hồi: $e"); }
  }

  // Thu hồi (Revoke) dùng chung logic Recall
  void revokeMessage(String messageId, String conversationId) {
    recallMessage(conversationId, messageId);
  }

  Future<void> updateQuickReaction(String conversationId, String emoji) async {
    try {
      await _dio.put('/conversations/$conversationId/quick-reaction', data: {'reaction': emoji});
      _socket?.emit('quick_reaction_changed', {'conversationId': conversationId, 'reaction': emoji});
    } catch (e) { print("❌ Lỗi đổi Quick Reaction: $e"); }
  }

  Future<void> updateNickname(String conversationId, String targetUserId, String nickname) async {
    try {
      await _dio.put('/conversations/$conversationId/nickname', data: {'targetUserId': targetUserId, 'nickname': nickname});
    } catch (e) { print("❌ Lỗi đổi nickname: $e"); }
  }

  Future<void> updateTheme(String conversationId, String themeId) async {
    try { await _dio.put('/conversations/$conversationId/theme', data: {'themeId': themeId}); } catch (e) {}
  }

  void markAsRead(String conversationId) {
    _socket?.emit('mark_read', {'conversationId': conversationId});
  }

  void _updateConversationList(String conversationId, Message message) {
    final index = conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      final oldConv = conversations.removeAt(index);
      conversations.insert(0, Conversation(
          id: oldConv.id, participants: oldConv.participants, lastMessage: message,
          unreadCount: oldConv.unreadCount + 1, updatedAt: DateTime.now(), themeId: oldConv.themeId
      ));
      notifyListeners();
    }
  }
}
