// File: lib/screens/social/reels_screen.dart

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/auth_service.dart';
import '../../services/reel_service.dart';
import '../../services/navigation_service.dart';
import '../../models/reel_model.dart';
import '../../utils/number_formatter.dart';
import '../social/user_profile_screen.dart';
import 'create_reel_screen.dart';

// --- MODEL CHO TIM BAY ---
class HeartOverlay {
  final String id;
  final Offset position;
  final double rotation;
  final List<Color> gradientColors;

  HeartOverlay({
    required this.id,
    required this.position,
    required this.rotation,
    required this.gradientColors,
  });
}

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  // 👇 THÊM BIẾN NÀY ĐỂ THEO DÕI PAGE HIỆN TẠI
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReelService>(context, listen: false).fetchReels();
    });
  }

  void _backToHome() {
    final navService = Provider.of<NavigationService>(context, listen: false);
    if (navService.pageController != null) {
      navService.pageController!.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleUploadReel() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

    if (video != null && mounted) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateReelScreen(videoFile: File(video.path)),
        ),
      );

      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Đã đăng Reel thành công! Xem ngay ở đầu trang."))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lưu ý: Reels luôn dùng nền đen để xem video tốt nhất, bất kể Dark/Light mode
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<ReelService>(
        builder: (context, reelService, child) {
          if (reelService.isLoading && reelService.reels.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }

          if (reelService.reels.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Chưa có video nào", style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 10),
                  ElevatedButton(
                      onPressed: () => reelService.fetchReels(),
                      child: const Text("Thử lại"))
                ],
              ),
            );
          }

          return GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! > 300 || details.primaryVelocity! < -300) {
                _backToHome();
              }
            },
            child: Stack(
              children: [
                PageView.builder(
                  scrollDirection: Axis.vertical,
                  itemCount: reelService.reels.length,
                  onPageChanged: (index) {
                    // 👇 CẬP NHẬT INDEX KHI SCROLL
                    setState(() {
                      _currentIndex = index;
                    });

                    // Load more logic
                    if (index > reelService.reels.length - 3) {
                      Provider.of<ReelService>(context, listen: false).fetchReels(loadMore: true);
                    }
                  },
                  itemBuilder: (context, index) {
                    // 👇 TRUYỀN BIẾN isActive XUỐNG
                    return ReelItem(
                      key: ValueKey(reelService.reels[index].id),
                      reel: reelService.reels[index],
                      isActive: index == _currentIndex,
                    );
                  },
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 16,
                  child: GestureDetector(
                    onTap: _backToHome,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 28),
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 20,
                  left: 0,
                  right: 0,
                  child: const Center(
                    child: Text(
                      "Reels",
                      style: TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  right: 16,
                  child: GestureDetector(
                    onTap: _handleUploadReel,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ReelItem extends StatefulWidget {
  final Reel reel;
  final bool isActive; // 👇 NHẬN BIẾN NÀY

  const ReelItem({super.key, required this.reel, required this.isActive});

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  final List<HeartOverlay> _hearts = [];
  bool _isLiked = false;
  int _localLikeCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeVideo();

    final currentUser = Provider.of<AuthService>(context, listen: false).user;
    if (currentUser != null && widget.reel.likes.contains(currentUser.id)) {
      _isLiked = true;
    } else {
      _isLiked = false;
    }
    _localLikeCount = widget.reel.likeCount;
  }

  // 👇 LOGIC QUAN TRỌNG: NGHE SỰ KIỆN THAY ĐỔI "ACTIVE"
  @override
  void didUpdateWidget(covariant ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller?.play();
      } else {
        _controller?.pause();
        _controller?.seekTo(Duration.zero); // Reset về đầu nếu muốn
      }
    }
  }

  void _initializeVideo() async {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.reel.videoUrl));
    try {
      await _controller!.initialize();
      await _controller!.setLooping(true);

      // 👇 CHỈ PLAY NẾU ĐANG LÀ TRANG ACTIVE (FIX LỖI ÂM THANH CHỒNG CHÉO)
      if (widget.isActive) {
        await _controller!.play();
      }

      if (mounted) setState(() => _isInitialized = true);
      _controller!.addListener(() {
        if (mounted) setState(() {});
      });
    } catch (e) {
      print("Lỗi load reel: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  List<Color> _generateRandomGradient() {
    final Random random = Random();
    return [
      Color.fromARGB(255, 200 + random.nextInt(55), random.nextInt(100), random.nextInt(100)),
      Color.fromARGB(255, random.nextInt(256), random.nextInt(256), 200 + random.nextInt(55)),
    ];
  }

  void _toggleLike({TapDownDetails? details}) {
    setState(() {
      if (!_isLiked) {
        _isLiked = true;
        _localLikeCount++;
        if (details != null) {
          final String heartId = DateTime.now().microsecondsSinceEpoch.toString();
          final Random random = Random();
          double rotation = (random.nextInt(30) - 15) * pi / 180;
          _hearts.add(HeartOverlay(
            id: heartId,
            position: details.globalPosition,
            rotation: rotation,
            gradientColors: _generateRandomGradient(),
          ));
          Timer(const Duration(milliseconds: 1000), () {
            if (mounted) setState(() => _hearts.removeWhere((heart) => heart.id == heartId));
          });
        }
      } else {
        if (details == null) {
          _isLiked = false;
          _localLikeCount--;
        }
      }
    });

    if (details == null || (details != null && _isLiked)) {
      Provider.of<ReelService>(context, listen: false).likeReel(widget.reel.id);
    }
  }

  void _handleShare() {
    Share.share(
      'Xem video này nè bro: ${widget.reel.videoUrl}\nĐăng bởi: ${widget.reel.user.displayName}',
      subject: 'Chia sẻ từ Face-Noel',
    );
  }

  void _navigateToProfile() {
    _controller?.pause();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(userId: widget.reel.user.id),
      ),
    ).then((_) {
      // Khi quay lại thì play tiếp nếu đang active
      if (widget.isActive) _controller?.play();
    });
  }

  void _showCommentSheet() {
    final TextEditingController commentController = TextEditingController();

    // --- DARK MODE LOGIC ---
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final inputFillColor = isDark ? Colors.grey[850] : Colors.grey[100];
    final hintColor = isDark ? Colors.grey[400] : Colors.grey[600];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: bgColor, // Áp dụng màu nền theo Theme
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text("Bình luận", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: FutureBuilder<List<dynamic>>(
                      future: Provider.of<ReelService>(context, listen: false).getComments(widget.reel.id),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CupertinoActivityIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Center(child: Text("Chưa có bình luận nào.", style: TextStyle(color: hintColor)));
                        }
                        final comments = snapshot.data!;
                        return ListView.builder(
                          controller: scrollController,
                          itemCount: comments.length,
                          itemBuilder: (context, index) {
                            final comment = comments[index];
                            final user = comment['user'];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: user != null && user['avatarUrl'] != null
                                    ? NetworkImage(user['avatarUrl'])
                                    : null,
                                backgroundColor: Colors.grey[200],
                                child: user == null || user['avatarUrl'] == null
                                    ? const Icon(Icons.person, color: Colors.grey)
                                    : null,
                              ),
                              title: Text(user?['displayName'] ?? 'Người dùng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                              subtitle: Text(comment['text'] ?? '', style: TextStyle(color: textColor)),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom + 10,
                        left: 10, right: 10, top: 10
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(radius: 16, backgroundColor: Colors.grey, child: Icon(Icons.person, color: Colors.white, size: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            style: TextStyle(color: textColor), // Màu chữ nhập vào
                            decoration: InputDecoration(
                              hintText: "Thêm bình luận...",
                              hintStyle: TextStyle(color: hintColor),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                              filled: true,
                              fillColor: inputFillColor, // Màu nền ô nhập
                            ),
                          ),
                        ),
                        IconButton(
                            onPressed: () async {
                              if (commentController.text.trim().isEmpty) return;
                              final newComment = await Provider.of<ReelService>(context, listen: false)
                                  .addComment(widget.reel.id, commentController.text);
                              if (newComment != null) {
                                commentController.clear();
                                Navigator.pop(context);
                                _showCommentSheet();
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã gửi bình luận!")));
                              }
                            },
                            icon: const Icon(Icons.send, color: Colors.blue)
                        ),
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const double heartSize = 100;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. VIDEO PLAYER
        GestureDetector(
          onTap: () {
            if (_controller != null && _controller!.value.isPlaying) {
              _controller!.pause();
            } else {
              _controller?.play();
            }
            setState(() {});
          },
          onDoubleTapDown: (details) => _toggleLike(details: details),
          onDoubleTap: () {},
          child: Container(
            color: Colors.black,
            child: _isInitialized
                ? Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            )
                : const Center(child: CupertinoActivityIndicator(color: Colors.white, radius: 15)),
          ),
        ),

        // 1.5 ICON PLAY
        if (_isInitialized && !_controller!.value.isPlaying)
          const Center(child: Icon(Icons.play_circle_fill, size: 60, color: Colors.white54)),

        // 2. TIM BAY
        ..._hearts.map((heart) {
          return Positioned(
            left: heart.position.dx - (heartSize / 2),
            top: heart.position.dy - (heartSize / 2),
            child: Transform.rotate(
              angle: heart.rotation,
              child: TikTokHeartAnimation(
                onComplete: () {},
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: heart.gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: const Icon(Icons.favorite, size: heartSize, color: Colors.white),
                ),
              ),
            ),
          );
        }),

        // 3. GRADIENT
        Positioned(
          bottom: 0, left: 0, right: 0, height: 350,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.6), Colors.black.withOpacity(0.9)],
              ),
            ),
          ),
        ),

        // 4. INFO
        Positioned(
          bottom: 80, left: 16, right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _navigateToProfile,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: widget.reel.user.avatarUrl != null ? NetworkImage(widget.reel.user.avatarUrl!) : null,
                      backgroundColor: Colors.grey[800],
                      child: widget.reel.user.avatarUrl == null ? const Icon(Icons.person, color: Colors.white, size: 18) : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.reel.user.displayName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!widget.reel.isExternal) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(border: Border.all(color: Colors.white), borderRadius: BorderRadius.circular(4)),
                      )
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(widget.reel.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14)),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.music_note, color: Colors.white, size: 14),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      widget.reel.isExternal ? "Original Audio • Pexels" : "Âm thanh gốc • ${widget.reel.user.displayName}",
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 5. CÁC NÚT TƯƠNG TÁC
        Positioned(
          bottom: 75, right: 10,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIconAction(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  NumberFormatter.format(_localLikeCount),
                  _isLiked ? Colors.red : Colors.white,
                  onTap: () => _toggleLike()
              ),
              const SizedBox(height: 20),
              _buildIconAction(
                  CupertinoIcons.chat_bubble_fill,
                  NumberFormatter.format(widget.reel.commentCount),
                  Colors.white,
                  onTap: _showCommentSheet
              ),
              const SizedBox(height: 20),
              _buildIconAction(
                CupertinoIcons.arrowshape_turn_up_right_fill, "Share", Colors.white,
                onTap: _handleShare,
              ),
              const SizedBox(height: 20),
              const RotatingMusicDisc(),
            ],
          ),
        ),

        // 6. SLIDER
        if (_isInitialized)
          Positioned(
            bottom: 50, left: 0, right: 0,
            child: SizedBox(
              height: 20,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  thumbShape: SliderComponentShape.noThumb,
                  overlayShape: SliderComponentShape.noOverlay,
                  trackHeight: 3,
                  activeTrackColor: Colors.redAccent,
                  inactiveTrackColor: Colors.white30,
                ),
                child: Slider(
                  value: _controller!.value.position.inMilliseconds.toDouble().clamp(0, _controller!.value.duration.inMilliseconds.toDouble()),
                  min: 0,
                  max: _controller!.value.duration.inMilliseconds.toDouble(),
                  onChanged: (value) {
                    _controller!.seekTo(Duration(milliseconds: value.toInt()));
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildIconAction(IconData icon, String text, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))
        ],
      ),
    );
  }
}

// ... GIỮ NGUYÊN PHẦN WIDGET HeartOverlay và Disc ở cuối file ...
class TikTokHeartAnimation extends StatefulWidget {
  final Widget child;
  final VoidCallback onComplete;

  const TikTokHeartAnimation({super.key, required this.child, required this.onComplete});

  @override
  State<TikTokHeartAnimation> createState() => _TikTokHeartAnimationState();
}

class _TikTokHeartAnimationState extends State<TikTokHeartAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.2, curve: Curves.elasticOut),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(begin: Offset.zero, end: const Offset(0, -0.8)).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _controller.forward().then((_) {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}

class RotatingMusicDisc extends StatefulWidget {
  const RotatingMusicDisc({super.key});

  @override
  State<RotatingMusicDisc> createState() => _RotatingMusicDiscState();
}

class _RotatingMusicDiscState extends State<RotatingMusicDisc> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 5), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Container(
        width: 45, height: 45, padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle, color: Colors.black87,
          border: Border.all(color: Colors.grey[800]!, width: 2),
        ),
        child: const Center(child: Icon(Icons.music_note, color: Colors.white, size: 20)),
      ),
    );
  }
}
