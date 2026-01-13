// File: lib/widgets/avatar_with_story_border.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/story_service.dart';
import '../screens/social/story_viewer_screen.dart';

class AvatarWithStoryBorder extends StatelessWidget {
  final String userId;
  final String? avatarUrl;
  final double radius;
  final double borderWidth;
  final VoidCallback? onTap;

  const AvatarWithStoryBorder({
    super.key,
    required this.userId,
    this.avatarUrl,
    this.radius = 20.0,
    this.borderWidth = 2.5,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final storyService = context.watch<StoryService>();

    final storyGroupIndex = storyService.storyGroups.indexWhere((group) => group.user.id == userId);
    final hasStory = storyGroupIndex != -1;

    bool allViewed = false;
    if (hasStory) {
      allViewed = storyService.storyGroups[storyGroupIndex].stories.every((s) => s.isViewed);
    }

    const defaultAvatar = 'https://upload.wikimedia.org/wikipedia/commons/8/89/Portrait_Placeholder.png';
    final imageUrl = (avatarUrl != null && avatarUrl!.isNotEmpty) ? avatarUrl! : defaultAvatar;

    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          onTap!();
          return;
        }
        if (hasStory) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StoryViewerScreen(
                storyGroups: storyService.storyGroups,
                initialGroupIndex: storyGroupIndex,
              ),
            ),
          );
        } else {
          print("User không có story, mở Profile...");
          // Cân nhắc thêm logic mở profile ở đây
        }
      },
      // === SỬA LẠI TOÀN BỘ CẤU TRÚC WIDGET BÊN DƯỚI ===
      child: CircleAvatar(
        radius: radius, // Bán kính tổng thể bao gồm cả viền xanh
        backgroundColor: hasStory
            ? (allViewed ? Colors.grey.shade400 : CupertinoColors.systemBlue)
            : Colors.transparent, // Không có story thì viền trong suốt
        child: CircleAvatar(
          radius: radius - borderWidth, // Bán kính của viền trắng bên trong
          backgroundColor: Colors.white, // Màu của viền trắng
          child: CircleAvatar(
            radius: radius - (borderWidth + 2), // Bán kính của ảnh đại diện, nhỏ hơn viền trắng một chút
            backgroundColor: Colors.grey[200],
            backgroundImage: CachedNetworkImageProvider(imageUrl),
          ),
        ),
      ),
    );
  }
}
