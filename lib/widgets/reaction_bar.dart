// Dán toàn bộ code này vào file: lib/widgets/reaction_bar.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_reaction_button/flutter_reaction_button.dart';

import '../models/reaction_model.dart';
// import '../models/user_model.dart'; // Không cần thiết ở đây nếu đã dùng AuthService
import '../services/auth_service.dart';
import '../services/post_service.dart';

class ReactionBar extends StatefulWidget {
  final String targetId;
  final String targetType;

  final ReactionModel? currentUserReaction;
  final Function(ReactionModel?) onReactionChanged;
  final VoidCallback? onCommentButtonPressed;

  const ReactionBar({
    super.key,
    required this.targetId,
    required this.targetType,
    this.currentUserReaction,
    required this.onReactionChanged,
    this.onCommentButtonPressed,
  });

  @override
  State<ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends State<ReactionBar> {
  late final List<Reaction<String>> _reactions;

  @override
  void initState() {
    super.initState();
    _reactions = [
      _buildReactionButtonFromLibrary('like', 'Thích'),
      _buildReactionButtonFromLibrary('love', 'Yêu thích'),
      _buildReactionButtonFromLibrary('haha', 'Haha'),
      _buildReactionButtonFromLibrary('sad', 'Buồn'),
      _buildReactionButtonFromLibrary('wow', 'Wow'),
      _buildReactionButtonFromLibrary('angry', 'Giận dữ'),
    ];
  }

  Reaction<String> _buildReactionButtonFromLibrary(String value, String title) {
    return Reaction<String>(
      value: value,
      icon: Tooltip(
        message: title,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          child: Image.asset('assets/images/reactions/$value.gif', height: 40, width: 40),
        ),
      ),
    );
  }

  ({Widget icon, Color color, String text}) _getReactionDetails(String? type) {
    switch (type) {
      case 'like': return (icon: Image.asset('assets/images/reactions/like.gif', width: 22, height: 22), color: const Color(0xFF0561F2), text: 'Thích');
      case 'love': return (icon: Image.asset('assets/images/reactions/love.gif', width: 22, height: 22), color: const Color(0xFFF33E58), text: 'Yêu thích');
      case 'haha': return (icon: Image.asset('assets/images/reactions/haha.gif', width: 22, height: 22), color: const Color(0xFFF7B125), text: 'Haha');
      case 'sad': return (icon: Image.asset('assets/images/reactions/sad.gif', width: 22, height: 22), color: const Color(0xFFF7B125), text: 'Buồn');
      case 'wow': return (icon: Image.asset('assets/images/reactions/wow.gif', width: 22, height: 22), color: const Color(0xFFF7B125), text: 'Wow');
      case 'angry': return (icon: Image.asset('assets/images/reactions/angry.gif', width: 22, height: 22), color: const Color(0xFFE9710F), text: 'Giận dữ');
      default: return (icon: const Icon(CupertinoIcons.hand_thumbsup, color: Colors.grey, size: 22), color: Colors.grey.shade600, text: 'Thích');
    }
  }

  Future<void> _handleReaction(String? reactionType) async {
    final currentUser = Provider.of<AuthService>(context, listen: false).user;
    if (currentUser == null) return;

    // Logic xác định reaction mới:
    // Thư viện trả về reactionType mà user vừa chọn.
    // Nếu user chọn lại cái cũ -> Thư viện vẫn trả về cái đó, ta cần tự kiểm tra để hủy.
    // TUY NHIÊN: Thư viện flutter_reaction_button có thuộc tính `toggle: true` đã xử lý việc chọn lại để hủy rồi.
    // Khi hủy, nó sẽ trả về null (hoặc không gọi callback, tùy phiên bản).

    // Ở đây ta nhận reactionType trực tiếp từ thư viện
    // Nếu reactionType null nghĩa là đã hủy chọn

    String? finalReactionType = reactionType;

    // Kiểm tra thủ công: Nếu bấm lại nút cũ thì coi như hủy (nếu thư viện không tự làm)
    if (widget.currentUserReaction?.type == reactionType) {
      // finalReactionType = null; // Thư viện này xử lý toggle khá tốt, ta cứ để nó quyết định trước
    }

    // Cập nhật UI Optimistic
    ReactionModel? newReactionForParent;
    if (finalReactionType != null) {
      newReactionForParent = ReactionModel(user: currentUser, type: finalReactionType);
    }
    widget.onReactionChanged(newReactionForParent);

    // Gọi API
    final postService = Provider.of<PostService>(context, listen: false);
    try {
      if (widget.targetType == 'post') {
        await postService.reactToPost(widget.targetId, finalReactionType);
      } else if (widget.targetType == 'comment') {
        await postService.reactToComment(widget.targetId, finalReactionType);
      }
    } catch (e) {
      debugPrint("Lỗi API reaction: $e");
      // Rollback nếu cần thiết (optional)
    }
  }

  @override
  Widget build(BuildContext context) {
    final reactionDetails = _getReactionDetails(widget.currentUserReaction?.type);

    // Widget con hiển thị icon và text
    final actionButtonChild = _buildActionButtonContent(
      icon: reactionDetails.icon,
      label: reactionDetails.text,
      labelColor: reactionDetails.color,
    );

    if (widget.targetType == 'comment') {
      return ReactionButton<String>(
        onReactionChanged: (Reaction<String>? reaction) {
          // Khi chọn reaction từ menu hoặc bấm toggle
          _handleReaction(reaction?.value);
        },
        reactions: _reactions,
        itemSize: const Size(45, 45),
        // toggle: true mặc định giúp bấm 1 cái là like, bấm lại là unlike
        // isChecked xác định trạng thái ban đầu
        isChecked: widget.currentUserReaction != null,
        selectedReaction: widget.currentUserReaction != null
            ? _reactions.firstWhere(
                (r) => r.value == widget.currentUserReaction!.type,
            orElse: () => _reactions[0]
        )
            : null,
        // child: Hiển thị khi chưa chọn gì hoặc trạng thái mặc định
        child: actionButtonChild,
      );
    }

    // Layout cho Post
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Expanded(
          child: ReactionButton<String>(
            onReactionChanged: (Reaction<String>? reaction) {
              debugPrint("Reaction changed: ${reaction?.value}");
              _handleReaction(reaction?.value);
            },
            reactions: _reactions,
            itemSize: const Size(50, 50),
            // Quan trọng: isChecked để thư viện biết đang ở trạng thái active hay không
            isChecked: widget.currentUserReaction != null,
            selectedReaction: widget.currentUserReaction != null
                ? _reactions.firstWhere(
                    (r) => r.value == widget.currentUserReaction!.type,
                orElse: () => _reactions[0]
            )
                : null,
            boxColor: Colors.white,
            boxElevation: 5,
            boxRadius: 20,
            // boxDuration: const Duration(milliseconds: 200),
            itemScale: .3,

            // SỬA LỖI CHÍNH Ở ĐÂY:
            // Không bọc actionButtonChild bằng InkWell có onTap riêng nữa.
            // Để ReactionButton tự xử lý sự kiện tap (mặc định tap là like, long-press là hiện menu).
            child: Container( // Dùng Container để hứng touch event của thư viện
              color: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  reactionDetails.icon,
                  const SizedBox(width: 8),
                  Text(
                    reactionDetails.text,
                    style: TextStyle(
                        color: reactionDetails.color,
                        fontWeight: FontWeight.w600,
                        fontSize: 15
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (widget.onCommentButtonPressed != null)
          Expanded(
            child: _buildActionButton(
              icon: Icon(CupertinoIcons.chat_bubble, color: Colors.grey.shade600, size: 22),
              label: 'Bình luận',
              labelColor: Colors.grey.shade600,
              onTap: () {
                widget.onCommentButtonPressed?.call();
              },
            ),
          ),
        Expanded(
          child: _buildActionButton(
            icon: Icon(CupertinoIcons.arrow_turn_up_right, color: Colors.grey.shade600, size: 22),
            label: 'Chia sẻ',
            labelColor: Colors.grey.shade600,
            onTap: () {},
          ),
        ),
      ],
    );
  }

  // Hàm helper chỉ để build nội dung (Icon + Text), không xử lý sự kiện
  Widget _buildActionButtonContent({
    required Widget icon,
    required String label,
    required Color labelColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0), // Padding cho đẹp
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 8),
          Text(
              label,
              style: TextStyle(color: labelColor, fontWeight: FontWeight.w600, fontSize: 15)
          ),
        ],
      ),
    );
  }

  // Hàm cũ giữ lại cho các nút Bình luận / Chia sẻ (vẫn cần onTap)
  Widget _buildActionButton({
    required Widget icon,
    required String label,
    required Color labelColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: labelColor, fontWeight: FontWeight.w600, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
