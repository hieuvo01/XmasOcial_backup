// File: lib/services/game_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'auth_service.dart'; // 👇 Import file AuthService

class GameService {
  // 👇 Biến chứa AuthService
  final AuthService _authService;

  // 👇 Constructor nhận AuthService từ Provider truyền vào
  GameService(this._authService);

  // Lấy URL backend
  String get baseUrl {
    // 1. Lấy biến BASE_URL từ file .env
    final String? envUrl = dotenv.env['BASE_URL'];

    // 2. Nếu tìm thấy link ngrok trong .env
    if (envUrl != null && envUrl.isNotEmpty) {
      // Vì trong .env bro lưu là "https://...app" (chưa có /api)
      // Nên ta phải nối thêm "/api" vào đuôi
      return '$envUrl/api';
    }

    // 3. Fallback: Nếu không tìm thấy .env thì mới dùng localhost
    return 'http://192.168.1.5:3000/api';
  }

  // --- 1. LƯU TRẠNG THÁI GAME ---
  Future<void> saveGameState(String gameId, Map<String, dynamic> gameState) async {
    try {
      // 👇 LẤY TOKEN TRỰC TIẾP TỪ AUTH SERVICE (Đã auto login ở main.dart)
      final token = _authService.token;

      if (token == null) {
        print("❌ Save Game Failed: Token is null (Not logged in)");
        return;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/games/save-state'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'gameId': gameId,
          'stateData': gameState,
        }),
      );

      if (response.statusCode != 200) {
        print("⚠️ Server Error Save Game: ${response.body}");
      } else {
        // print("✅ Game Saved!");
      }
    } catch (e) {
      print("❌ Connection Error (Save): $e");
    }
  }

  // --- 2. TẢI TRẠNG THÁI GAME ---
  Future<Map<String, dynamic>?> loadGameState(String gameId) async {
    try {
      // 👇 LẤY TOKEN TỪ AUTH SERVICE
      final token = _authService.token;

      if (token == null) {
        print("❌ Load Game Failed: Token is null (Not logged in)");
        return null;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/games/load-state/$gameId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print("📡 Load Game Response: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Kiểm tra cấu trúc trả về
        if (data['success'] == true && data['stateData'] != null) {
          return data['stateData'];
        }
      }
      return null;
    } catch (e) {
      print("❌ Connection Error (Load): $e");
      return null;
    }
  }

  // --- 3. XÓA SAVE GAME ---
  Future<void> clearGameState(String gameId) async {
    try {
      final token = _authService.token;
      if (token == null) return;

      await http.delete(
        Uri.parse('$baseUrl/games/clear-state/$gameId'),
        headers: { 'Authorization': 'Bearer $token' },
      );
    } catch (e) {
      print("Error clearing game state: $e");
    }
  }

  // --- 4. LƯU ĐIỂM CAO ---
  Future<void> submitScore(String gameId, int score) async {
    try {
      final token = _authService.token;
      if (token == null) return;

      await http.post(
        Uri.parse('$baseUrl/games/submit-score'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'gameId': gameId,
          'score': score,
        }),
      );
    } catch (e) {
      print("Error submitting score: $e");
    }
  }

  // --- 5. LẤY BẢNG XẾP HẠNG (Thêm cái này để dùng cho Leaderboard) ---
  Future<List<dynamic>> getLeaderboard(String gameId) async {
    try {
      // API này Public không cần token cũng được, nhưng gửi kèm cũng không sao
      final response = await http.get(Uri.parse('$baseUrl/games/leaderboard/$gameId'));

      if (response.statusCode == 200) {
        return jsonDecode(response.body); // Trả về List
      }
      return [];
    } catch (e) {
      print("Error getting leaderboard: $e");
      return [];
    }
  }
}
