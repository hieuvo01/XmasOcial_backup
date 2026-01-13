// File: lib/screens/social/create_post_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/post_service.dart';

class CreatePostScreen extends StatefulWidget {
  final VoidCallback onPostCreated;

  const CreatePostScreen({super.key, required this.onPostCreated});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();

  // Dùng List để chứa nhiều ảnh/video
  final List<XFile> _mediaFiles = [];

  final ImagePicker _picker = ImagePicker();
  bool _isPosting = false;

  void _handlePost() async {
    FocusScope.of(context).unfocus();

    if (_contentController.text.trim().isEmpty && _mediaFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập nội dung hoặc chọn ảnh/video.')),
      );
      return;
    }

    setState(() {
      _isPosting = true;
    });

    try {
      final postService = Provider.of<PostService>(context, listen: false);

      // Chuyển đổi List<XFile> sang List<File>
      List<File> filesToUpload = _mediaFiles.map((xFile) => File(xFile.path)).toList();

      await postService.createPost(
        _contentController.text.trim(),
        mediaFiles: filesToUpload.isNotEmpty ? filesToUpload : null,
      );

      widget.onPostCreated();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xảy ra lỗi khi đăng bài: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  // Chọn nhiều ảnh cùng lúc
  Future<void> _pickMultiImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _mediaFiles.addAll(pickedFiles);
        });
      }
    } catch (e) {
      _showError('Không thể chọn ảnh: $e');
    }
  }

  // Chọn video
  Future<void> _pickVideo() async {
    try {
      final XFile? pickedVideo = await _picker.pickVideo(source: ImageSource.gallery);
      if (pickedVideo != null) {
        setState(() {
          _mediaFiles.add(pickedVideo);
        });
      }
    } catch (e) {
      _showError('Không thể chọn video: $e');
    }
  }

  // Mở Camera chụp ảnh
  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        setState(() {
          _mediaFiles.add(photo);
        });
      }
    } catch (e) {
      _showError('Không thể chụp ảnh: $e');
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _mediaFiles.removeAt(index);
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // Hàm kiểm tra xem file có phải là video không
  bool _isVideo(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv'].contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).user;
    const defaultAvatar = 'https://upload.wikimedia.org/wikipedia/commons/8/89/Portrait_Placeholder.png';
    final avatarUrl = (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty) ? user.avatarUrl! : defaultAvatar;

    // --- CẤU HÌNH DARK MODE ---
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    // Màu chữ
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    // Màu nền Input: Dark thì xám đen (grey[900]), Light thì xám nhạt (grey[100])
    final inputFillColor = isDark ? Colors.grey[900] : Colors.grey[100];
    final hintColor = isDark ? Colors.grey[500] : Colors.grey[400];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Tạo bài viết', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: SizedBox(
                height: 36,
                child: FilledButton(
                  onPressed: _isPosting ? null : _handlePost,
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 20)
                  ),
                  child: _isPosting
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Text('Đăng', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- USER INFO ---
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: NetworkImage(avatarUrl),
                        ),
                        const SizedBox(width: 12),
                        // Bọc vào Expanded để text tự co giãn và không gây Overflow
                        Expanded(
                          child: Text(
                            user?.displayName ?? 'Người dùng',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: textColor,
                            ),
                            overflow: TextOverflow.ellipsis, // Hiện dấu "..." nếu tên quá dài
                            maxLines: 1, // Chỉ hiển thị trên 1 dòng
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // --- INPUT TEXT FIELD (ĐẸP HƠN) ---
                    TextField(
                      controller: _contentController,
                      decoration: InputDecoration(
                        hintText: 'Bạn đang nghĩ gì thế?',
                        hintStyle: TextStyle(color: hintColor, fontSize: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none, // Bỏ viền để dùng màu nền
                        ),
                        filled: true, // Bật chế độ tô màu nền
                        fillColor: inputFillColor, // Màu nền động theo Dark Mode
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      maxLines: null,
                      minLines: 4, // Chiều cao tối thiểu
                      style: TextStyle(color: textColor, fontSize: 18), // Chữ to rõ ràng
                      cursorColor: Colors.blueAccent,
                      autofocus: true,
                    ),

                    const SizedBox(height: 20),

                    // --- MEDIA GRID VIEW ---
                    if (_mediaFiles.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(), // Để scroll theo trang chính
                          shrinkWrap: true,
                          itemCount: _mediaFiles.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2, // 2 cột
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                            childAspectRatio: 1.0,
                          ),
                          itemBuilder: (context, index) {
                            final file = _mediaFiles[index];
                            final isVideo = _isVideo(file.path);

                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  File(file.path),
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, _, __) => Container(
                                    color: Colors.grey[800],
                                    child: const Center(child: Icon(Icons.video_file, size: 40, color: Colors.white54)),
                                  ),
                                ),
                                if (isVideo)
                                  Container(
                                    color: Colors.black26,
                                    child: const Center(
                                      child: Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
                                    ),
                                  ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: GestureDetector(
                                    onTap: () => _removeMedia(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, size: 18, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 80), // Khoảng trống để không bị che bởi bottom bar
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // --- BOTTOM BAR ---
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
            boxShadow: [
              if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -2), blurRadius: 10)
            ]
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Thêm vào bài viết", style: TextStyle(fontWeight: FontWeight.w500)),
              Row(
                children: [
                  _buildOptionButton(Icons.photo_library, Colors.green, _pickMultiImages, "Ảnh"),
                  _buildOptionButton(Icons.camera_alt, Colors.blue, _takePhoto, "Camera"),
                  _buildOptionButton(Icons.video_collection, Colors.purple, _pickVideo, "Video"),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget con để tạo nút tùy chọn đẹp hơn
  Widget _buildOptionButton(IconData icon, Color color, VoidCallback onTap, String tooltip) {
    return IconButton(
      icon: Icon(icon, color: color),
      onPressed: onTap,
      tooltip: tooltip,
      splashRadius: 24,
    );
  }
}
