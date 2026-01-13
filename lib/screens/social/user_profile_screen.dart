// File: lib/screens/social/user_profile_screen.dart

import 'dart:io'; // <--- MỚI: Để xử lý File ảnh
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_maps/screens/social/create_story_screen.dart';
import 'package:image_picker/image_picker.dart'; // <--- MỚI: Chọn ảnh từ thư viện
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../services/message_service.dart';
import '../../widgets/avatar_with_story_border.dart';
import '../../widgets/full_screen_image_viewer.dart'; // <--- MỚI: Xem ảnh full màn hình
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/post_service.dart';
import '../../services/user_service.dart';
import '../../widgets/post_card.dart';
import '../../widgets/friend_grid_item.dart';
import '../settings/edit_profile_screen.dart';
import 'chat_screen.dart';
import 'create_post_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final ScrollController? scrollController;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.scrollController,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  UserModel? _user;
  late Future<List<Post>> _postsFuture;
  bool _isLoading = true;
  late TabController _tabController;
  late ScrollController _internalScrollController;
  final ImagePicker _picker = ImagePicker(); // <--- MỚI: Khởi tạo ImagePicker

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _internalScrollController = widget.scrollController ?? ScrollController();
    _initData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (widget.scrollController == null) {
      _internalScrollController.dispose();
    }
    super.dispose();
  }

  void _initData() {
    _postsFuture = Provider.of<PostService>(context, listen: false)
        .fetchPostsByUser(widget.userId);
    _fetchUserOnly(showLoading: true);
  }

  Future<void> _fetchUserOnly({bool showLoading = false}) async {
    if (showLoading) setState(() => _isLoading = true);

    try {
      final fetchedUser = await Provider.of<UserService>(context, listen: false)
          .getUserById(widget.userId);
      if (mounted) {
        setState(() {
          _user = fetchedUser;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Lỗi tải thông tin: $e', isError: true);
      }
    }
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _postsFuture = Provider.of<PostService>(context, listen: false)
          .fetchPostsByUser(widget.userId);
    });
    await _fetchUserOnly();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: const Duration(seconds: 1)),
    );
  }

  // 👇👇👇 LOGIC XỬ LÝ AVATAR (MỚI) 👇👇👇

  // 1. Hàm xử lý khi nhấn vào Avatar
  void _onAvatarTap() {
    if (_user == null) return;

    final currentUser = Provider.of<AuthService>(context, listen: false).user;
    final isMe = currentUser?.id == _user!.id;

    if (isMe) {
      // Nếu là chính mình -> Hiện menu chọn (Xem / Cập nhật)
      _showAvatarOptions();
    } else {
      // Nếu là người khác -> Chỉ xem ảnh
      _viewAvatarFullScreen();
    }
  }

  // 2. Hiển thị Menu lựa chọn
  void _showAvatarOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text("Ảnh đại diện"),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _viewAvatarFullScreen();
            },
            child: const Text("Xem ảnh đại diện"),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _pickAndUpdateAvatar();
            },
            child: const Text("Cập nhật ảnh đại diện"),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text("Hủy"),
        ),
      ),
    );
  }

  // 3. Xem ảnh Full màn hình
  void _viewAvatarFullScreen() {
    if (_user?.avatarUrl == null || _user!.avatarUrl!.isEmpty) {
      _showSnackBar("Người dùng chưa có ảnh đại diện", isError: true);
      return;
    }

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => FullScreenImageViewer(
          // 🔥 SỬA TẠI ĐÂY: Biến url thành List bằng cách bọc trong dấu []
          imageUrls: [_user!.avatarUrl!],
          // 🔥 THÊM: Vị trí bắt đầu là 0
          startIndex: 0,
          tag: 'profile_avatar_${_user!.id}',
        ),
      ),
    );
  }

  // 4. Chọn ảnh từ máy và cập nhật lên Server
  Future<void> _pickAndUpdateAvatar() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      // Hiện loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CupertinoActivityIndicator(radius: 15, color: Colors.white)),
      );

      // Gọi Service upload
      await Provider.of<UserService>(context, listen: false).updateAvatar(File(pickedFile.path));

      // Đóng loading
      if (mounted) Navigator.pop(context);

      _showSnackBar("Cập nhật ảnh đại diện thành công!");
      _fetchUserOnly(); // Tải lại thông tin user để cập nhật UI

    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Đóng loading nếu lỗi
        _showSnackBar("Lỗi cập nhật ảnh: $e", isError: true);
      }
    }
  }
  // 👆👆👆 KẾT THÚC LOGIC AVATAR 👆👆👆


  void _showCreateOptions(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Tạo nội dung mới', style: TextStyle(fontSize: 16)),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.pencil_outline, color: CupertinoColors.activeBlue),
                SizedBox(width: 8),
                Text('Tạo bài viết'),
              ],
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => CreatePostScreen(
                    onPostCreated: () { _handleRefresh(); },
                  ),
                ),
              );
            },
          ),
          CupertinoActionSheetAction(
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.add_circled, color: CupertinoColors.activeBlue),
                SizedBox(width: 8),
                Text('Tạo tin'),
              ],
            ),
            onPressed: () {
              // 1. Đóng ActionSheet trước
              Navigator.pop(context);

              // 2. Mở màn hình tạo tin (Story) với hiệu ứng trượt iOS
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (context) => CreateStoryScreen(
                    // Sau khi tạo tin xong sẽ tự động làm mới profile
                    onPostCreated: () => _handleRefresh(),
                  ),
                ),
              );
            },

          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
      ),
    );
  }

  void _showDetailInfo() {
    if (_user == null) return;
    String joinDate = "Chưa cập nhật";

    if (_user!.createdAt != null) {
      try {
        joinDate = "Tháng ${DateFormat('MM, yyyy').format(_user!.createdAt!)}";
      } catch (e) {
        joinDate = "${_user!.createdAt!.month}/${_user!.createdAt!.year}";
      }
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) {
        final textColor = Theme.of(context).textTheme.bodyLarge?.color;

        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text("Giới thiệu", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 20),
              if (_user!.bio != null && _user!.bio!.isNotEmpty)
                _buildDetailRow(Icons.info_outline, "Tiểu sử", _user!.bio!, textColor),
              _buildDetailRow(Icons.alternate_email, "Username", "@${_user!.username}", textColor),
              if (_user!.email != null)
                _buildDetailRow(Icons.email_outlined, "Email", _user!.email!, textColor),
              _buildDetailRow(Icons.calendar_month_outlined, "Đã tham gia", joinDate, textColor),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: Colors.grey[200],
                  child: const Text("Đóng", style: TextStyle(color: Colors.black)),
                  onPressed: () => Navigator.pop(context),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color? textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFriendActionButton({
    required IconData icon, required String label, required VoidCallback onPressed, bool isPrimary = true,
  }) {
    final secondaryBtnColor = Theme.of(context).inputDecorationTheme.fillColor ?? Colors.grey[300];
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: isPrimary ? CupertinoColors.systemBlue : secondaryBtnColor,
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: isPrimary ? Colors.white : (Theme.of(context).iconTheme.color ?? Colors.black)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label, style: TextStyle(color: isPrimary ? Colors.white : textColor, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
          )
        ],
      ),
    );
  }

  Widget _buildOtherUserActions(BuildContext context) {
    final currentUserId = Provider.of<AuthService>(context, listen: false).user!.id;
    final userService = Provider.of<UserService>(context, listen: false);

    final messageButton = Expanded(
      child: _buildFriendActionButton(
        icon: CupertinoIcons.chat_bubble_text_fill,
        label: 'Nhắn tin',
        onPressed: () async {
          showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CupertinoActivityIndicator(radius: 15, color: Colors.white)));
          try {
            final msgService = Provider.of<MessageService>(context, listen: false);
            final conversationId = await msgService.getConversationId(_user!.id);
            if (context.mounted) Navigator.pop(context);

            if (conversationId != null) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(conversationId: conversationId, targetUser: _user!)));
            } else {
              _showSnackBar('Lỗi kết nối chat.', isError: true);
            }
          } catch (e) {
            if (context.mounted) Navigator.pop(context);
            _showSnackBar('Có lỗi xảy ra: $e', isError: true);
          }
        },
        isPrimary: false,
      ),
    );

    Widget mainActionButton;

    if (_user!.friends.any((friend) => friend.id == currentUserId)) {
      mainActionButton = Expanded(
        child: _buildFriendActionButton(
            icon: CupertinoIcons.person_crop_circle_fill_badge_xmark,
            label: 'Bạn bè',
            onPressed: () {
              showCupertinoDialog(
                  context: context,
                  builder: (ctx) => CupertinoAlertDialog(
                      title: Text('Hủy kết bạn với ${_user!.displayName}?'),
                      actions: [
                        CupertinoDialogAction(child: const Text('Không'), onPressed: () => Navigator.pop(ctx)),
                        CupertinoDialogAction(
                            isDestructiveAction: true,
                            child: const Text('Hủy kết bạn'),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              try {
                                await userService.unfriendUser(_user!.id);
                                _showSnackBar('Đã hủy kết bạn.');
                                _fetchUserOnly();
                              } catch (e) {
                                _showSnackBar(e.toString(), isError: true);
                              }
                            })
                      ]));
            }),
      );
    } else if (_user!.receivedFriendRequests.contains(currentUserId)) {
      mainActionButton = Expanded(
        child: _buildFriendActionButton(
            icon: CupertinoIcons.arrow_up_right_circle_fill,
            label: 'Đã gửi lời mời',
            onPressed: () async {
              try {
                await userService.rejectFriendRequest(_user!.id);
                _showSnackBar('Đã hủy lời mời.');
                _fetchUserOnly();
              } catch (e) {}
            },
            isPrimary: false),
      );
    } else if (_user!.sentFriendRequests.contains(currentUserId)) {
      return Row(children: [
        Expanded(
            child: _buildFriendActionButton(
                icon: CupertinoIcons.person_crop_circle_badge_checkmark,
                label: 'Xác nhận',
                onPressed: () async {
                  try {
                    await userService.acceptFriendRequest(_user!.id);
                    _showSnackBar('Kết bạn thành công!');
                    _fetchUserOnly();
                  } catch (e) {
                    _showSnackBar(e.toString(), isError: true);
                  }
                })),
        const SizedBox(width: 8),
        Expanded(
            child: _buildFriendActionButton(
                icon: CupertinoIcons.xmark_circle_fill,
                label: 'Xóa',
                onPressed: () async {
                  try {
                    await userService.rejectFriendRequest(_user!.id);
                    _showSnackBar('Đã xóa lời mời kết bạn.');
                    _fetchUserOnly();
                  } catch (e) {
                    _showSnackBar(e.toString(), isError: true);
                  }
                },
                isPrimary: false)),
      ]);
    } else {
      mainActionButton = Expanded(
        child: _buildFriendActionButton(
            icon: CupertinoIcons.person_add_solid,
            label: 'Thêm bạn bè',
            onPressed: () async {
              try {
                await userService.sendFriendRequest(_user!.id);
                _showSnackBar('Đã gửi lời mời kết bạn!');
                _fetchUserOnly();
              } catch (e) {
                _showSnackBar(e.toString(), isError: true);
              }
            }),
      );
    }

    return Row(children: [mainActionButton, const SizedBox(width: 8), messageButton]);
  }

  Widget _buildCurrentUserActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildFriendActionButton(
            icon: CupertinoIcons.add_circled_solid,
            label: 'Tạo',
            onPressed: () => _showCreateOptions(context),
            isPrimary: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildFriendActionButton(
            icon: CupertinoIcons.pencil,
            label: 'Chỉnh sửa',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EditProfileScreen(user: _user!)),
              );
              _fetchUserOnly();
            },
            isPrimary: false,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthService>(context, listen: false).user;
    final bool isCurrentUser = widget.userId == currentUser?.id;
    final bool canPop = ModalRoute.of(context)?.canPop ?? false;
    final bool showAppBar = !isCurrentUser || canPop;

    final scaffoldBgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final iconColor = Theme.of(context).iconTheme.color;
    final appBarBgColor = Theme.of(context).appBarTheme.backgroundColor;

    return Scaffold(
      backgroundColor: scaffoldBgColor,
      appBar: showAppBar
          ? AppBar(
        backgroundColor: appBarBgColor,
        elevation: 0.5,
        leading: canPop
            ? IconButton(icon: Icon(CupertinoIcons.back, color: iconColor), onPressed: () => Navigator.of(context).pop())
            : null,
        title: Text(_user?.displayName ?? '', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
      )
          : null,
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator(radius: 15))
          : _user == null
          ? Center(child: Text('Không thể tải thông tin người dùng.', style: TextStyle(color: textColor)))
          : RefreshIndicator(
        onRefresh: _handleRefresh,
        color: CupertinoColors.activeBlue,
        child: NestedScrollView(
          controller: _internalScrollController,
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Container(
                  color: cardColor,
                  child: Column(
                    children: [
                      if (!showAppBar) const SizedBox(height: 40),
                      SizedBox(
                        height: 310,
                        child: Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            // 1. ẢNH BÌA
                            Positioned(
                              top: 0, left: 0, right: 0, height: 220,
                              child: Image.network(
                                  _user!.coverUrl ?? 'https://images.unsplash.com/photo-1513151233558-d860c5398176?q=80&w=2070&auto=format&fit=crop',
                                  fit: BoxFit.cover),
                            ),
                            // 2. AVATAR TRÒN
                            Positioned(
                              top: 140,
                              child: Container(
                                padding: const EdgeInsets.all(5.0),
                                decoration: BoxDecoration(color: cardColor, shape: BoxShape.circle),
                                child: AvatarWithStoryBorder(
                                  userId: _user!.id,
                                  avatarUrl: _user!.avatarUrl,
                                  radius: 80,
                                  borderWidth: 0,
                                  // 👇 GẮN HÀM XỬ LÝ NHẤN AVATAR VÀO ĐÂY
                                  onTap: _onAvatarTap,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          children: [
                            Text(_user!.displayName, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor)),
                            const SizedBox(height: 8),
                            if (_user!.bio != null && _user!.bio!.isNotEmpty)
                              Text(_user!.bio!, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, color: textColor?.withOpacity(0.7))),
                            const SizedBox(height: 20),
                            isCurrentUser ? _buildCurrentUserActions(context) : _buildOtherUserActions(context),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(children: [
                          const Divider(),
                          ListTile(
                              leading: const Icon(CupertinoIcons.info_circle_fill, color: Colors.grey),
                              title: Text('Xem thông tin giới thiệu của ${_user!.displayName}', style: TextStyle(fontWeight: FontWeight.w500, color: textColor)),
                              trailing: const Icon(CupertinoIcons.right_chevron, size: 16, color: Colors.grey),
                              onTap: _showDetailInfo)
                        ]),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                delegate: _SliverTabBarDelegate(TabBar(
                    controller: _tabController,
                    labelColor: CupertinoColors.activeBlue,
                    unselectedLabelColor: Colors.grey[600],
                    indicatorColor: CupertinoColors.activeBlue,
                    tabs: const [Tab(text: 'Bài viết'), Tab(text: 'Bạn bè')])),
                pinned: true,
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildPostsTab(currentUser, textColor),
              _buildFriendsTab(_user!.friends, textColor)
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostsTab(UserModel? currentUser, Color? textColor) {
    return FutureBuilder<List<Post>>(
      future: _postsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CupertinoActivityIndicator());
        if (snapshot.hasError) return Center(child: Text('Lỗi tải bài viết: ${snapshot.error}', style: TextStyle(color: textColor)));
        final posts = snapshot.data ?? [];
        if (posts.isEmpty) return Center(child: Padding(padding: const EdgeInsets.only(top: 40), child: Text('Chưa có bài viết nào.', style: TextStyle(color: textColor))));
        return ListView.builder(padding: const EdgeInsets.all(8), itemCount: posts.length, itemBuilder: (context, index) => PostCard(post: posts[index], currentUser: currentUser));
      },
    );
  }

  Widget _buildFriendsTab(List<UserModel> friends, Color? textColor) {
    if (friends.isEmpty) return Center(child: Padding(padding: const EdgeInsets.only(top: 40), child: Text('Chưa có bạn bè nào.', style: TextStyle(color: textColor))));
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${friends.length} người bạn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 16),
          GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.8),
              itemCount: friends.length,
              itemBuilder: (context, index) => FriendGridItem(friend: friends[index]))
        ]),
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _SliverTabBarDelegate(this.tabBar);
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: Theme.of(context).cardColor, child: tabBar);
  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => tabBar != oldDelegate.tabBar;
}
