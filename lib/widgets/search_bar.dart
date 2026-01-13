// lib/widgets/search_bar.dart

import 'package:flutter/material.dart';

class MapSearchBar extends StatelessWidget {
  final void Function(String) onChanged;
  final void Function(String) onSubmitted;
  final TextEditingController? controller;
  final String? hintText;
  // Thêm callback cho nút micro
  final VoidCallback? onMicPressed;

  const MapSearchBar({
    super.key,
    required this.onChanged,
    required this.onSubmitted,
    this.controller,
    this.hintText,
    this.onMicPressed, // Thêm vào constructor
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4.0,
      borderRadius: BorderRadius.circular(30.0),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hintText ?? 'Tìm kiếm hoặc ra lệnh...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
          // Thêm nút Micro vào đây
          suffixIcon: IconButton(
            icon: const Icon(Icons.mic, color: Colors.blueAccent),
            onPressed: onMicPressed,
            tooltip: 'Tìm kiếm bằng giọng nói',
          ),
        ),
      ),
    );
  }
}
