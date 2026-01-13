// Dán toàn bộ code này vào file: lib/services/navigation_service.dart

import 'package:flutter/material.dart';

class NavigationService extends ChangeNotifier {
  // PageController sẽ được gán từ SocialMainScreen
  PageController? pageController;

  /// Điều hướng đến một trang (tab) cụ thể
  void navigateToPage(int pageIndex) {
    if (pageController != null && pageController!.hasClients) {
      pageController!.animateToPage(
        pageIndex,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }
}
