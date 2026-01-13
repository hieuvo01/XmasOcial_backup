// File: lib/screens/social/story_viewer_screen.dart

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../models/story_model.dart';
import '../../../models/user_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/story_service.dart';

// Import Widget phụ trợ
import '../../config/story_styles.dart';
import '../../widgets/avatar_with_story_border.dart';

class StoryViewerScreen extends StatefulWidget {
  final List<UserStoryGroup> storyGroups;
  final int initialGroupIndex;

  const StoryViewerScreen({
    super.key,
    required this.storyGroups,
    required this.initialGroupIndex,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  VideoPlayerController? _videoController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  int _currentUserIndex = 0;
  int _currentStoryIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentUserIndex = widget.initialGroupIndex;
    _currentStoryIndex = 0;
    _pageController = PageController(initialPage: _currentUserIndex);
    _animationController = AnimationController(vsync: this);

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    _loadStory();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _videoController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // <--- CẬP NHẬT LOGIC: TỰ ĐỘNG GHÉP LINK SERVER CHO NHẠC --->
  void _loadStory() async {
    final story = widget.storyGroups[_currentUserIndex].stories[_currentStoryIndex];

    // 1. Reset trạng thái - DỪNG MỌI THỨ TRƯỚC
    try {
      if (_videoController != null) {
        await _videoController!.pause();
        await _videoController!.dispose();
      }
      _videoController = null;
      _animationController.stop();
      _animationController.reset();
      await _audioPlayer.stop();
    } catch (e) {
      print("Lỗi reset state: $e");
    }

    Provider.of<StoryService>(context, listen: false).markAsViewed(story.id);

    // 2. XỬ LÝ URL NHẠC (QUAN TRỌNG: GHÉP BASE URL)
    String? cleanMusicUrl = story.musicUrl;

    // 👇👇👇 LOGIC MỚI BẮT ĐẦU TỪ ĐÂY 👇👇👇
    if (cleanMusicUrl != null &&
        cleanMusicUrl.isNotEmpty &&
        cleanMusicUrl != 'null' &&
        cleanMusicUrl != 'undefined') {

      // Nếu link chưa bắt đầu bằng http (tức là link nội bộ uploads/...), ta phải ghép Base URL vào
      if (!cleanMusicUrl.startsWith('http')) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final baseUrl = authService.baseUrl; // Lấy http://ip:port từ AuthService

        if (baseUrl != null) {
          // Xử lý dấu / để tránh bị 2 dấu // hoặc thiếu
          String cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
          String cleanPath = cleanMusicUrl.startsWith('/') ? cleanMusicUrl.substring(1) : cleanMusicUrl;
          cleanMusicUrl = '$cleanBase/$cleanPath';
        }
      }
    }
    // 👆👆👆 KẾT THÚC LOGIC MỚI 👆👆👆

    // Kiểm tra lần cuối: Phải bắt đầu bằng http thì mới coi là hợp lệ
    bool hasBackgroundMusic = cleanMusicUrl != null &&
        cleanMusicUrl.startsWith('http');

    if (!hasBackgroundMusic) {
      cleanMusicUrl = null;
    } else {
      print("👉 Final Music URL: $cleanMusicUrl"); // Debug xem link cuối cùng đúng chưa
    }

    Duration? musicDuration;

    // === TRƯỜNG HỢP VIDEO ===
    if (story.mediaType == MediaType.video && story.mediaUrl != null) {
      _videoController = VideoPlayerController.networkUrl(
          Uri.parse(story.mediaUrl!),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true)
      );

      try {
        await _videoController!.initialize();

        if (mounted) {
          setState(() {});

          if (hasBackgroundMusic) {
            // A. CÓ NHẠC NỀN -> Mute Video, Play Nhạc
            await _videoController!.setVolume(0);
            await _videoController!.play();

            await _audioPlayer.setAudioContext(AudioContext(
              android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
              iOS: AudioContextIOS(
                  category: AVAudioSessionCategory.playback,
                  options: {AVAudioSessionOptions.mixWithOthers}
              ),
            ));

            try {
              await _audioPlayer.play(UrlSource(cleanMusicUrl!), volume: 1.0);
            } catch (e) {
              print("Lỗi phát nhạc video: $e");
            }

          } else {
            // B. KHÔNG CÓ NHẠC NỀN -> Mở tiếng Video
            await _videoController!.setVolume(1.0);
            await _videoController!.play();
          }

          _animationController.duration = _videoController!.value.duration;
          _animationController.forward();
        }
      } catch (e) {
        print("Lỗi tải video: $e");
        _animationController.duration = const Duration(seconds: 5);
        if(mounted) _animationController.forward();
      }
    }
    // === TRƯỜNG HỢP ẢNH / TEXT ===
    else {
      if (hasBackgroundMusic) {
        try {
          await _audioPlayer.play(UrlSource(cleanMusicUrl!), volume: 1.0);

          try {
            musicDuration = await _audioPlayer.getDuration();
          } catch (_) {}

          if (musicDuration == null || musicDuration.inSeconds == 0) {
            musicDuration = const Duration(seconds: 30);
          }
        } catch (e) {
          print("Lỗi phát nhạc ảnh/text: $e");
        }
      }

      Duration displayDuration = const Duration(seconds: 5);
      if (musicDuration != null) displayDuration = musicDuration;

      _animationController.duration = displayDuration;
      if (mounted) {
        setState(() {});
        _animationController.forward();
      }
    }
  }



  void _nextStory() {
    final currentStories = widget.storyGroups[_currentUserIndex].stories;
    if (_currentStoryIndex < currentStories.length - 1) {
      setState(() { _currentStoryIndex++; });
      _loadStory();
    } else {
      if (_currentUserIndex < widget.storyGroups.length - 1) {
        setState(() { _currentUserIndex++; _currentStoryIndex = 0; });
        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
        _loadStory();
      } else {
        Navigator.pop(context);
      }
    }
  }

  void _previousStory() {
    if (_currentStoryIndex > 0) {
      setState(() { _currentStoryIndex--; });
      _loadStory();
    } else {
      if (_currentUserIndex > 0) {
        setState(() { _currentUserIndex--; _currentStoryIndex = widget.storyGroups[_currentUserIndex].stories.length - 1; });
        _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
        _loadStory();
      } else {
        Navigator.pop(context);
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() { _currentUserIndex = index; _currentStoryIndex = 0; });
    _loadStory();
  }

  Future<void> _handleDeleteStory(Story story) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Provider.of<StoryService>(context, listen: false).deleteStory(story.id);
      if (mounted) {
        navigator.pop();
        messenger.showSnackBar(const SnackBar(content: Text("Đã xóa tin thành công")));
      }
    } catch (e) {
      if (mounted) {
        _animationController.forward();
        _audioPlayer.resume();
        messenger.showSnackBar(SnackBar(content: Text("Lỗi: ${e.toString()}")));
      }
    }
  }

  void _showMoreOptions(Story story) {
    _animationController.stop();
    if (_videoController != null) _videoController!.pause();
    _audioPlayer.pause();

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Tùy chọn tin'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              showCupertinoDialog(
                context: context,
                builder: (ctx) => CupertinoAlertDialog(
                  title: const Text('Xóa tin này?'),
                  content: const Text('Hành động này không thể hoàn tác.'),
                  actions: [
                    CupertinoDialogAction(child: const Text('Hủy'), onPressed: () {
                      Navigator.pop(ctx);
                      _resumeStory();
                    }),
                    CupertinoDialogAction(isDestructiveAction: true, child: const Text('Xóa'), onPressed: () { Navigator.pop(ctx); _handleDeleteStory(story); }),
                  ],
                ),
              );
            },
            child: const Text('Xóa tin'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(child: const Text('Hủy'), onPressed: () {
          Navigator.pop(context);
          _resumeStory();
        }),
      ),
    ).whenComplete(() {
      if (mounted && !_animationController.isAnimating) {
        // Handle complete logic if needed
      }
    });
  }

  void _resumeStory() {
    if (mounted) {
      _animationController.forward();
      if (_videoController != null) _videoController!.play();
      _audioPlayer.resume();
    }
  }

  // 👇👇👇 CẬP NHẬT HÀM NÀY ĐỂ HỖ TRỢ DARK MODE 👇👇👇
  void _showViewersList(Story story) {
    _animationController.stop();
    if (_videoController != null) _videoController!.pause();
    _audioPlayer.pause();

    // Lấy Theme hiện tại
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Màu sắc động theo Theme
    final backgroundColor = theme.scaffoldBackgroundColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final handleColor = isDark ? Colors.grey[700] : Colors.grey[300];

    showModalBottomSheet(
      context: context,
      backgroundColor: backgroundColor, // Background động
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5, minChildSize: 0.3, maxChildSize: 0.9, expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                children: [
                  // Thanh Handle
                  Container(
                      width: 40, height: 5,
                      decoration: BoxDecoration(color: handleColor, borderRadius: BorderRadius.circular(10))
                  ),
                  const SizedBox(height: 10),
                  Text('Người đã xem', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                  const Divider(height: 20),
                  Expanded(
                    child: FutureBuilder<List<UserModel>>(
                      future: Provider.of<StoryService>(context, listen: false).getStoryViewers(story.id),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CupertinoActivityIndicator());
                        final viewers = snapshot.data ?? [];
                        if (viewers.isEmpty) return Center(child: Text('Chưa có ai xem tin này.', style: TextStyle(color: subTextColor)));
                        return ListView.builder(
                          controller: scrollController,
                          itemCount: viewers.length,
                          itemBuilder: (context, index) {
                            final viewer = viewers[index];
                            return ListTile(
                              leading: AvatarWithStoryBorder(userId: viewer.id, avatarUrl: viewer.avatarUrl, radius: 20),
                              title: Text(viewer.displayName, style: TextStyle(color: textColor)), // Text động
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _resumeStory();
    });
  }
  // 👆👆👆

  @override
  Widget build(BuildContext context) {
    if (widget.storyGroups.isEmpty) return const Scaffold(backgroundColor: Colors.black, body: Center(child: Text("Không có story", style: TextStyle(color: Colors.white))));
    // Nền Story luôn là Đen để tối ưu trải nghiệm xem ảnh/video
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          if (details.globalPosition.dx < MediaQuery.of(context).size.width / 3) _previousStory(); else _nextStory();
        },
        onLongPressStart: (_) {
          _animationController.stop();
          _videoController?.pause();
          _audioPlayer.pause();
        },
        onLongPressEnd: (_) {
          _animationController.forward();
          _videoController?.play();
          _audioPlayer.resume();
        },
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: widget.storyGroups.length,
              itemBuilder: (context, userIndex) {
                final currentStories = widget.storyGroups[userIndex].stories;
                if (currentStories.isEmpty) return Container(color: Colors.black);
                final storyIndexToShow = userIndex == _currentUserIndex ? _currentStoryIndex : 0;
                return _buildStoryContent(currentStories[storyIndexToShow]);
              },
            ),
            _buildUIOverlay(),
            Positioned(bottom: 20, left: 0, right: 0, child: _buildBottomBar())
          ],
        ),
      ),
    );
  }

  Widget _buildStoryContent(Story story) {
    if (story.mediaType == MediaType.text) {
      return Container(
        decoration: BoxDecoration(gradient: StoryStyleHelper.getGradient(story.style)),
        child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24.0), child: Text(story.text ?? '', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, fontFamily: 'Helvetica', decoration: TextDecoration.none, shadows: [Shadow(blurRadius: 10, color: Colors.black45)])))),
      );
    } else if (story.mediaType == MediaType.video) {
      if (_videoController != null && _videoController!.value.isInitialized) return Center(child: AspectRatio(aspectRatio: _videoController!.value.aspectRatio, child: VideoPlayer(_videoController!)));
      return const Center(child: CupertinoActivityIndicator(color: Colors.white));
    } else {
      return CachedNetworkImage(imageUrl: story.mediaUrl ?? '', fit: BoxFit.contain, width: double.infinity, height: double.infinity, progressIndicatorBuilder: (ctx, url, progress) => const Center(child: CupertinoActivityIndicator(color: Colors.white)), errorWidget: (ctx, url, error) => const Center(child: Icon(Icons.error_outline, color: Colors.red, size: 50)));
    }
  }

  Widget _buildUIOverlay() {
    final stories = widget.storyGroups[_currentUserIndex].stories;
    if (stories.isEmpty) return const SizedBox.shrink();
    final currentStory = stories[_currentStoryIndex];
    final authService = Provider.of<AuthService>(context, listen: false);
    final isMyStory = authService.user?.id == currentStory.user.id;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 10, left: 10, right: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: List.generate(stories.length, (index) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2.0), child: _AnimatedBar(animationController: _animationController, position: index, currentIndex: _currentStoryIndex))))),
          const SizedBox(height: 10),
          ListTile(
            leading: AvatarWithStoryBorder(userId: currentStory.user.id, avatarUrl: currentStory.user.avatarUrl, radius: 20, onTap: () {}),
            title: Text(currentStory.user.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, shadows: [Shadow(blurRadius: 3)])),
            subtitle: Text(timeago.format(currentStory.createdAt, locale: 'vi'), style: const TextStyle(color: Colors.white70, fontSize: 12, shadows: [Shadow(blurRadius: 3)])),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [if (isMyStory) IconButton(icon: const Icon(CupertinoIcons.ellipsis_circle, color: Colors.white, size: 28), onPressed: () => _showMoreOptions(currentStory)), IconButton(icon: const Icon(CupertinoIcons.clear, color: Colors.white, size: 28), onPressed: () => Navigator.of(context).pop())]),
            dense: true, contentPadding: EdgeInsets.zero,
          ),

          if (currentStory.musicUrl != null && currentStory.musicUrl!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(left: 50, top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white30, width: 0.5)
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.music_note, color: Colors.white, size: 12),
                  const SizedBox(width: 8),
                  ScrollingText(
                    text: currentStory.musicName ?? "Âm thanh gốc",
                    width: MediaQuery.of(context).size.width * 0.4,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.graphic_eq, color: Colors.white70, size: 12),
                ],
              ),
            ),

          if (currentStory.reactions.isNotEmpty && isMyStory)
            Container(
              margin: const EdgeInsets.only(top: 20, left: 4), height: 40, width: MediaQuery.of(context).size.width * 0.8,
              child: ListView.builder(
                scrollDirection: Axis.horizontal, itemCount: currentStory.reactions.length,
                itemBuilder: (context, index) {
                  final reaction = currentStory.reactions[index];
                  String getIconAsset(String type) {
                    const validTypes = ['like', 'love', 'haha', 'wow', 'sad', 'angry'];
                    return validTypes.contains(type) ? 'assets/images/reactions/$type.gif' : 'assets/images/reactions/like.gif';
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: (reaction.user.avatarUrl != null && reaction.user.avatarUrl!.isNotEmpty)
                              ? NetworkImage(reaction.user.avatarUrl!)
                              : const NetworkImage('https://via.placeholder.com/150'),
                        ),
                        Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)]), child: Image.asset(getIconAsset(reaction.type), width: 14, height: 14, fit: BoxFit.contain))
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final story = widget.storyGroups[_currentUserIndex].stories[_currentStoryIndex];
    final authService = Provider.of<AuthService>(context, listen: false);
    final isMyStory = (authService.user?.id != null && story.user.id == authService.user!.id);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMyStory) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ['like', 'love', 'haha', 'wow', 'sad', 'angry'].map((type) {
                return GestureDetector(
// Trong Widget _buildBottomBar() của file story_viewer_screen.dart

                  onTap: () async {
                    try {
                      final storyService = Provider.of<StoryService>(context, listen: false);

                      // 1. Gửi React lên server
                      await storyService.reactToStory(story.id, type);

                      // 2. 🔥 GỌI HÀM NÀY ĐỂ CẬP NHẬT UI NGAY LẬP TỨC
                      await storyService.refreshSingleStory(story.id);

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Đã bày tỏ cảm xúc!'),
                                duration: Duration(milliseconds: 500)
                            )
                        );
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
                    }
                  },
                  child: Image.asset('assets/images/reactions/$type.gif', width: 42, height: 42),
                );
              }).toList()),
            ),
          ],
          if (isMyStory) ...[
            const SizedBox(height: 10),
            TextButton.icon(style: TextButton.styleFrom(backgroundColor: Colors.black54, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), icon: const Icon(Icons.visibility, color: Colors.white, size: 16), label: Text('${story.viewerIds.length} người đã xem', style: const TextStyle(color: Colors.white, fontSize: 13)), onPressed: () => _showViewersList(story)),
          ]
        ],
      ),
    );
  }
}

class ScrollingText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double width;

  const ScrollingText({
    super.key,
    required this.text,
    required this.style,
    required this.width,
  });

  @override
  State<ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<ScrollingText> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController)
      ..addListener(() {
        if (_scrollController.hasClients) {
          double maxScroll = _scrollController.position.maxScrollExtent;
          _scrollController.jumpTo(maxScroll * _animation.value);
        }
      })
      ..addStatusListener((status) async {
        if (status == AnimationStatus.completed) {
          await Future.delayed(const Duration(seconds: 2));
          if(mounted) _animationController.reverse();
        } else if (status == AnimationStatus.dismissed) {
          await Future.delayed(const Duration(seconds: 2));
          if(mounted) _animationController.forward();
        }
      });

    Future.delayed(const Duration(seconds: 1), () {
      if(mounted) _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Text(widget.text, style: widget.style),
      ),
    );
  }
}

class _AnimatedBar extends StatelessWidget {
  final AnimationController animationController;
  final int position;
  final int currentIndex;
  const _AnimatedBar({required this.animationController, required this.position, required this.currentIndex});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(borderRadius: BorderRadius.circular(5), child: Container(height: 3, color: Colors.white.withOpacity(0.3), child: AnimatedBuilder(animation: animationController, builder: (context, child) { return Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: (position < currentIndex) ? 1.0 : (position == currentIndex) ? animationController.value : 0.0, child: Container(color: Colors.white))); })));
  }
}
