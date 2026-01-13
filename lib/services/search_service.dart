// lib/services/search_service.dart
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import từ file models mới tạo
import '../models.dart';

class SearchService {
  static const String _historyKey = 'search_history';

  Future<void> saveSearchQuery(String query) async {
    if (query.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_historyKey) ?? [];

    history.remove(query);
    history.insert(0, query);

    if (history.length > 20) {
      history = history.sublist(0, 20);
    }

    await prefs.setStringList(_historyKey, history);
  }

  Future<List<String>> getSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_historyKey) ?? [];
  }

  Future<void> clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  // --- HÀM FETCH SUGGESTIONS CẦN ĐƯỢC HOÀN THIỆN ---
  Future<List<SearchSuggestion>> fetchSuggestions(String query, Position? currentPosition) async {
    // Tạm thời để trống, bạn có thể thêm logic gọi API ở đây sau
    // Ví dụ: gọi API Nominatim hoặc Google Places
    return [];
  }
}
