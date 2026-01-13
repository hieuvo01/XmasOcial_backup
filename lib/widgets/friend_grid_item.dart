// Dán toàn bộ code này vào file: lib/widgets/friend_grid_item.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';

import '../screens/social/user_profile_screen.dart';
import '../services/auth_service.dart';
import '../services/navigation_service.dart'; // <-- THÊM IMPORT QUAN TRỌNG

class FriendGridItem extends StatelessWidget {
  final UserModel friend;

  const FriendGridItem({super.key, required this.friend});

  @override
  Widget build(BuildContext context) {
    const defaultAvatar = 'https://upload.wikimedia.org/wikipedia/commons/8/89/Portrait_Placeholder.png';
    // Lấy currentUserId từ AuthService
    final currentUserId = Provider.of<AuthService>(context, listen: false).user?.id;

    return GestureDetector(
      onTap: () {
        // ===== LOGIC ĐIỀU HƯỚNG MỚI SỬ DỤNG PROVIDER =====
        if (friend.id == currentUserId) {
          // TRƯỜNG HỢP 1: Nhấn vào chính mình
          // 1. Pop tất cả các màn hình con về màn hình SocialMainScreen
          Navigator.of(context).popUntil((route) => route.isFirst);

          // 2. Lấy NavigationService và ra lệnh chuyển trang
          // ProfileTab của bạn có index là 2 (0: Feed, 1: Reels, 2: Profile)
          Provider.of<NavigationService>(context, listen: false).navigateToPage(2);
        } else {
          // TRƯỜNG HỢP 2: Nhấn vào người khác
          // Đẩy một màn hình UserProfileScreen mới lên
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => UserProfileScreen(userId: friend.id),
            ),
          );
        }
        // ==================================================
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 1.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Image.network(
                friend.avatarUrl ?? defaultAvatar,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CupertinoActivityIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.person, size: 40, color: Colors.grey),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
              child: Text(
                friend.displayName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
