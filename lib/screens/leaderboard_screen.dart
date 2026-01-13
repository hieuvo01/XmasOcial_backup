// File: lib/screens/leaderboard_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Để format ngày tháng (nhớ thêm intl vào pubspec.yaml nếu chưa có)
import '../../services/game_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 3 Tabs tương ứng với 3 gameId mà backend bro đã định nghĩa
    // Lưu ý: Tên gameId phải khớp với lúc bro submitScore (vd: 'snake', 'brick_breaker', '2048')
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Nền tối sang trọng
      appBar: AppBar(
        title: const Text("BẢNG XẾP HẠNG 🏆", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          indicatorWeight: 3,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          tabs: const [
            Tab(text: "SNAKE 🐍"),
            Tab(text: "BRICK 🧱"),
            Tab(text: "2048 🔢"),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF121212), Color(0xFF1E1E2C)],
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: const [
            LeaderboardList(gameId: 'snake'),
            LeaderboardList(gameId: 'brick_breaker'),
            LeaderboardList(gameId: '2048'),
          ],
        ),
      ),
    );
  }
}

class LeaderboardList extends StatefulWidget {
  final String gameId;
  const LeaderboardList({super.key, required this.gameId});

  @override
  State<LeaderboardList> createState() => _LeaderboardListState();
}

class _LeaderboardListState extends State<LeaderboardList> with AutomaticKeepAliveClientMixin {
  late Future<List<dynamic>> _leaderboardFuture;

  // Giữ trạng thái tab để không bị load lại khi chuyển tab
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _leaderboardFuture = Provider.of<GameService>(context, listen: false)
          .fetchLeaderboard(widget.gameId);
    });
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return "";
    try {
      final date = DateTime.parse(isoString);
      return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal()); // Cần package:intl
    } catch (e) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Cần thiết cho AutomaticKeepAliveClientMixin

    return FutureBuilder<List<dynamic>>(
      future: _leaderboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.amber));
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off, color: Colors.redAccent, size: 50),
                const SizedBox(height: 10),
                const Text("Không thể tải dữ liệu", style: TextStyle(color: Colors.white70)),
                TextButton(
                  onPressed: _refresh,
                  child: const Text("Thử lại", style: TextStyle(color: Colors.amber)),
                )
              ],
            ),
          );
        }

        final data = snapshot.data ?? [];

        if (data.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events_outlined, size: 80, color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 10),
                const Text("Chưa có cao thủ nào!", style: TextStyle(color: Colors.white54, fontSize: 18)),
                const SizedBox(height: 5),
                const Text("Hãy là người đầu tiên đua Top.", style: TextStyle(color: Colors.white30)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: Colors.amber,
          backgroundColor: const Color(0xFF2C2C3E),
          onRefresh: () async => _refresh(),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: data.length,
            separatorBuilder: (ctx, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = data[index];
              final username = item['username'] ?? 'Ẩn danh';
              final score = item['score'] ?? 0;
              final dateStr = _formatDate(item['createdAt']);

              // --- LOGIC GIAO DIỆN TOP 3 ---
              Color cardColor = const Color(0xFF2C2C3E); // Màu mặc định
              Color textColor = Colors.white;
              Widget? rankWidget;
              double elevation = 2;

              if (index == 0) {
                // TOP 1 🥇
                cardColor = const Color(0xFFFFD700).withOpacity(0.2); // Vàng
                textColor = const Color(0xFFFFD700);
                rankWidget = const Text("🥇", style: TextStyle(fontSize: 24));
              } else if (index == 1) {
                // TOP 2 🥈
                cardColor = const Color(0xFFC0C0C0).withOpacity(0.2); // Bạc
                textColor = const Color(0xFFC0C0C0);
                rankWidget = const Text("🥈", style: TextStyle(fontSize: 24));
              } else if (index == 2) {
                // TOP 3 🥉
                cardColor = const Color(0xFFCD7F32).withOpacity(0.2); // Đồng
                textColor = const Color(0xFFCD7F32);
                rankWidget = const Text("🥉", style: TextStyle(fontSize: 24));
              } else {
                // Các hạng khác
                rankWidget = CircleAvatar(
                  backgroundColor: Colors.white10,
                  radius: 14,
                  child: Text("${index + 1}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF252535),
                  borderRadius: BorderRadius.circular(15),
                  border: index < 3 ? Border.all(color: textColor.withOpacity(0.5), width: 1) : null,
                  boxShadow: index == 0 ? [
                    BoxShadow(color: Colors.amber.withOpacity(0.1), blurRadius: 10, spreadRadius: 1)
                  ] : [],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: SizedBox(
                    width: 40,
                    child: Center(child: rankWidget),
                  ),
                  title: Text(
                    username,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text(
                    dateStr,
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: index < 3 ? textColor.withOpacity(0.2) : Colors.white10,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "$score",
                      style: TextStyle(
                        color: index < 3 ? textColor : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
