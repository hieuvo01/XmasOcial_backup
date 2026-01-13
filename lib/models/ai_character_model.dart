// File: lib/models/ai_character_model.dart

// ✨ 1. Định nghĩa Enum ngay tại đây để độc lập
enum AiPersonality {
  normal,      // Bình thường, lịch sự
  funny,       // Hài hước, lầy lội
  cold,        // Lạnh lùng, cool ngầu
  cute,        // Dễ thương, nhõng nhẽo
  gangster,    // Giang hồ, hổ báo
}

class AICharacter {
  final String id;
  final String name;
  final String avatarUrl;
  final String bio;
  final String systemPrompt;
  final AiPersonality personality;

  AICharacter({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.bio,
    required this.systemPrompt,
    this.personality = AiPersonality.normal,
  });

  // Factory nhận JSON từ MongoDB
  factory AICharacter.fromJson(Map<String, dynamic> json) {
    return AICharacter(
      id: json['_id'] ?? json['id'] ?? '', // Cover cả _id (Mongo) và id (thường)
      name: json['name'] ?? 'Unknown AI',
      avatarUrl: json['avatarUrl'] ?? '',
      bio: json['bio'] ?? '',
      // Nếu API User ẩn systemPrompt thì mặc định là rỗng (Logic chat sẽ tự fallback)
      systemPrompt: json['systemPrompt'] ?? '',
      personality: _parsePersonality(json['personality']),
    );
  }

  // Helper chuyển String từ DB sang Enum
  static AiPersonality _parsePersonality(String? type) {
    switch (type) {
      case 'gangster': return AiPersonality.gangster;
      case 'cute': return AiPersonality.cute;
      case 'cold': return AiPersonality.cold;
      case 'funny': return AiPersonality.funny;
      case 'normal':
      default: return AiPersonality.normal;
    }
  }
}
