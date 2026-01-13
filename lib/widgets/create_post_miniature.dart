// File: lib/widgets/create_post_miniature.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../screens/social/create_post_screen.dart';

// === BƯỚC 1: IMPORT WIDGET MỚI ===
import 'avatar_with_story_border.dart';

class CreatePostMiniature extends StatelessWidget {
  final VoidCallback onPostCreated;

  const CreatePostMiniature({super.key, required this.onPostCreated});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context, listen: false).user;

    // Lấy màu từ theme
    final cardColor = Theme.of(context).cardColor;
    final dividerColor = Theme.of(context).dividerColor;
    final hintColor = Theme.of(context).inputDecorationTheme.hintStyle?.color ?? Colors.grey;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;

    // Nếu chưa load được user thì return rỗng để tránh lỗi
    if (user == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 8.0),
      // 👇 SỬA: Dùng cardColor thay vì Colors.white
      color: cardColor,
      child: Column(
        children: [
          Row(
            children: [
              // === BƯỚC 2: THAY THẾ CIRCLE AVATAR CŨ ===
              AvatarWithStoryBorder(
                userId: user.id,
                avatarUrl: user.avatarUrl,
                radius: 20,
                borderWidth: 2.0,
              ),
              // =========================================

              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (context) => CreatePostScreen(onPostCreated: onPostCreated),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      // 👇 SỬA: Dùng dividerColor cho viền
                      border: Border.all(color: dividerColor),
                    ),
                    // 👇 SỬA: Dùng hintColor cho chữ gợi ý
                    child: Text('Bạn đang nghĩ gì?', style: TextStyle(color: hintColor)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, thickness: 0.5, color: dividerColor),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.videocam,
                label: 'Video trực tiếp',
                color: Colors.red,
                textColor: textColor,
                onPressed: () {},
              ),
              _buildActionButton(
                icon: Icons.photo_library,
                label: 'Ảnh/video',
                color: Colors.green,
                textColor: textColor,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (context) => CreatePostScreen(onPostCreated: onPostCreated),
                    ),
                  );
                },
              ),
              _buildActionButton(
                icon: Icons.video_call,
                label: 'Phòng họp mặt',
                color: Colors.purple,
                textColor: textColor,
                onPressed: () {},
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    Color? textColor, // Thêm tham số màu chữ
  }) {
    return Expanded(
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: color),
        // 👇 SỬA: Dùng textColor thay vì Colors.black cứng
        label: Text(
          label,
          style: TextStyle(color: textColor, fontSize: 13), // Giảm size chữ xíu cho vừa vặn
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
