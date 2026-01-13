// File: lib/config/story_styles.dart
import 'package:flutter/material.dart';

class StoryStyleHelper {
  // Danh sách các style màu nền (Giống Facebook/Instagram)
  static final List<Map<String, dynamic>> styles = [
    {
      'id': 'blue_gradient',
      'gradient': const LinearGradient(
        colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      'id': 'fire_gradient',
      'gradient': const LinearGradient(
        colors: [Color(0xFFf12711), Color(0xFFf5af19)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      'id': 'purple_gradient',
      'gradient': const LinearGradient(
        colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      'id': 'green_gradient',
      'gradient': const LinearGradient(
        colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      'id': 'dark_mode',
      'gradient': const LinearGradient(
        colors: [Color(0xFF232526), Color(0xFF414345)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
  ];

  // Hàm lấy Gradient từ ID (dùng khi hiển thị story)
  static Gradient getGradient(String? styleId) {
    final style = styles.firstWhere(
          (element) => element['id'] == styleId,
      orElse: () => styles[0], // Mặc định là cái đầu tiên
    );
    return style['gradient'] as Gradient;
  }
}
