// File: lib/screens/social/create_reel_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../services/reel_service.dart';
import '../../services/post_service.dart'; // 👈 Thêm cái này để dùng hàm upload Cloudinary

class CreateReelScreen extends StatefulWidget {
  final File videoFile;
  const CreateReelScreen({super.key, required this.videoFile});

  @override
  State<CreateReelScreen> createState() => _CreateReelScreenState();
}

class _CreateReelScreenState extends State<CreateReelScreen> {
  late VideoPlayerController _controller;
  final TextEditingController _captionController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.videoFile)
      ..initialize().then((_) {
        setState(() {});
        _controller.setLooping(true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _uploadReel() async {
    if (_captionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hãy viết mô tả cho video nhé!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🚀 BƯỚC 1: Upload video lên Cloudinary (Dùng hàm public của PostService)
      final postService = Provider.of<PostService>(context, listen: false);

      // Gọi hàm uploadDirectToCloudinary (đã bỏ dấu _)
      // Nhớ truyền resourceType là 'video'
      final String? cloudVideoUrl = await postService.uploadDirectToCloudinary(
          widget.videoFile,
          'video',
          folder: 'xmasocial_reels' // Lưu vào folder riêng cho Reels cho đẹp
      );

      if (cloudVideoUrl != null) {
        // 🚀 BƯỚC 2: Gửi link đó về Server Database
        final success = await Provider.of<ReelService>(context, listen: false)
            .createReelDirect(
            videoUrl: cloudVideoUrl,
            description: _captionController.text
        );

        if (success && mounted) {
          Navigator.pop(context, true);
          return;
        }
      }

      throw Exception("Không thể upload video lên Cloudinary");

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi đăng Reel: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Reel Mới', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _uploadReel,
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Đăng', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (_controller.value.isInitialized)
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            else
              const SizedBox(height: 300, child: Center(child: CircularProgressIndicator())),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _captionController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Viết mô tả cho thước phim này...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
