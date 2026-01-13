// Dán toàn bộ code này vào file: lib/screens/post_detail_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/post_model.dart';
import '../../models/comment_model.dart';
import '../../models/reaction_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/post_service.dart';
import '../../screens/social/user_profile_screen.dart';
import '../../widgets/comment_section.dart';
import '../../widgets/post_card.dart';
import '../../widgets/comment_input_bar.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Post? _currentPost;
  bool _isLoading = true;
  String? _error;

  String? _replyingToCommentId;
  String? _replyingToUsername;

  @override
  void initState() {
    super.initState();
    _fetchPostDetails();
  }

  Future<void> _fetchPostDetails() async {
    if (_currentPost == null) {
      if (mounted) setState(() { _isLoading = true; _error = null; });
    }

    try {
      final postData = await Provider.of<PostService>(context, listen: false)
          .getPostById(widget.postId);
      if (mounted) {
        setState(() {
          _currentPost = postData;
          _isLoading = false;
        });
      }
    } catch (e, stacktrace) {
      print('Lỗi khi fetch post details: $e\n$stacktrace');
      if (mounted) {
        setState(() {
          _error = 'Không thể tải dữ liệu bài viết.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handlePostReaction(Post post, ReactionModel? newReaction) async {
    final postService = Provider.of<PostService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.user;
    if (currentUser == null) return;

    ReactionModel? oldReaction;
    try {
      oldReaction = post.reactions.firstWhere((r) => r.user.id == currentUser.id);
    } catch (e) {
      oldReaction = null;
    }

    String? reactionType = newReaction?.type;

    if (oldReaction != null && oldReaction.type == reactionType) {
      reactionType = null;
    }

    if (reactionType == null && oldReaction == null) return;

    final finalReactionType = reactionType ?? oldReaction?.type;
    if (finalReactionType == null) return;

    setState(() {
      final reactionIndex = _currentPost!.reactions.indexWhere((r) => r.user.id == currentUser.id);
      if (reactionIndex != -1) {
        if (_currentPost!.reactions[reactionIndex].type == finalReactionType) {
          _currentPost!.reactions.removeAt(reactionIndex);
        } else {
          _currentPost!.reactions[reactionIndex] = _currentPost!.reactions[reactionIndex].copyWith(type: finalReactionType);
        }
      } else {
        _currentPost!.reactions.add(
            ReactionModel(user: currentUser, type: finalReactionType));
      }
    });

    try {
      final updatedPostFromServer = await postService.reactToPost(post.id, reactionType);
      if (mounted) {
        setState(() {
          _currentPost = updatedPostFromServer;
        });
      }
    } catch (e) {
      print("Lỗi khi react, đang fetch lại post: $e");
      _fetchPostDetails();
    }
  }

  void _onCommentPosted(Post updatedPost) {
    if (mounted) {
      setState(() {
        _currentPost = updatedPost;
      });
    }
    _cancelReply();
  }

  void _setReplyTo(Comment comment) {
    setState(() {
      _replyingToCommentId = comment.id;
      _replyingToUsername = comment.author.username;
    });
  }

  void _cancelReply() {
    if (mounted) {
      setState(() {
        _replyingToCommentId = null;
        _replyingToUsername = null;
        FocusScope.of(context).unfocus();
      });
    }
  }

  void _onCommentDeleted() {
    _fetchPostDetails();
  }

  void _navigateToUserProfile(String userId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => UserProfileScreen(userId: userId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appBarTitle =
    _currentPost != null ? 'Bài viết của ${_currentPost!.author.displayName}' : 'Đang tải...';

    // --- DARK MODE COLORS ---
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFF0F2F5);
    final appBarBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryText = isDark ? Colors.white : Colors.black87;
    final iconColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 1,
        // Giữ iconTheme để nút back tự động đổi màu theo AppBar nếu cần
        iconTheme: IconThemeData(color: iconColor),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: iconColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          appBarTitle,
          style: TextStyle(color: primaryText, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
                onTap: () => _cancelReply(),
                child: _buildBody(isDark)
            ),
          ),
          if (_currentPost != null)
            CommentInputBar(
              onCommentPosted: (updatedPost) => _onCommentPosted(updatedPost),
              postId: widget.postId,
              replyingToCommentId: _replyingToCommentId,
              replyingToUsername: _replyingToUsername,
              onCancelReply: _cancelReply,
            )
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    // Màu divider ngăn cách Post và Comment
    final dividerColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEBEEF0);
    // Màu chữ lỗi
    final errorColor = isDark ? Colors.grey[400] : Colors.black87;

    if (_isLoading) {
      return Center(
          child: CupertinoActivityIndicator(
              color: isDark ? Colors.white : null // Indicator màu trắng nếu nền tối
          )
      );
    }

    if (_error != null || _currentPost == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _error ?? 'Đã xảy ra lỗi không xác định.',
            textAlign: TextAlign.center,
            style: TextStyle(color: errorColor),
          ),
        ),
      );
    }

    final post = _currentPost!;
    final currentUser = Provider.of<AuthService>(context, listen: false).user;

    return RefreshIndicator(
      onRefresh: _fetchPostDetails,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      color: Colors.blue,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          PostCard(
            post: post,
            isDetailView: true,
            currentUser: currentUser,
            onPostUpdated: _handlePostReaction,
          ),
          Divider(thickness: 8, color: dividerColor),
          CommentSection(
            postId: post.id,
            postAuthorId: post.author.id,
            comments: post.comments,
            onReply: _setReplyTo,
            onNavigateToProfile: _navigateToUserProfile,
            onCommentDeleted: _onCommentDeleted,
          ),
        ],
      ),
    );
  }
}
