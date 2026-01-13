// File: lib/config/app_config.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // Lấy giá trị từ file .env, nếu không tìm thấy thì trả về chuỗi rỗng hoặc báo lỗi
  static String get baseUrl => dotenv.env['BASE_URL'] ?? '';
  static String get githubClientId => dotenv.env['GITHUB_CLIENT_ID'] ?? '';
  static String get githubRedirectUri => dotenv.env['GITHUB_REDIRECT_URI'] ?? '';
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static int get zegoAppId => int.parse(dotenv.env['ZEGO_APP_ID'] ?? '0');
  static String get zegoAppSign => dotenv.env['ZEGO_APP_SIGN'] ?? '';

}
