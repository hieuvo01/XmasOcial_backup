// File: lib/screens/admin/reel_detail_screen.dart

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import '../../config/app_config.dart';
import '../../services/admin_service.dart';

class ReelDetailScreen extends StatefulWidget {
  final Map<String, dynamic> reel; // Dữ liệu reel được truyền sang
  const ReelDetailScreen({super.key, required this.reel});

  @override
  State<ReelDetailScreen> createState() => _ReelDetailScreenState();
}

class _ReelDetailScreenState extends State<ReelDetailScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isPlayerInitialized = false;
  final String _baseUrl = AppConfig.baseUrl;

  // State cho Comments
  bool _isLoadingComments = true;
  List<dynamic> _comments = [];
  final AdminService _adminService = AdminService();

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _fetchComments(); // Gọi API lấy comment
  }

  // 1. Khởi tạo Video Player
  // 1. Khởi tạo Video Player
  Future<void> _initializePlayer() async {
    String? videoUrl = widget.reel['videoUrl'];

    // 👇 TEST MODE: Nếu không có URL thật, dùng video mẫu để test giao diện
    if (videoUrl == null || videoUrl.isEmpty) {
      print("⚠️ Không có video URL, đang dùng video mẫu để test.");
      videoUrl = 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';
    }
    // -----------------------------------------------------------

    // Xử lý link local (localhost)
    if (!videoUrl.startsWith('http')) {
      videoUrl = "$_baseUrl$videoUrl";
    }

    try {
      print("▶️ Đang phát video: $videoUrl"); // Log để check link

      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: true,
        aspectRatio: _videoController!.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(height: 8),
                Text("Lỗi tải video:\n$errorMessage",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white)),
              ],
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          _isPlayerInitialized = true;
        });
      }
    } catch (e) {
      print("❌ Lỗi video player: $e");
    }
  }


  // 2. Lấy danh sách Comments (Giả sử API getCommentsForPost dùng được cho Reel nếu Reel cũng là 1 dạng Post)
  // Nếu Reel có API riêng thì bro thay _adminService.getCommentsForReel vào đây
  Future<void> _fetchComments() async {
    try {
      // Lưu ý: Nếu hệ thống của bro Reel lưu comments riêng thì cần viết thêm API getCommentsForReel
      // Tạm thời mình dùng API getCommentsForPost (nếu cấu trúc giống nhau) hoặc để trống chờ API
      // Ở đây tôi giả lập lấy comment rỗng để không bị lỗi crash app

      // final comments = await _adminService.getCommentsByPostId(context, widget.reel['_id']);

      // Giả sử chưa có API riêng, set rỗng trước
      if (mounted) {
        setState(() {
          _comments = widget.reel['comments'] ?? []; // Nếu reel object đã populate sẵn comments
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      print("Lỗi lấy comment: $e");
      if (mounted) setState(() => _isLoadingComments = false);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  // Helper: Format ngày
  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      return DateFormat('dd/MM HH:mm').format(DateTime.parse(dateStr));
    } catch(e) { return ''; }
  }

  // Helper: Lấy URL ảnh
  String? _getUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    return "$_baseUrl$url";
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.reel['user'] ?? {};

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text("Kiểm duyệt: ${user['displayName'] ?? 'Unknown'}",
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        leading: const BackButton(color: Colors.white),
      ),
      body: Column(
        children: [
          // A. VIDEO PLAYER (Phần trên)
          Expanded(
            flex: 4,
            child: Container(
              color: Colors.black,
              child: Center(
                child: _isPlayerInitialized
                    ? Chewie(controller: _chewieController!)
                    : const CircularProgressIndicator(color: Colors.white),
              ),
            ),
          ),

          // B. INFO & COMMENTS (Phần dưới)
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Thông tin Reel
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundImage: _getUrl(user['avatarUrl']) != null
                                  ? NetworkImage(_getUrl(user['avatarUrl'])!)
                                  : null,
                              child: _getUrl(user['avatarUrl']) == null ? const Icon(Icons.person, size: 12) : null,
                            ),
                            const SizedBox(width: 8),
                            Text(user['displayName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Text(_formatDate(widget.reel['createdAt']), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(widget.reel['description'] ?? "Không có mô tả", style: const TextStyle(fontSize: 15)),
                        const Divider(height: 20),
                        const Text("Bình luận:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ),

                  // 2. Danh sách Comment
                  Expanded(
                    child: _isLoadingComments
                        ? const Center(child: CircularProgressIndicator())
                        : _comments.isEmpty
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, color: Colors.grey[400], size: 40),
                          const SizedBox(height: 8),
                          Text("Chưa có bình luận nào", style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    )
                        : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _comments.length,
                      separatorBuilder: (_,__) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final cmt = _comments[index];
                        final author = cmt['author'] ?? cmt['user'] ?? {}; // Handle linh hoạt field

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundImage: _getUrl(author['avatarUrl']) != null
                                  ? NetworkImage(_getUrl(author['avatarUrl'])!)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(author['displayName'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text(cmt['content'] ?? '', style: const TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  // 3. Nút Xóa
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0,-2))]
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.delete_forever),
                      label: const Text("XÓA REEL NÀY"),
                      onPressed: () {
                        Navigator.pop(context, 'delete'); // Trả về signal delete
                      },
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
