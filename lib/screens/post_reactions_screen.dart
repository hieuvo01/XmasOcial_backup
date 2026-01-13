// Dán toàn bộ code này vào file mới: lib/screens/post_reactions_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/reaction_model.dart';
import '../models/user_model.dart';
import '../services/post_service.dart';
import 'social/user_profile_screen.dart'; // Import màn hình profile

class PostReactionsScreen extends StatefulWidget {
  final String postId;

  const PostReactionsScreen({super.key, required this.postId});

  @override
  State<PostReactionsScreen> createState() => _PostReactionsScreenState();
}

class _PostReactionsScreenState extends State<PostReactionsScreen> {
  late Future<List<ReactionModel>> _reactionsFuture;

  @override
  void initState() {
    super.initState();
    // Gọi hàm fetch dữ liệu ngay khi widget được tạo
    _reactionsFuture = _fetchReactions();
  }

  // Hàm gọi service để lấy dữ liệu
  Future<List<ReactionModel>> _fetchReactions() {
    // Chúng ta sẽ tạo hàm getPostReactions trong PostService ở bước tiếp theo
    return Provider.of<PostService>(context, listen: false)
        .getPostReactions(widget.postId);
  }

  // Hàm điều hướng đến trang cá nhân của người dùng
  void _navigateToUserProfile(String userId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => UserProfileScreen(userId: userId)),
    );
  }


// Hàm để lấy icon tương ứng với loại reaction
  Widget _getReactionIcon(String type) {
    String imagePath;
    switch (type) {
      case 'like':
        imagePath = 'assets/images/reactions/like.gif';
        break;
      case 'love':
        imagePath = 'assets/images/reactions/love.gif';
        break;
      case 'haha':
        imagePath = 'assets/images/reactions/haha.gif';
        break;
      case 'sad':
        imagePath = 'assets/images/reactions/sad.gif';
        break;
      case 'wow':
        imagePath = 'assets/images/reactions/wow.gif';
        break;
      case 'angry':
        imagePath = 'assets/images/reactions/angry.gif';
        break;
      default:
      // Mặc định vẫn là like nếu có loại reaction lạ
        imagePath = 'assets/images/reactions/like.gif';
    }
    // Trả về một Widget Image.asset với kích thước phù hợp
    return Image.asset(imagePath, width: 28, height: 28);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Những người đã bày tỏ cảm xúc'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<List<ReactionModel>>(
        future: _reactionsFuture,
        builder: (context, snapshot) {
          // Trường hợp đang tải dữ liệu
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CupertinoActivityIndicator());
          }

          // Trường hợp có lỗi
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi tải dữ liệu: ${snapshot.error}'));
          }

          // Trường hợp không có dữ liệu hoặc danh sách rỗng
          final reactions = snapshot.data;
          if (reactions == null || reactions.isEmpty) {
            return const Center(child: Text('Chưa có ai bày tỏ cảm xúc.'));
          }

          // Trường hợp có dữ liệu, hiển thị ListView
          return ListView.builder(
            itemCount: reactions.length,
            itemBuilder: (context, index) {
              final reaction = reactions[index];
              final user = reaction.user;

              return ListTile(
                onTap: () => _navigateToUserProfile(user.id),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundImage: user.avatarUrl != null
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: user.avatarUrl == null
                      ? const Icon(Icons.person, size: 24)
                      : null,
                ),
                title: Text(
                  user.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('@${user.username}'),
                trailing: _getReactionIcon(reaction.type), // Hiển thị icon cảm xúc
              );
            },
          );
        },
      ),
    );
  }
}
