// File: lib/screens/social/create_text_story_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/story_service.dart';
import '../../config/story_styles.dart';

class CreateTextStoryScreen extends StatefulWidget {
  const CreateTextStoryScreen({super.key});

  @override
  State<CreateTextStoryScreen> createState() => _CreateTextStoryScreenState();
}

class _CreateTextStoryScreenState extends State<CreateTextStoryScreen> {
  final TextEditingController _textController = TextEditingController();
  int _selectedStyleIndex = 0; // Style đang chọn
  bool _isUploading = false;

  void _submitStory() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isUploading = true);

    try {
      final styleId = StoryStyleHelper.styles[_selectedStyleIndex]['id'] as String;

      // Gọi hàm createTextStory trong Service của bro
      await Provider.of<StoryService>(context, listen: false)
          .createStory(
        mediaType: 'text',
        text: text,
        style: styleId,
      );


      if (mounted) {
        Navigator.pop(context); // Đóng màn hình
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã đăng tin thành công!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentGradient = StoryStyleHelper.styles[_selectedStyleIndex]['gradient'] as Gradient;

    return Scaffold(
      body: Stack(
        children: [
          // 1. NỀN GRADIENT
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(gradient: currentGradient),
          ),

          // 2. Ô NHẬP TEXT Ở GIỮA
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: TextField(
                controller: _textController,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Helvetica', // Font đẹp tí
                ),
                maxLines: null, // Cho phép xuống dòng
                decoration: const InputDecoration(
                  hintText: 'Bạn đang nghĩ gì?',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
                autofocus: true,
              ),
            ),
          ),

          // 3. NÚT ĐÓNG (Góc trái trên)
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // 4. NÚT ĐĂNG (Góc phải trên)
          Positioned(
            top: 50,
            right: 20,
            child: TextButton(
              onPressed: _isUploading ? null : _submitStory,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: _isUploading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Đăng', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),

          // 5. THANH CHỌN MÀU (Góc trái dưới)
          Positioned(
            bottom: 30,
            left: 20,
            child: Container(
              height: 40,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  const Icon(Icons.palette, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  // Nút chuyển màu
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        // Cycle qua các màu
                        _selectedStyleIndex = (_selectedStyleIndex + 1) % StoryStyleHelper.styles.length;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Text('Đổi màu', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 5),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
