// File: lib/services/character_ai_service.dart

import 'dart:convert';
import 'package:flutter/material.dart'; // Import để dùng BuildContext (dù không dùng tới nhưng để khớp tham số bên UI)
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/ai_character_model.dart';

// ⚠️ LƯU Ý: Enum AiPersonality nên để bên file model (ai_character_model.dart).
// Nếu bên đó có rồi thì bro xóa đoạn enum dưới này đi để tránh trùng lặp nhé.
// enum AiPersonality { normal, funny, cold, cute, gangster }

class CharacterAiService {
  // ⚠️ Dùng biến từ AppConfig + nối thêm đuôi '/api'
  static String get baseUrl => "${AppConfig.baseUrl}/api";

  // --- HÀM HELPER: LẤY TOKEN ---
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  // --- HÀM HELPER: LẤY CÂU LỆNH NHẬP VAI THEO TÍNH CÁCH ---
  String _getPersonalityInstruction(AiPersonality personality) {
    switch (personality) {
      case AiPersonality.funny:
        return "Hãy trả lời một cách hài hước, lầy lội, trêu chọc người dùng. Xưng hô là 'tao' và gọi người dùng là 'mày' hoặc 'bro'. Dùng ngôn ngữ đời thường, slang.";
      case AiPersonality.cold:
        return "Hãy trả lời thật ngắn gọn, lạnh lùng, dứt khoát. Tỏ ra cool ngầu, không dùng cảm xúc, không dùng icon.";
      case AiPersonality.cute:
        return "Hãy trả lời thật dễ thương, ngọt ngào. Xưng hô là 'em' hoặc 'tớ', gọi người dùng là 'anh iu' hoặc 'cậu'. Dùng nhiều emoji đáng yêu (🌸, 🥺, 👉👈).";
      case AiPersonality.gangster:
        return "Hãy nhập vai đại ca giang hồ. Xưng 'bố mày', gọi 'chú em'. Giọng điệu hổ báo nhưng nghĩa khí. Dùng từ lóng giang hồ.";
      case AiPersonality.normal:
      default:
        return "Hãy trả lời tự nhiên, lịch sự và thân thiện.";
    }
  }

  // ==========================================
  // 👇 1. MỚI: LẤY DANH SÁCH AI TỪ SERVER
  // ==========================================
  Future<List<AICharacter>> fetchActiveCharacters(BuildContext context) async {
    try {
      final token = await _getToken();
      // Nếu chưa login cũng có thể cho xem list (tùy logic), nhưng ở đây mình yêu cầu token
      if (token == null || token.isEmpty) return [];

      final url = Uri.parse('$baseUrl/ai/characters');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        // Map từ JSON sang Model AICharacter
        return data.map((json) => AICharacter.fromJson(json)).toList();
      } else {
        print("❌ Lỗi lấy danh sách AI: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("❌ Lỗi kết nối fetchActiveCharacters: $e");
      return [];
    }
  }

  // ==========================================
  // 2. LẤY LỊCH SỬ CHAT
  // ==========================================
  Future<List<Map<String, String>>> getChatHistory(String characterId) async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        return [];
      }

      final url = Uri.parse('$baseUrl/ai/history/$characterId');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => {
          'role': item['role'].toString(),
          'content': item['content'].toString(),
        }).toList();
      }
      return [];
    } catch (e) {
      print("❌ Lỗi lấy history: $e");
      return [];
    }
  }

  // ==========================================
  // 3. GỬI TIN NHẮN
  // ==========================================
  Future<String> getCharacterResponse({
    required String userMessage,
    required AICharacter character,
    List<Map<String, String>>? history,
    AiPersonality personality = AiPersonality.normal,
  }) async {
    try {
      final token = await _getToken();

      if (token == null || token.isEmpty) {
        return "(Lỗi: Bạn chưa đăng nhập)";
      }

      final url = Uri.parse('$baseUrl/ai/chat');

      // Map dữ liệu history
      final convertedHistory = history?.map((msg) {
        return {
          'role': msg['role'] == 'ai' ? 'model' : 'user',
          'content': msg['content']
        };
      }).toList();

      // Lưu ý: Backend bây giờ đã tự xử lý System Prompt dựa trên ID nhân vật.
      // Tuy nhiên, nếu bro vẫn muốn gửi kèm 'personalityInstruction' để tùy biến thêm từ phía Client,
      // bro có thể gửi nó trong field systemPrompt (fallback) hoặc backend sẽ tự xử lý.

      final personalityInstruction = _getPersonalityInstruction(personality);
      final clientSidePrompt = """
      ${character.systemPrompt}
      CHẾ ĐỘ TÍNH CÁCH: $personalityInstruction
      """;

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'message': userMessage,
          'character': {
            'id': character.id,
            'name': character.name,
            'bio': character.bio,
            // Gửi prompt này để Backend dùng làm fallback nếu cần
            'systemPrompt': clientSidePrompt
          },
          'history': convertedHistory ?? []
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['reply'] ?? "...";
      } else {
        print("❌ Lỗi Server Chat: ${response.body}");
        return "(Lỗi Server: ${response.statusCode})";
      }
    } catch (e) {
      print("❌ Lỗi kết nối chat: $e");
      return "(Không kết nối được với Server)";
    }
  }

  // ==========================================
  // 4. XÓA LỊCH SỬ CHAT
  // ==========================================
  Future<bool> clearChatHistory(String characterId) async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) return false;

      final url = Uri.parse('$baseUrl/ai/history/$characterId');

      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        print("✅ Đã xóa lịch sử chat với $characterId");
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}
