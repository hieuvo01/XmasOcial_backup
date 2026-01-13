// File: lib/screens/social/social_main_screen.dart

import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

// Import các tab và service
import 'tabs/feed_tab.dart';
import 'tabs/friends_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/notifications_tab.dart';
import 'tabs/menu_tab.dart';
import 'reels_screen.dart';

import '../../services/notification_service.dart';
import '../../services/navigation_service.dart';

class SocialMainScreen extends StatefulWidget {
  const SocialMainScreen({super.key});

  @override
  State<SocialMainScreen> createState() => _SocialMainScreenState();
}

class _SocialMainScreenState extends State<SocialMainScreen> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _animationController;
  late final Animation<Offset> _offsetAnimation;

  int _currentIndex = 0;
  late PageController _pageController;

  // Biến lưu reference service để clean up an toàn
  NavigationService? _navigationService;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Lưu reference service ngay từ đầu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _navigationService = Provider.of<NavigationService>(context, listen: false);
        _navigationService?.pageController = _pageController;
      }
    });

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 1.1),
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    // 👇 FIX LỖI CRASH Ở ĐÂY:
    // 1. Không dùng addPostFrameCallback trong dispose.
    // 2. Không dùng context trong dispose.
    // 3. Dùng biến _navigationService đã lưu để gán null.
    if (_navigationService != null) {
      _navigationService!.pageController = null;
    }

    _scrollController.dispose();
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // --- HÀM XỬ LÝ CUỘN (ĐÃ FIX LẠI LOGIC) ---
  bool _handleScrollNotification(ScrollNotification notification) {
    bool canHideTabBar = (_currentIndex == 0 || _currentIndex == 1 || _currentIndex == 3);

    if (!canHideTabBar) return false;

    if (notification.depth > 1) return false;

    if (notification is ScrollUpdateNotification) {
      if (notification.scrollDelta != null && notification.scrollDelta!.abs() < 2.0) return false;

      final metrics = notification.metrics;

      if (metrics.pixels <= 10 || metrics.pixels >= metrics.maxScrollExtent - 10) {
        if (_animationController.isCompleted) {
          _animationController.reverse();
        }
        return false;
      }

      if (notification.scrollDelta! > 0) {
        if (!_animationController.isCompleted) {
          _animationController.forward();
        }
      }
      else if (notification.scrollDelta! < 0) {
        if (!_animationController.isDismissed) {
          _animationController.reverse();
        }
      }
    }
    return false;
  }

  void _onTabTapped(int index) {
    _pageController.jumpToPage(index);
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });

    if (_animationController.status != AnimationStatus.dismissed) {
      _animationController.reverse();
    }
  }

  BottomNavigationBarItem _buildTabIcon(IconData icon, String label, {bool isReels = false}) {
    return BottomNavigationBarItem(
        icon: Icon(icon, size: isReels ? 30 : 28),
        label: label
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReelsTab = _currentIndex == 2;

    // --- LẤY MÀU TỪ THEME CHO DARK MODE ---
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Màu nền Scaffold: Nếu là Reels thì Đen, còn lại theo Theme
    final scaffoldBgColor = isReelsTab
        ? Colors.black
        : Theme.of(context).scaffoldBackgroundColor;

    // Màu nền Thanh Bar: Nếu là Reels thì đen mờ, còn lại là màu Card mờ (Trắng hoặc Xám đậm)
    final navBarBgColor = isReelsTab
        ? Colors.black.withOpacity(0.6)
        : (isDark ? const Color(0xFF242526).withOpacity(0.9) : Colors.white.withOpacity(0.9));

    // Màu viền trên Thanh Bar
    final navBarBorderColor = isReelsTab
        ? Colors.white10
        : Theme.of(context).dividerColor;

    return CupertinoPageScaffold(
      backgroundColor: scaffoldBgColor,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                FeedTab(scrollController: _scrollController),
                FriendsTab(scrollController: _scrollController),
                const ReelsScreen(),
                ProfileTab(scrollController: _scrollController),
                const NotificationsTab(),
                const MenuTab(),
              ],
            ),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: _offsetAnimation,
                child: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: Consumer<NotificationService>(
                      builder: (context, notificationService, child) {
                        return CupertinoTabBar(
                          currentIndex: _currentIndex,
                          onTap: _onTabTapped,
                          // Màu icon khi không chọn
                          inactiveColor: isReelsTab ? Colors.white60 : Colors.grey,
                          // Màu icon khi chọn
                          activeColor: isReelsTab ? Colors.white : CupertinoColors.activeBlue,

                          // Màu nền động theo theme
                          backgroundColor: navBarBgColor,

                          border: Border(
                              top: BorderSide(
                                  color: navBarBorderColor,
                                  width: 0.3
                              )
                          ),
                          items: <BottomNavigationBarItem>[
                            _buildTabIcon(_currentIndex == 0 ? CupertinoIcons.house_alt_fill : CupertinoIcons.house_alt, 'Bảng tin'),
                            _buildTabIcon(_currentIndex == 1 ? CupertinoIcons.person_2_fill : CupertinoIcons.person_2, 'Bạn bè'),
                            _buildTabIcon(_currentIndex == 2 ? CupertinoIcons.play_circle_fill : CupertinoIcons.play_circle, 'Reels', isReels: true),
                            _buildTabIcon(_currentIndex == 3 ? CupertinoIcons.person_crop_circle_fill : CupertinoIcons.person_crop_circle, 'Cá nhân'),
                            BottomNavigationBarItem(
                              label: 'Thông báo',
                              icon: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Icon(_currentIndex == 4 ? CupertinoIcons.bell_solid : CupertinoIcons.bell, size: 28),
                                  if (notificationService.unreadCount > 0)
                                    Positioned(
                                      top: -2, right: -6,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                        child: Text(
                                          '${notificationService.unreadCount}',
                                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            _buildTabIcon(CupertinoIcons.line_horizontal_3, 'Menu'),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
