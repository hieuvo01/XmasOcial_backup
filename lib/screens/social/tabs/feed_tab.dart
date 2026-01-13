// File: lib/screens/social/tabs/feed_tab.dart

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

import '../../../config/story_styles.dart';
import '../../../models/story_model.dart';
import '../../../models/user_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/post_service.dart';
import '../../../services/story_service.dart';
import '../create_story_screen.dart';
import '../create_text_story_screen.dart';
import '../search_screen.dart';
import '../story_viewer_screen.dart';
import '../../../widgets/create_post_miniature.dart';
import '../../../widgets/post_card.dart';
import 'messenger_tab.dart';

class FeedTab extends StatefulWidget {
  final ScrollController? scrollController;
  const FeedTab({super.key, this.scrollController});

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleRefresh();
    });
  }

  Future<void> _handleRefresh() async {
    // Gọi song song để tiết kiệm thời gian
    await Future.wait([
      Provider.of<PostService>(context, listen: false).fetchPosts(),
      Provider.of<StoryService>(context, listen: false).fetchStories(),
    ]);
  }

  // === HÀM HELPER TẠO THUMBNAIL TỪ VIDEO URL ===
  Future<String?> _generateThumbnail(String videoUrl) async {
    try {
      final fileName = await VideoThumbnail.thumbnailFile(
        video: videoUrl,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 200,
        quality: 75,
      );
      return fileName;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthService>(context, listen: false).user;
    // Lấy màu từ theme
    final scaffoldBgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final dividerColor = Theme.of(context).dividerColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Material(
      color: scaffoldBgColor, // Sửa màu nền tổng
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: cardColor, // Sửa màu nền AppBar
          elevation: 0.5,
          centerTitle: false,
          title: const Text('XmasOcial', style: TextStyle(color: CupertinoColors.activeBlue, fontWeight: FontWeight.bold, fontSize: 26, fontFamily: 'Helvetica')),
          actions: [
            _buildActionIcon(CupertinoIcons.search, () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SearchScreen()));
            }),
            _buildActionIcon(CupertinoIcons.chat_bubble_text, () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const MessengerTab())
              );
            }),
          ],
        ),

        body: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: CupertinoColors.activeBlue,
          child: CustomScrollView(
            controller: widget.scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              // 1. Ô Tạo bài viết
              SliverToBoxAdapter(child: CreatePostMiniature(onPostCreated: _handleRefresh)),

              SliverToBoxAdapter(child: Divider(thickness: 8.0, color: dividerColor)), // Sửa màu Divider

              // 2. Stories Section
              Selector<StoryService, List<UserStoryGroup>>(
                selector: (_, service) => service.storyGroups,
                builder: (context, storyGroups, child) {
                  return _buildStoriesSection(currentUser, storyGroups);
                },
              ),

              SliverToBoxAdapter(child: Divider(thickness: 0.5, color: dividerColor, indent: 12, endIndent: 12)), // Sửa màu Divider

              // 3. Post List
              Consumer<PostService>(
                builder: (context, postService, child) {
                  if (postService.isLoading && postService.posts.isEmpty) {
                    return const SliverFillRemaining(child: Center(child: CupertinoActivityIndicator(radius: 15.0)));
                  }

                  if (postService.posts.isEmpty) {
                    return SliverFillRemaining(child: Center(child: Text("Chưa có bài viết nào.", style: TextStyle(color: textColor))));
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        return PostCard(
                          key: ValueKey(postService.posts[index].id),
                          post: postService.posts[index],
                          currentUser: currentUser,
                        );
                      },
                      childCount: postService.posts.length,
                    ),
                  );
                },
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoriesSection(UserModel? currentUser, List<UserStoryGroup> storyGroups) {
    return SliverToBoxAdapter(
      child: Container(
        height: 200.0,
        color: Theme.of(context).cardColor, // Sửa nền Story Section
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 1 + storyGroups.length,
          itemBuilder: (BuildContext context, int index) {
            if (index == 0) {
              return _buildCreateStoryCard(currentUser);
            }
            final groupIndex = index - 1;
            final storyGroup = storyGroups[groupIndex];
            return _buildStoryCard(storyGroup, groupIndex);
          },
        ),
      ),
    );
  }

  Widget _buildCreateStoryCard(UserModel? user) {
    const defaultAvatar = 'https://upload.wikimedia.org/wikipedia/commons/8/89/Portrait_Placeholder.png';
    final avatarUrl = (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
        ? user!.avatarUrl!
        : defaultAvatar;

    // Lấy màu thẻ con
    final cardColor = Theme.of(context).cardColor;
    final scaffoldColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            height: 200,
            decoration: BoxDecoration(
              color: cardColor, // Sửa nền bottom sheet
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                ),
                const SizedBox(height: 20),
                // ListTile(
                //   leading: const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.text_fields_rounded, color: Colors.white)),
                //   title: Text('Tạo tin dạng văn bản', style: TextStyle(fontWeight: FontWeight.w500, color: textColor)), // Sửa màu text
                //   onTap: () {
                //     Navigator.pop(context);
                //     Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTextStoryScreen()));
                //   },
                // ),
                ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.photo_library_rounded, color: Colors.white)),
                  title: Text('Chọn ảnh hoặc video', style: TextStyle(fontWeight: FontWeight.w500, color: textColor)), // Sửa màu text
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateStoryScreen()));
                  },
                ),
              ],
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(left: 12.0, right: 6.0),
        child: SizedBox(
          width: 110,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: CachedNetworkImage(
                  imageUrl: avatarUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  height: 70,
                  decoration: BoxDecoration(color: scaffoldColor, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12))), // Sửa màu nền chân thẻ
                  child: Center(child: Padding(padding: const EdgeInsets.only(top: 20.0), child: Text('Tạo tin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)))), // Sửa màu text
                ),
              ),
              Positioned(
                bottom: 45, left: 0, right: 0,
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: CupertinoColors.systemBlue, shape: BoxShape.circle, border: Border.all(color: cardColor, width: 4)), // Sửa viền theo màu nền
                  child: const Icon(CupertinoIcons.add, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoryCard(UserStoryGroup storyGroup, int groupIndex) {
    final story = storyGroup.stories.first;
    final user = storyGroup.user;
    const defaultAvatar = 'https://upload.wikimedia.org/wikipedia/commons/8/89/Portrait_Placeholder.png';

    Widget thumbnailWidget;

    // TRƯỜNG HỢP 1: TEXT
    if (story.mediaType == MediaType.text) {
      thumbnailWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        decoration: BoxDecoration(
          gradient: StoryStyleHelper.getGradient(story.style),
        ),
        child: Center(
          child: Text(
            story.text ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              fontFamily: 'Helvetica',
              overflow: TextOverflow.ellipsis,
            ),
            maxLines: 4,
          ),
        ),
      );
    }
    // TRƯỜNG HỢP 2: VIDEO
    else if (story.mediaType == MediaType.video) {
      thumbnailWidget = FutureBuilder<String?>(
        future: _generateThumbnail(story.mediaUrl ?? ''),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
            return Image.file(
              File(snapshot.data!),
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => Container(color: Colors.black),
            );
          } else {
            return Container(color: Colors.black);
          }
        },
      );
    }
    // TRƯỜNG HỢP 3: ẢNH
    else {
      thumbnailWidget = CachedNetworkImage(
        imageUrl: story.mediaUrl ?? '',
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: Colors.grey[200]),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[300],
          child: Icon(Icons.broken_image, color: Theme.of(context).cardColor),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        final storyService = Provider.of<StoryService>(context, listen: false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoryViewerScreen(
              storyGroups: storyService.storyGroups,
              initialGroupIndex: groupIndex,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        child: SizedBox(
          width: 110,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.0),
            child: Stack(
              fit: StackFit.expand,
              children: [
                thumbnailWidget,
                if (story.mediaType == MediaType.video)
                  const Center(child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 30)),

                Container(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7)
                            ]))),
                Positioned(
                  top: 8.0,
                  left: 8.0,
                  child: Container(
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: story.isViewed
                                ? CupertinoColors.systemGrey2
                                : CupertinoColors.systemBlue,
                            width: 2.5)),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundImage:
                      CachedNetworkImageProvider(user.avatarUrl ?? defaultAvatar),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8.0,
                  left: 8.0,
                  right: 8.0,
                  child: Text(user.displayName,
                      style: const TextStyle(
                          color: Colors.white, // Tên trên Story luôn trắng
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          shadows: [Shadow(blurRadius: 2.0)]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Hàm Helper tạo nút icon tròn
  Widget _buildActionIcon(IconData icon, VoidCallback onPressed) {
    // Lấy màu động: nền icon tự tối đi, icon tự sáng lên
    final bgColor = Theme.of(context).inputDecorationTheme.fillColor ?? Colors.grey[200];
    final iconColor = Theme.of(context).iconTheme.color;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor, size: 24),
        onPressed: onPressed,
        splashRadius: 20,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }
}
