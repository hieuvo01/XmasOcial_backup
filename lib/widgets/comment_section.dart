// Dán toàn bộ code này vào file: lib/widgets/comment_section.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/comment_model.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';

class CommentSection extends StatelessWidget {
  final String postId;
  final String postAuthorId;
  final List<Comment> comments;

  final Function(Comment) onReply;
  final Function(String) onNavigateToProfile;
  final VoidCallback onCommentDeleted;

  const CommentSection({
    super.key,
    required this.postId,
    required this.postAuthorId,
    required this.comments,
    required this.onReply,
    required this.onNavigateToProfile,
    required this.onCommentDeleted,
  });

  List<Comment> _flattenComments(List<Comment> rootComments) {
    List<Comment> flatList = [];
    for (var comment in rootComments) {
      flatList.add(comment);
      if (comment.replies.isNotEmpty) {
        flatList.addAll(comment.replies);
      }
    }
    return flatList;
  }

  void _showDeleteConfirmationDialog(BuildContext context, Comment comment) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Xóa bình luận?'),
        content: const Text('Hành động này không thể hoàn tác.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Hủy'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            child: const Text('Xóa'),
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteComment(context, comment);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteComment(BuildContext context, Comment comment) async {
    try {
      final postService = Provider.of<PostService>(context, listen: false);
      await postService.deleteComment(postId, comment.id);
      onCommentDeleted();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi xóa: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayComments = _flattenComments(comments);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (displayComments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Center(
          child: Text(
            'Chưa có bình luận nào.\nHãy là người đầu tiên!',
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayComments.length,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      itemBuilder: (context, index) {
        final comment = displayComments[index];
        return _buildCommentItem(context, comment, isDark);
      },
    );
  }

  Widget _buildCommentItem(BuildContext context, Comment comment, bool isDark) {
    final currentUserId = Provider.of<AuthService>(context, listen: false).user?.id;
    final isOwner = comment.author.id == currentUserId || postAuthorId == currentUserId;

    // Màu nền khối comment: Xám nhạt (Light) hoặc Xám đen (Dark)
    final bubbleColor = isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE9EBEE);
    // Màu tên user: Trắng (Dark) hoặc Đen đậm (Light)
    final nameColor = isDark ? Colors.white : Colors.black87;

    // Màu nút hành động (Thích/Phản hồi)
    final actionTextColor = isDark ? Colors.grey[400] : Colors.grey[800];
    // Màu thời gian
    final timeColor = isDark ? Colors.grey[500] : Colors.grey[700];

    return GestureDetector(
      onLongPress: () {
        if (isOwner) {
          _showDeleteConfirmationDialog(context, comment);
        }
      },
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => onNavigateToProfile(comment.author.id),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                backgroundImage: (comment.author.avatarUrl != null)
                    ? NetworkImage(comment.author.avatarUrl!)
                    : null,
                child: (comment.author.avatarUrl == null)
                    ? const Icon(Icons.person, color: Colors.grey)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: bubbleColor, // Nền động
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => onNavigateToProfile(comment.author.id),
                          child: Text(
                            comment.author.displayName,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                                color: nameColor // Tên động
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),

                        // Truyền isDark vào hàm xử lý nội dung
                        _buildRichContent(comment.content, isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: Row(
                      children: [
                        Text(
                          timeago.format(DateTime.parse(comment.createdAt), locale: 'vi'),
                          style: TextStyle(color: timeColor, fontSize: 12.5),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Thích',
                          style: TextStyle(color: actionTextColor, fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () => onReply(comment),
                          child: Text(
                            'Phản hồi',
                            style: TextStyle(color: actionTextColor, fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== HÀM XỬ LÝ TEXT: Tô màu @Username =====
  Widget _buildRichContent(String content, bool isDark) {
    final RegExp regex = RegExp(r'^(@[^\s]+)\s');
    final match = regex.firstMatch(content);

    // Màu nội dung chính
    final contentColor = isDark ? Colors.white : Colors.black;

    if (match != null) {
      final usernameTag = match.group(1)!;
      final restOfContent = content.substring(match.end);

      return RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 14.5, height: 1.35, color: contentColor),
          children: [
            TextSpan(
              text: '$usernameTag ',
              style: TextStyle(
                color: Colors.blue[700], // Tag vẫn giữ màu xanh
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(text: restOfContent),
          ],
        ),
      );
    }

    return Text(
      content,
      style: TextStyle(fontSize: 14.5, height: 1.35, color: contentColor),
    );
  }
}
