// File: lib/widgets/video_thumbnail_widget.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

class VideoThumbnailWidget extends StatefulWidget {
  final String videoPath; // Có thể là URL mạng hoặc đường dẫn file local
  final bool isLocal; // true nếu là file đang chọn ở máy, false nếu là link server

  const VideoThumbnailWidget({
    super.key,
    required this.videoPath,
    this.isLocal = false
  });

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  String? _thumbnailPath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    try {
      final fileName = await VideoThumbnail.thumbnailFile(
        video: widget.videoPath,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 300, // Giới hạn kích thước cho nhẹ
        quality: 75,
      );

      if (mounted) {
        setState(() {
          _thumbnailPath = fileName;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Lỗi tạo thumbnail: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.black12,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_thumbnailPath != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(_thumbnailPath!),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildError(),
          ),
          // Icon Play đè lên để biết là video
          const Center(
            child: CircleAvatar(
              backgroundColor: Colors.black45,
              radius: 20,
              child: Icon(Icons.play_arrow, color: Colors.white, size: 25),
            ),
          ),
        ],
      );
    }

    return _buildError();
  }

  Widget _buildError() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }
}
