// File: lib/screens/social/tabs/friends_tab.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/user_model.dart';
import '../../../services/user_service.dart';
import '../../../services/navigation_service.dart';
import '../user_profile_screen.dart';

class FriendsTab extends StatefulWidget {
  final ScrollController scrollController;
  const FriendsTab({super.key, required this.scrollController});

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  late Future<List<UserModel>> _suggestionsFuture;

  @override
  void initState() {
    super.initState();
    _fetchSuggestions();
  }

  void _fetchSuggestions() {
    _suggestionsFuture = Provider.of<UserService>(context, listen: false).fetchUserSuggestions();
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _fetchSuggestions();
    });
  }

  void _addFriend(String userId) async {
    try {
      await Provider.of<UserService>(context, listen: false).sendFriendRequest(userId);
      _handleRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi lời mời kết bạn!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  void _navigateToUserProfile(String userId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(userId: userId),
      ),
    );
  }

  void _backToFeed() {
    final navService = Provider.of<NavigationService>(context, listen: false);
    if (navService.pageController != null) {
      navService.pageController!.jumpToPage(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lấy màu từ Theme
    final scaffoldBgColor = Theme.of(context).scaffoldBackgroundColor;
    final appBarBgColor = Theme.of(context).appBarTheme.backgroundColor;
    final iconColor = Theme.of(context).appBarTheme.iconTheme?.color ?? Colors.black;
    final titleColor = Theme.of(context).appBarTheme.titleTextStyle?.color ?? Colors.black;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Scaffold(
      backgroundColor: scaffoldBgColor, // 👇 SỬA: Màu nền động
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: iconColor), // 👇 SỬA: Màu icon động
          onPressed: _backToFeed,
        ),
        title: Text(
          'Người bạn có thể biết',
          style: TextStyle(color: titleColor, fontSize: 24, fontWeight: FontWeight.bold), // 👇 SỬA: Màu chữ động
        ),
        backgroundColor: appBarBgColor, // 👇 SỬA: Màu nền AppBar động
        elevation: 0.5,
        centerTitle: false,
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 300) {
            _backToFeed();
          }
        },
        child: FutureBuilder<List<UserModel>>(
          future: _suggestionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CupertinoActivityIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Lỗi tải dữ liệu: ${snapshot.error}', style: TextStyle(color: textColor)));
            }
            final suggestions = snapshot.data ?? [];
            if (suggestions.isEmpty) {
              return RefreshIndicator(
                onRefresh: _handleRefresh,
                child: Stack(
                  children: [
                    ListView(), // Cần ListView để kéo xuống refresh được
                    Center(child: Text('Không có gợi ý nào.', style: TextStyle(color: textColor))),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _handleRefresh,
              color: CupertinoColors.activeBlue, // Thêm màu cho refresh spinner
              child: ListView.builder(
                controller: widget.scrollController,
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 12.0, bottom: 100.0),
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final user = suggestions[index];
                  return _buildSuggestionTile(user, textColor);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSuggestionTile(UserModel user, Color? textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _navigateToUserProfile(user.id),
              child: Container(
                color: Colors.transparent,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                      child: user.avatarUrl == null ? const Icon(CupertinoIcons.person_fill, size: 35) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        user.displayName,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor), // 👇 SỬA: Màu chữ tên
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          CupertinoButton.filled(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onPressed: () => _addFriend(user.id),
            child: const Text('Thêm bạn', style: TextStyle(fontSize: 14, color: Colors.white)), // Chữ nút bấm luôn trắng
          )
        ],
      ),
    );
  }
}
