// lib/home_screen.dart
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bản đồ AI'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'Màn hình bản đồ sẽ ở đây!',
          style: TextStyle(fontSize: 20),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Thêm chức năng cho nút này, ví dụ: lấy vị trí hiện tại
        },
        child: const Icon(Icons.location_searching),
      ),
    );
  }
}
