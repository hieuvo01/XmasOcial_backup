// File: lib/services/game_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'auth_service.dart';

class GameService {
  final AuthService _authService;

  GameService(this._authService);

  // Lấy URL backend
  String get baseUrl {
    final String? envUrl = dotenv.env['BASE_URL'];
    if (envUrl != null && envUrl.isNotEmpty) {
      // Đã có /api ở đây
      return '$envUrl/api';
    }
    return 'http://192.168.1.5:3000/api';
  }

  // --- 1. LƯU TRẠNG THÁI GAME ---
  Future<void> saveGameState(String gameId, Map<String, dynamic> gameState) async {
    try {
      final token = _authService.token;
      if (token == null) {
        print("❌ Save Game Failed: Token is null");
        return;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/games/save-state'), // ✅ Đúng
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
      }
    } catch (e) {
      print("❌ Connection Error (Save): $e");
    }
  }

  // --- 2. TẢI TRẠNG THÁI GAME ---
  Future<Map<String, dynamic>?> loadGameState(String gameId) async {
    try {
      final token = _authService.token;
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/games/load-state/$gameId'), // ✅ Đúng
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print("📡 Load Game Response: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
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
        Uri.parse('$baseUrl/games/clear-state/$gameId'), // ✅ Đúng
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
        Uri.parse('$baseUrl/games/submit-score'), // ✅ Đúng
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

  // --- 5. LẤY BẢNG XẾP HẠNG (Fetch Leaderboard) ---
  Future<List<dynamic>> fetchLeaderboard(String gameId) async {
    // ⚠️ ĐÃ SỬA Ở ĐÂY: Xóa chữ /api thừa đi
    final url = Uri.parse('$baseUrl/games/leaderboard/$gameId');

    try {
      print("🏆 Đang tải BXH cho game: $gameId từ $url");

      final response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("❌ Lỗi Server BXH: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("❌ Lỗi kết nối BXH: $e");
      return [];
    }
  }
}
