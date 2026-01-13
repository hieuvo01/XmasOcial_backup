// Dán toàn bộ code này vào file: lib/widgets/comment_input_bar.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/post_service.dart';
import '../models/post_model.dart';

class CommentInputBar extends StatefulWidget {
  final String postId;
  final void Function(Post) onCommentPosted;
  final String? replyingToCommentId;
  final String? replyingToUsername;
  final VoidCallback onCancelReply;

  const CommentInputBar({
    Key? key,
    required this.postId,
    required this.onCommentPosted,
    this.replyingToCommentId,
    this.replyingToUsername,
    required this.onCancelReply,
  }) : super(key: key);

  @override
  _CommentInputBarState createState() => _CommentInputBarState();
}

class _CommentInputBarState extends State<CommentInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ===== LOGIC TỰ ĐỘNG ĐIỀN @USERNAME VÀO Ô NHẬP =====
  @override
  void didUpdateWidget(covariant CommentInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.replyingToUsername != null &&
        widget.replyingToUsername != oldWidget.replyingToUsername) {

      final tagText = '@${widget.replyingToUsername} ';
      _controller.text = tagText;

      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: tagText.length),
      );

      FocusScope.of(context).requestFocus(_focusNode);
    }
  }

  Future<void> _submitComment() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;

    setState(() { _isSending = true; });

    try {
      final postService = Provider.of<PostService>(context, listen: false);
      final updatedPost = await postService.createComment(
        widget.postId,
        content,
        parentCommentId: widget.replyingToCommentId,
      );

      // 👇 CHỈ GIỮ LẠI ĐOẠN CODE TRONG IF NÀY 👇
      if (updatedPost != null) {
        widget.onCommentPosted(updatedPost);

        // Di chuyển việc clear input vào trong này cho chắc chắn thành công mới xóa
        _controller.clear();
        widget.onCancelReply();
        _focusNode.unfocus();
      }
      // 👆 ĐÃ XÓA ĐOẠN CODE THỪA Ở DƯỚI GÂY LỖI 👆

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString().replaceAll("Exception: ", "")}')),
      );
    } finally {
      if (mounted) {
        setState(() { _isSending = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- DARK MODE COLORS ---
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerBg = isDark ? const Color(0xFF1E1E1E) : Theme.of(context).cardColor;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final inputFillColor = isDark ? const Color(0xFF3A3B3C) : Colors.grey[200];
    final textColor = isDark ? Colors.white : Colors.black;
    final hintColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: containerBg,
        border: Border(top: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.replyingToUsername != null)
            Padding(
              padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
              child: Row(
                children: [
                  Text(
                    'Đang trả lời ${widget.replyingToUsername}...',
                    style: TextStyle(color: hintColor, fontSize: 13),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      _controller.clear();
                      widget.onCancelReply();
                    },
                    child: Icon(Icons.close, size: 16, color: hintColor),
                  )
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: TextStyle(color: textColor), // Màu chữ khi gõ
                  decoration: InputDecoration(
                    hintText: 'Viết bình luận...',
                    hintStyle: TextStyle(color: hintColor),
                    filled: true,
                    fillColor: inputFillColor, // Màu nền ô input động
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _submitComment(),
                ),
              ),
              const SizedBox(width: 8),
              _isSending
                  ? const Padding(
                padding: EdgeInsets.all(8.0),
                child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
              )
                  : IconButton(
                icon: const Icon(Icons.send),
                onPressed: _submitComment,
                color: Colors.blueAccent, // Luôn để màu xanh cho nổi
              ),
            ],
          ),
        ],
      ),
    );
  }
}
