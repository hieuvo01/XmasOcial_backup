// lib/utils/sticker_list.dart

// 1. Model cho một bộ sticker
class StickerPack {
  final String name; // Tên bộ sticker (VD: "QooBee")
  final String icon; // Icon đại diện cho bộ, hiển thị trên thanh tab
  final String basePath; // Đường dẫn thư mục chứa sticker của bộ này
  final List<String> stickers; // Danh sách tên file sticker (VD: ['1.gif', '2.gif'])
  final String format; // Định dạng file (png, webp, gif...)

  StickerPack({
    required this.name,
    required this.icon,
    required this.basePath,
    required this.stickers,
    this.format = 'webp', // Mặc định là webp
  });

  // Hàm tiện ích để lấy đường dẫn đầy đủ của một sticker
  String getStickerPath(int index) {
    return '$basePath/${stickers[index]}';
  }
}

// 2. Định nghĩa các bộ sticker của bro
// QUAN TRỌNG: Bro phải đảm bảo tên file trong thư mục assets là 1.gif, 2.gif... (không có số 0 ở đầu)
final List<StickerPack> myStickerPacks = [
  // BỘ 1: QooBee (Gấu Vàng)
  StickerPack(
    name: "QooBee GIF",
    basePath: 'assets/stickers/qoobee',
    icon: 'assets/stickers/qoobee/icon.gif',
    // Tạo file từ 1.gif -> 8.gif
    stickers: List.generate(8, (i) => '${i + 1}.gif'),
    format: 'gif',
  ),

  StickerPack(
    name: "Meep GIF",
    basePath: 'assets/stickers/meep',
    icon: 'assets/stickers/meep/icon.gif',
    // Tạo file từ 1.gif -> 16.gif (Bỏ số 0 ở đầu)
    stickers: List.generate(8, (i) => '${i + 1}.gif'),
    format: 'gif',
  ),

  StickerPack(
    name: "Mimi GIF",
    basePath: 'assets/stickers/mimi',
    icon: 'assets/stickers/mimi/icon.gif',
    // Tạo file từ 1.gif -> 8.gif (Bỏ số 0 ở đầu)
    stickers: List.generate(8, (i) => '${i + 1}.gif'),
    format: 'gif',
  ),
];
