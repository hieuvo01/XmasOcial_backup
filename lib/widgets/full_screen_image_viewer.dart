import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FullScreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int startIndex; // 🔥 ĐỔI TÊN TỪ initialIndex THÀNH startIndex
  final String tag;

  const FullScreenImageViewer({
    Key? key,
    required this.imageUrls,
    required this.startIndex, // 🔥 ĐỔI TÊN Ở ĐÂY
    required this.tag,
  }) : super(key: key);

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    // Gán giá trị bắt đầu
    _currentIndex = widget.startIndex;

    // Khởi tạo controller với startIndex truyền vào
    // Bây giờ vế trái (của PageController) và vế phải (của mình) đã khác tên nhau
    _pageController = PageController(
      initialPage: widget.startIndex,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Hero(
                    // Sử dụng startIndex để so sánh
                    tag: index == widget.startIndex ? widget.tag : 'media_item_$index',
                    child: Image.network(
                      widget.imageUrls[index],
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CupertinoActivityIndicator(color: Colors.white),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),

          // Nút đóng
          Positioned(
            top: 50.0,
            right: 15.0,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.xmark,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),

          // Chỉ số trang
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: 40.0,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${_currentIndex + 1} / ${widget.imageUrls.length}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}