// lib/utils/debouncer.dart
import 'dart:async';
import 'package:flutter/material.dart';

class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    // Nếu có một timer cũ, hủy nó đi
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
    }
    // Tạo một timer mới
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void dispose() {
    _timer?.cancel();
  }
}
