// File: lib/screens/social/tabs/create_post_tab.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/auth_service.dart';
import '../create_post_screen.dart';

class CreatePostTab extends StatelessWidget {
  const CreatePostTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Lấy màu từ theme để hỗ trợ Dark Mode
    final hintColor = Theme.of(context).inputDecorationTheme.hintStyle?.color ?? Colors.grey;
    final dividerColor = Theme.of(context).dividerColor;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Consumer<AuthService>(
      builder: (context, authService, child) {
        // final currentUser = authService.user;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Column(
            children: [
              Row(
                children: [
                  // Nút bấm giả dạng TextField
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => CreatePostScreen(onPostCreated: () {}),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: dividerColor),
                        ),
                        child: Text(
                          'Bạn đang nghĩ gì?',
                          style: TextStyle(color: hintColor, fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              Divider(height: 20, thickness: 1, color: dividerColor),

              // Các nút chức năng (Ảnh, Video, Cảm xúc)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                      icon: Icons.photo_library,
                      label: 'Ảnh/Video',
                      color: Colors.green,
                      textColor: textColor
                  ),
                  _buildActionButton(
                      icon: Icons.person_add,
                      label: 'Gắn thẻ bạn bè',
                      color: Colors.blue,
                      textColor: textColor
                  ),
                  _buildActionButton(
                      icon: Icons.emoji_emotions,
                      label: 'Cảm xúc',
                      color: Colors.orange,
                      textColor: textColor
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  // Hàm helper để tạo các nút chức năng
  Widget _buildActionButton({required IconData icon, required String label, required Color color, Color? textColor}) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: textColor)),
      ],
    );
  }
}
