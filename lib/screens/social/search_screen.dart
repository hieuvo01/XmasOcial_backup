import 'dart:async'; // Để dùng Timer (debounce)
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/social_search_service.dart';
import '../../widgets/post_card.dart';
import 'user_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce; // Timer để delay việc gọi API khi gõ

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<SocialSearchService>(context, listen: false).clearResults();
      }
    });
    super.dispose();
  }

  // Hàm xử lý khi người dùng gõ phím
  void _onSearchChanged(String query, SocialSearchService searchService) {
    // Hủy timer cũ nếu người dùng gõ tiếp
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Tạo timer mới: Chỉ gọi API sau khi người dùng dừng gõ 500ms
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isNotEmpty) {
        searchService.searchUsersAndPosts(query);
      } else {
        searchService.clearResults();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Lấy theme dark/light
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Màu nền Scaffold: Xám nhẹ (Light) hoặc Đen/Xám đậm (Dark)
    final scaffoldBgColor = isDark ? CupertinoColors.black : CupertinoColors.systemGroupedBackground;

    // Màu nền thanh Navigation & Container tìm kiếm
    final barBgColor = isDark
        ? CupertinoColors.black.withOpacity(0.9)
        : CupertinoColors.white.withOpacity(0.9);

    // Màu nền ô input tìm kiếm
    final searchInputBg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFEFEFF4);

    // Màu chữ trong ô tìm kiếm
    final searchInputText = isDark ? Colors.white : Colors.black87;

    // Màu placeholder (chữ mờ)
    final placeholderColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Consumer<SocialSearchService>(
      builder: (context, searchService, child) {
        return CupertinoPageScaffold(
          backgroundColor: scaffoldBgColor,
          navigationBar: CupertinoNavigationBar(
            middle: Text('Tìm kiếm', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            backgroundColor: barBgColor,
            border: null, // Bỏ đường kẻ mặc định cho sạch
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Thanh tìm kiếm
                Container(
                  color: isDark ? Colors.black : CupertinoColors.white, // Nền container chứa ô search
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: CupertinoSearchTextField(
                    controller: _searchController,
                    placeholder: 'Tìm người dùng, bài viết...',
                    style: TextStyle(color: searchInputText),
                    backgroundColor: searchInputBg, // Màu nền ô nhập liệu động
                    placeholderStyle: TextStyle(color: placeholderColor),
                    itemColor: placeholderColor ?? CupertinoColors.placeholderText, // Màu icon kính lúp

                    // Gọi hàm tìm kiếm ngay khi gõ (Auto-complete)
                    onChanged: (value) => _onSearchChanged(value, searchService),
                    onSubmitted: (value) {
                      _debounce?.cancel();
                      searchService.searchUsersAndPosts(value);
                    },
                  ),
                ),

                // Phần hiển thị kết quả
                Expanded(
                  child: searchService.isLoading
                      ? const Center(child: CupertinoActivityIndicator(radius: 14))
                      : _buildResultsList(searchService, isDark),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultsList(SocialSearchService searchService, bool isDark) {
    // Màu chữ chính/phụ động
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final iconColor = isDark ? Colors.grey[600] : Colors.grey[300];

    // Màu nền block kết quả (ListTile container)
    final blockBgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    // ---- Trạng thái ban đầu (chưa gõ gì) ----
    if (_searchController.text.trim().isEmpty) {
      return Center(
        child: Material(
          color: Colors.transparent, // Nền trong suốt
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.search, size: 80, color: iconColor),
              const SizedBox(height: 16),
              Text(
                'Nhập tên hoặc nội dung để tìm kiếm',
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Helvetica', // Hoặc font mặc định đẹp của máy
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ---- Trạng thái có lỗi ----
    if (searchService.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            'Lỗi: ${searchService.error!}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    // ---- Trạng thái không tìm thấy kết quả ----
    if (searchService.users.isEmpty && searchService.posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.doc_text_search, size: 60, color: iconColor),
            const SizedBox(height: 10),
            Text(
              'Không tìm thấy kết quả nào.',
              style: TextStyle(color: secondaryTextColor, fontSize: 16),
            ),
          ],
        ),
      );
    }

    // ---- Trạng thái có kết quả (Đã đẹp rồi, giữ nguyên) ----
    return Material(
      color: Colors.transparent, // Nền trong suốt để hiện màu nền của Scaffold
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // --- Danh sách người dùng ---
          if (searchService.users.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
              child: Text('MỌI NGƯỜI',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: secondaryTextColor)),
            ),
            Container(
              color: blockBgColor, // Nền động cho block kết quả
              child: Column(
                children: searchService.users.map((user) {
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                          backgroundImage: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                              ? NetworkImage(user.avatarUrl!)
                              : null,
                          child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                              ? Icon(CupertinoIcons.person_fill, color: isDark ? Colors.grey[500] : Colors.grey)
                              : null,
                        ),
                        title: Text(
                          user.displayName,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: primaryTextColor),
                        ),
                        subtitle: Text(
                          '@${user.username}',
                          style: TextStyle(color: secondaryTextColor, fontSize: 14),
                        ),
                        trailing: Icon(CupertinoIcons.chevron_right, size: 16, color: isDark ? Colors.grey[600] : Colors.grey),
                        onTap: () {
                          // Ẩn bàn phím khi chuyển trang
                          FocusScope.of(context).unfocus();
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (ctx) => UserProfileScreen(userId: user.id),
                          ));
                        },
                      ),
                      // Đường kẻ mờ giữa các item, trừ item cuối
                      if (user != searchService.users.last)
                        Divider(height: 1, indent: 70, thickness: 0.5, color: isDark ? Colors.grey[800] : Colors.grey[300]),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],

          // --- Danh sách bài viết ---
          if (searchService.posts.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
              child: Text('BÀI VIẾT',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: secondaryTextColor)),
            ),
            // Hiển thị post card trực tiếp
            // Lưu ý: Widget PostCard của bro cần phải tự support dark mode bên trong nó nhé
            ...searchService.posts.map((post) => Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: PostCard(post: post),
            )),
          ],

          // Khoảng trống dưới cùng để không bị che bởi bàn phím ảo (nếu có)
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}
