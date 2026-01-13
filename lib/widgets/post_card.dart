// File: lib/widgets/post_card.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/post_model.dart';
import '../models/reaction_model.dart';
import '../models/user_model.dart';
import '../services/post_service.dart';
import 'reaction_bar.dart';
import '../screens/post_detail_screen.dart';
import 'full_screen_image_viewer.dart';
import '../screens/social/user_profile_screen.dart';
import '../screens/post_reactions_screen.dart';

// Import các widget hỗ trợ Video
import 'video_player_item.dart';
import 'video_thumbnail_widget.dart'; // <--- QUAN TRỌNG: Nhớ tạo file này như hướng dẫn trước

// Import Widget Avatar có viền Story
import 'avatar_with_story_border.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final UserModel? currentUser;
  final bool isDetailView;
  final Function(Post, ReactionModel?)? onPostUpdated;

  const PostCard({
    super.key,
    required this.post,
    this.currentUser,
    this.isDetailView = false,
    this.onPostUpdated,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  ReactionModel? _currentUserReaction;

  @override
  void initState() {
    super.initState();
    _updateCurrentUserReaction();
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post != oldWidget.post) {
      _updateCurrentUserReaction();
    }
  }

  void _updateCurrentUserReaction() {
    if (widget.currentUser == null) {
      setState(() {
        _currentUserReaction = null;
      });
      return;
    }
    try {
      final reaction = widget.post.reactions
          .firstWhere((r) => r.user.id == widget.currentUser!.id);
      setState(() {
        _currentUserReaction = reaction;
      });
    } catch (e) {
      setState(() {
        _currentUserReaction = null;
      });
    }
  }

  void _onReactionChanged(ReactionModel? newReaction) {
    final postService = Provider.of<PostService>(context, listen: false);
    final currentUserId = widget.currentUser?.id;
    if (currentUserId == null) return;

    String? newReactionType = newReaction?.type;

    if (widget.isDetailView) {
      widget.onPostUpdated?.call(widget.post, newReaction);
      return;
    }

    setState(() {
      final existingReactionIndex =
      widget.post.reactions.indexWhere((r) => r.user.id == currentUserId);

      if (existingReactionIndex != -1) {
        if (newReactionType == null) {
          widget.post.reactions.removeAt(existingReactionIndex);
          _currentUserReaction = null;
        } else {
          final updatedReaction = widget.post.reactions[existingReactionIndex]
              .copyWith(type: newReactionType);
          widget.post.reactions[existingReactionIndex] = updatedReaction;
          _currentUserReaction = updatedReaction;
        }
      } else {
        if (newReactionType != null) {
          final reactionToAdd =
          ReactionModel(user: widget.currentUser!, type: newReactionType);
          widget.post.reactions.add(reactionToAdd);
          _currentUserReaction = reactionToAdd;
        }
      }
    });

    postService.reactToPost(widget.post.id, newReactionType);
  }

  void _navigateToDetail() {
    if (widget.isDetailView) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(postId: widget.post.id),
      ),
    );
  }

  // --- LOGIC CHỈNH SỬA BÀI VIẾT (Đã Nâng Cấp Dark Mode) ---
  void _handleEditPost() {
    final TextEditingController editController =
    TextEditingController(text: widget.post.content);
    bool isUpdating = false;

    // Lấy Theme hiện tại
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Màu sắc động theo Theme
    final backgroundColor = isDark ? Colors.grey[900] : Colors.white;
    final textFieldColor = isDark ? Colors.grey[800] : Colors.grey[100];
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.grey[400] : Colors.grey[600];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Để bàn phím không che mất
      backgroundColor: backgroundColor, // Màu nền modal
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Chỉnh sửa bài viết",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor // Màu chữ tiêu đề
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: editController,
                    maxLines: 5,
                    minLines: 1,
                    autofocus: true,
                    style: TextStyle(color: textColor), // Màu chữ nhập vào
                    decoration: InputDecoration(
                      hintText: "Bạn đang nghĩ gì?",
                      hintStyle: TextStyle(color: hintColor), // Màu placeholder
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none, // Bỏ viền mặc định cho đẹp
                      ),
                      filled: true,
                      fillColor: textFieldColor, // Màu nền ô nhập
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isUpdating
                          ? null
                          : () async {
                        final newContent = editController.text.trim();
                        if (newContent.isEmpty) return;

                        setModalState(() => isUpdating = true);

                        try {
                          final updatedPost =
                          await Provider.of<PostService>(context,
                              listen: false)
                              .updatePost(
                              widget.post.id, newContent);

                          if (mounted) {
                            Navigator.pop(context); // Đóng modal
                            // Cập nhật UI ngay lập tức
                            setState(() {
                              widget.post.content = updatedPost.content;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      "Đã cập nhật bài viết thành công!")),
                            );
                          }
                        } catch (e) {
                          setModalState(() => isUpdating = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Lỗi cập nhật: $e")),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        disabledBackgroundColor: Colors.blue.withOpacity(0.5),
                      ),
                      child: isUpdating
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                          : const Text("Lưu thay đổi",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    timeago.setLocaleMessages('vi', timeago.ViMessages());
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: InkWell(
        onTap: _navigateToDetail,
        splashColor: Colors.transparent,
        highlightColor: Colors.grey.withOpacity(0.1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPostHeader(),
            if (widget.post.content.isNotEmpty) _buildPostContent(),
            if (widget.post.mediaUrls.isNotEmpty)
              _buildPostMedia(),
            if (widget.post.reactions.isNotEmpty ||
                widget.post.commentCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 8.0),
                child: _buildPostStats(),
              ),
            if (!widget.isDetailView)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.0),
                child: Divider(height: 1, thickness: 0.5),
              ),
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              child: ReactionBar(
                targetId: widget.post.id,
                targetType: 'post',
                currentUserReaction: _currentUserReaction,
                onReactionChanged: _onReactionChanged,
                onCommentButtonPressed: _navigateToDetail,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 10.0, 4.0, 10.0),
      child: Row(
        children: [
          AvatarWithStoryBorder(
            userId: widget.post.author.id,
            avatarUrl: widget.post.author.avatarUrl,
            radius: 20,
            borderWidth: 2.0,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) =>
                      UserProfileScreen(userId: widget.post.author.id))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.post.author.displayName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(timeago.format(widget.post.createdAt, locale: 'vi'),
                      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: Colors.grey),
            onSelected: (value) async {
              if (value == 'delete') {
                final bool? confirmDelete = await showCupertinoDialog<bool>(
                  context: context,
                  builder: (BuildContext context) => CupertinoAlertDialog(
                    title: const Text('Xác nhận xóa'),
                    content: const Text(
                        'Bạn có chắc chắn muốn xóa bài viết này không? Hành động này không thể hoàn tác.'),
                    actions: <CupertinoDialogAction>[
                      CupertinoDialogAction(
                        child: const Text('Hủy'),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                      CupertinoDialogAction(
                        isDestructiveAction: true,
                        child: const Text('Xóa'),
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ],
                  ),
                );
                if (confirmDelete == true) {
                  try {
                    await Provider.of<PostService>(context, listen: false)
                        .deletePost(widget.post.id);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Lỗi: Không thể xóa bài viết. $e')),
                      );
                    }
                  }
                }
              } else if (value == 'edit') {
                _handleEditPost();
              } else if (value == 'report') {
                print('Báo cáo bài viết ${widget.post.id}');
              }
            },
            itemBuilder: (BuildContext context) {
              final isMyPost = widget.currentUser?.id == widget.post.author.id;
              if (isMyPost) {
                return <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 10),
                      Text('Chỉnh sửa bài viết')
                    ]),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      SizedBox(width: 10),
                      Text('Xóa bài viết', style: TextStyle(color: Colors.red))
                    ]),
                  ),
                ];
              } else {
                return <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'report',
                    child: Row(children: [
                      Icon(Icons.flag_outlined, size: 20),
                      SizedBox(width: 10),
                      Text('Báo cáo bài viết')
                    ]),
                  ),
                ];
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPostContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 0, 12.0, 10.0),
      child: Text(widget.post.content,
          style: const TextStyle(fontSize: 16, height: 1.4)),
    );
  }

  // --- LOGIC HIỂN THỊ ĐA PHƯƠNG TIỆN (ẢNH/VIDEO) ---
  Widget _buildPostMedia() {
    final mediaUrls = widget.post.mediaUrls;
    final count = mediaUrls.length;

    if (count == 0) return const SizedBox.shrink();

    // TRƯỜNG HỢP 1: CHỈ CÓ 1 ẢNH/VIDEO
    if (count == 1) {
      final url = mediaUrls.first;
      final heroTag = 'post_media_${widget.post.id}_0';

      return GestureDetector(
        onTap: () => _openFullScreen(url, heroTag),
        child: Hero(
          tag: heroTag,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 400),
            width: double.infinity,
            child: _buildImageWidget(url),
          ),
        ),
      );
    }

    // TRƯỜNG HỢP 2: TỪ 2 ẢNH TRỞ LÊN (HIỂN THỊ GRID)
    return Container(
      height: 350, // Chiều cao cố định cho grid
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          // Cột bên trái (Luôn hiển thị ảnh đầu tiên)
          Expanded(
            flex: 1,
            child: _buildGridItem(mediaUrls[0], 0, height: double.infinity),
          ),
          const SizedBox(width: 2), // Khoảng cách giữa các ảnh

          // Cột bên phải
          Expanded(
            flex: 1,
            child: Column(
              children: [
                // Ảnh thứ 2 (Góc trên phải)
                Expanded(
                  flex: 1,
                  child: _buildGridItem(mediaUrls[1], 1, height: double.infinity),
                ),
                // Xử lý ảnh thứ 3 hoặc phần còn lại
                if (count > 2) ...[
                  const SizedBox(height: 2),
                  Expanded(
                    flex: 1,
                    child: count == 3
                        ? _buildGridItem(mediaUrls[2], 2, height: double.infinity)
                        : _buildGridItem(mediaUrls[2], 2, height: double.infinity, remainingCount: count - 3),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget con để hiển thị từng ô ảnh trong Grid
  Widget _buildGridItem(String url, int index, {required double height, int remainingCount = 0}) {
    final heroTag = 'post_media_${widget.post.id}_$index';

    return GestureDetector(
      onTap: () => _openFullScreen(url, heroTag),
      child: Hero(
        tag: heroTag,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildImageWidget(url, height: height),

            // Lớp phủ hiển thị số lượng ảnh còn lại (Ví dụ: +3)
            if (remainingCount > 0)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Text(
                    '+$remainingCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 👇👇👇 SỬA LOGIC HIỂN THỊ ẢNH/VIDEO THUMBNAIL TẠI ĐÂY 👇👇👇
  Widget _buildImageWidget(String url, {double? height}) {
    bool isVideo = url.toLowerCase().endsWith('.mp4') ||
        url.toLowerCase().endsWith('.mov') ||
        url.toLowerCase().endsWith('.avi');

    if (isVideo) {
      // Nếu là video, dùng VideoThumbnailWidget để load ảnh thumb từ URL
      return SizedBox(
        height: height,
        child: VideoThumbnailWidget(
          videoPath: url,
          isLocal: false, // Link từ server (network)
        ),
      );
    }

    // Nếu là ảnh, dùng Image.network bình thường
    return Image.network(
      url,
      height: height,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.grey[200],
          child: const Center(child: CupertinoActivityIndicator()),
        );
      },
      errorBuilder: (context, error, stackTrace) =>
          Container(color: Colors.grey[200], child: const Icon(Icons.broken_image, color: Colors.grey)),
    );
  }
  // 👆👆👆

  // Hàm mở ảnh/video Full màn hình - ĐÃ CẬP NHẬT ĐỂ VUỐT ẢNH
  void _openFullScreen(String url, String tag) {
    bool isVideo = url.toLowerCase().endsWith('.mp4') ||
        url.toLowerCase().endsWith('.mov');

    if (isVideo) {
      // Giữ nguyên logic mở Video (Video thường không vuốt chung với gallery ảnh)
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
                backgroundColor: Colors.transparent,
                iconTheme: const IconThemeData(color: Colors.white)
            ),
            body: Center(
              child: VideoPlayerItem(videoUrl: url),
            ),
          ),
        ),
      );
    } else {
      // 🔥 LOGIC MỚI: Tìm vị trí của ảnh hiện tại trong danh sách media
      final imageOnlyList = widget.post.mediaUrls.where((u) {
        return !u.toLowerCase().endsWith('.mp4') && !u.toLowerCase().endsWith('.mov');
      }).toList();

      int initialIndex = imageOnlyList.indexOf(url);

      Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (context, _, __) => FullScreenImageViewer(
            imageUrls: imageOnlyList,
            startIndex: initialIndex,
            tag: tag,
          ),
        ),
      );
    }
  }

  Widget _buildPostStats() {
    final uniqueReactionTypes =
    widget.post.reactions.map((r) => r.type).toSet().toList();
    final totalReactions = widget.post.reactions.length;

    return Row(
      children: [
        if (totalReactions > 0)
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      PostReactionsScreen(postId: widget.post.id),
                ),
              );
            },
            child: Row(
              children: [
                SizedBox(
                  width: (uniqueReactionTypes.length > 3
                      ? 3
                      : uniqueReactionTypes.length) *
                      14.0 +
                      8,
                  height: 22,
                  child: Stack(
                    children: List.generate(
                      uniqueReactionTypes.length > 3
                          ? 3
                          : uniqueReactionTypes.length,
                          (index) {
                        final reactionType = uniqueReactionTypes[index];
                        return Container(
                          margin: EdgeInsets.only(left: index * 14.0),
                          padding: const EdgeInsets.all(1.5),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black12, blurRadius: 1.0)
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/reactions/$reactionType.gif',
                            width: 18,
                            height: 18,
                            errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.thumb_up,
                                size: 12, color: Colors.blue),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(totalReactions.toString(),
                    style: const TextStyle(color: Colors.grey, fontSize: 15)),
              ],
            ),
          ),
        const Spacer(),
        if (widget.post.commentCount > 0)
          GestureDetector(
            onTap: _navigateToDetail,
            child: Text('${widget.post.commentCount} bình luận',
                style: const TextStyle(color: Colors.grey, fontSize: 15)),
          ),
      ],
    );
  }
}
