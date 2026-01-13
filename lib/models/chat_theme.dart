// File: lib/models/chat_theme.dart

import 'package:flutter/material.dart';

class ChatTheme {
  final String id;
  final String name;
  final Color primaryColor;
  final List<Color> gradient; // Gradient cho bong bóng chat
  final Color? appBarColor;   // Màu icon trên AppBar

  // --- THÊM CÁI NÀY ---
  final List<Color>? backgroundGradient; // Gradient cho nền chat (nhạt hơn)
  final String? backgroundImage;
  const ChatTheme({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.gradient,
    this.appBarColor,
    this.backgroundGradient, // <--- Thêm vào constructor
    this.backgroundImage,
  });
}

// Danh sách các theme mẫu (Đã update background)
final List<ChatTheme> appThemes = [
  ChatTheme(
    id: 'galaxy',
    name: 'Vũ trụ',
    primaryColor: const Color(0xFFC77DFF), // Màu tím sáng cho icon
    gradient: [const Color(0xFF9D4EDD), const Color(0xFFE0AAFF)],
    // Không cần backgroundGradient vì sẽ dùng ảnh
    backgroundImage: 'https://images.unsplash.com/photo-1534796636912-3b95b3ab5986?q=80&w=1000&auto=format&fit=crop', // Link ảnh mẫu
  ),
  ChatTheme(
    id: 'christmas',
    name: 'Giáng sinh',
    primaryColor: const Color(0xFFD32F2F),
    gradient: [const Color(0xFFD32F2F), const Color(0xFFEF5350)],
    backgroundImage: 'https://static-www.adweek.com/wp-content/uploads/2022/12/Messenger-Christmas-Theme-Hero.png?w=1240',
  ),
  ChatTheme(
    id: 'classic_blue',
    name: 'Cổ điển',
    primaryColor: const Color(0xFF0084FF),
    gradient: [const Color(0xFF0084FF), const Color(0xFF0084FF).withOpacity(0.8)],
    // Nền trắng cổ điển
    backgroundGradient: [Colors.white, Colors.white],
  ),
  ChatTheme(
    id: 'love',
    name: 'Tình yêu',
    primaryColor: const Color(0xFFFF3366),
    gradient: [const Color(0xFFFF3366), const Color(0xFFFF6699)],
    // Nền hồng phấn siêu nhạt
    backgroundImage: 'https://i.pinimg.com/736x/b8/b8/52/b8b85211dba2ce2daaf9b901d9aeed09.jpg',

  ),
  ChatTheme(
    id: 'ocean',
    name: 'Đại dương',
    primaryColor: const Color(0xFF00C6FF),
    gradient: [const Color(0xFF0072FF), const Color(0xFF00C6FF)],
    // Nền xanh nước biển nhạt
    backgroundGradient: [const Color(0xFFE0F7FA), const Color(0xFFB2EBF2)],
  ),
  ChatTheme(
    id: 'lofi',
    name: 'Lofi',
    primaryColor: const Color(0xFF00C6FF),
    gradient: [const Color(0xFF0072FF), const Color(0xFF00C6FF)],
    // Nền xanh nước biển nhạt
    backgroundImage: 'https://preview.redd.it/the-new-theme-from-messenger-lo-fi-is-so-aesthetic-i-had-to-v0-znalhai8daq81.jpg?width=640&crop=smart&auto=webp&s=485f0334373de7ddb3d6bcaf43463da704c88706',

  ),
  ChatTheme(
    id: 'sunset',
    name: 'Hoàng hôn',
    primaryColor: const Color(0xFFFC466B),
    gradient: [const Color(0xFF3F5EFB), const Color(0xFFFC466B)],
    // Nền tím nhạt pha hồng
    backgroundGradient: [const Color(0xFFF3E5F5), const Color(0xFFFCE4EC)],
  ),
  ChatTheme(
    id: 'nature',
    name: 'Thiên nhiên',
    primaryColor: const Color(0xFF11998E),
    gradient: [const Color(0xFF11998E), const Color(0xFF38EF7D)],
    // Nền xanh lá nhạt
    backgroundGradient: [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)],
  ),
  ChatTheme(
    id: 'night',
    name: 'Bóng đêm',
    primaryColor: Colors.white, // Icon màu trắng cho nổi
    gradient: [Colors.white, Colors.grey], // Bubble trắng/xám
    // Nền tối
    backgroundGradient: [const Color(0xFF121212), const Color(0xFF2C3E50)],
  ),
];
