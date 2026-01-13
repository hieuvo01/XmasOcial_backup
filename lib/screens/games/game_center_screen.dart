// File: lib/screens/games/game_center_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_maps/screens/games/recycle/recycle_game_main.dart';
import 'package:flutter_maps/services/game_service.dart';
import 'package:provider/provider.dart';
import '../leaderboard_screen.dart';
import 'chess_screen.dart';
import 'flappy_bird_screen.dart';
import 'tic_tac_toe_screen.dart';
import 'sudoku_screen.dart';
import 'game_2048_screen.dart';
import 'quiz_screen.dart';
import 'memory_match_screen.dart';
import 'snake_screen.dart';
import 'minesweeper_screen.dart';
import 'bau_cua_screen.dart';
import 'brick_breaker_screen.dart';
import 'rubik_screen.dart';

class GameCenterScreen extends StatefulWidget {
  const GameCenterScreen({super.key});

  @override
  State<GameCenterScreen> createState() => _GameCenterScreenState();
}

class _GameCenterScreenState extends State<GameCenterScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey[900] : Colors.grey[100];
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final accentColor = isDark ? Colors.cyanAccent : Colors.indigoAccent;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          "Game Center",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 24,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code_scanner, color: accentColor),
            tooltip: "Nhập mã phòng",
            onPressed: () => _showJoinRoomDialog(context),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Header Hero
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentColor, accentColor.withOpacity(0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.sports_esports, size: 40, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Chào mừng!",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Chơi cùng bạn bè hoặc solo",
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Grid Games - Đã thêm hết các game thiếu
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildListDelegate([
                _buildGameCard(
                  context,
                  title: "Bảng Xếp Hạng",
                  emoji: "🏆",
                  color: Colors.amber,
                  isDark: isDark,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
                  isHot: true,
                ),
                _buildGameCard(
                  context,
                  title: "Cờ Caro",
                  emoji: "❌⭕",
                  color: Colors.blueAccent,
                  isDark: isDark,
                  onTap: () => _handleGameTap(context, 'tictactoe', (data) => const TicTacToeScreen()),
                ),
                _buildGameCard(
                  context,
                  title: "RECYCLE",
                  emoji: "❤️️",
                  color: Colors.lightGreen,
                  isDark: isDark,
                  onTap: () => _handleGameTap(context, 'recycle', (data) => const RecycleGameScreen()),
                ),
                _buildGameCard(
                  context,
                  title: "Cờ Vua",
                  emoji: "♟️",
                  color: Colors.brown,
                  isDark: isDark,
                  onTap: () => _handleGameTap(context, 'chess', (data) => ChessScreen(savedData: data)),
                ),
                _buildGameCard(
                  context,
                  title: "Bầu Cua",
                  emoji: "🎲",
                  color: Colors.deepOrange,
                  isDark: isDark,
                  onTap: () => _handleGameTap(context, 'baucua', (data) => const BauCuaScreen()),
                  isNew: true,
                ),
                _buildGameCard(
                  context,
                  title: "Rắn Săn Mồi",
                  emoji: "🐍",
                  color: Colors.teal,
                  isDark: isDark,
                  onTap: () => _handleGameTap(context, 'snake', (data) => const SnakeScreen()),
                ),
                _buildGameCard(
                  context,
                  title: "2048",
                  emoji: "🔢",
                  color: Colors.purpleAccent,
                  isDark: isDark,
                  onTap: () => _handleGameTap(context, '2048', (data) => const Game2048Screen()),
                ),
                _buildGameCard(
                  context,
                  title: "Phá Gạch",
                  emoji: "🧱",
                  color: Colors.cyan,
                  isDark: isDark,
                  onTap: () => _handleGameTap(context, 'brickbreaker', (data) => const BrickBreakerGameScreen()),
                ),
                _buildGameCard(
                  context,
                  title: "Sudoku",
                  emoji: "🧠",
                  color: Colors.orangeAccent,
                  isDark: isDark,
                  onTap: () => _handleGameTap(context, 'sudoku', (data) => SudokuScreen(savedData: data)),
                ),
                _buildGameCard(
                  context,
                  title: "Dò Mìn",
                  emoji: "💣",
                  color: Colors.redAccent,
                  isDark: isDark,
                  onTap: () => _handleGameTap(context, 'minesweeper', (data) => const MinesweeperScreen()),
                ),
                _buildGameCard(
                  context,
                  title: "Flappy Bird",
                  emoji: "🐦",
                  color: Colors.blue,
                  isDark: isDark,
                  onTap: () => _handleGameTap(context, 'flappybird', (data) => const FlappyBirdScreen()),
                ),
                _buildGameCard(
                  context,
                  title: "Đố Vui",
                  emoji: "❓",
                  color: Colors.green,
                  isDark: isDark,
                  onTap: () => _handleGameTap(context, 'quiz', (data) => const QuizScreen()),
                ),
                _buildGameCard(
                  context,
                  title: "Lật Hình",
                  emoji: "🃏",
                  color: Colors.pinkAccent,
                  isDark: isDark,
                  onTap: () => _handleGameTap(context, 'memory', (data) => const MemoryMatchScreen()),
                ),
                _buildGameCard(
                  context,
                  title: "Rubik 3D",
                  emoji: "🧊",
                  color: Colors.deepPurpleAccent,
                  isDark: isDark,
                  onTap: () => _handleGameTap(context, 'rubik', (data) => const RubikScreen()),
                ),

              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard(
      BuildContext context, {
        required String title,
        required String emoji,
        required Color color,
        required bool isDark,
        required VoidCallback onTap,
        bool isHot = false,
        bool isNew = false,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.9, end: 1.0),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 8),
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: color.withOpacity(0.6),
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 48),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // Badge Hot/New
              if (isHot || isNew)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isHot ? Colors.redAccent : Colors.greenAccent,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: Text(
                      isHot ? "HOT" : "NEW",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleGameTap(BuildContext context, String gameId, Widget Function(Map<String, dynamic>? savedData) gameBuilder) async {
    final gameService = Provider.of<GameService>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    final savedData = await gameService.loadGameState(gameId);
    if (context.mounted) Navigator.pop(context);

    if (savedData != null && context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Tiếp tục chơi?"),
          content: const Text("Bro có ván game đang chơi dở. Muốn chơi tiếp hay chơi mới?"),
          actions: [
            TextButton(
              child: const Text("Chơi mới", style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.pop(ctx);
                await gameService.clearGameState(gameId);
                if (context.mounted) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => gameBuilder(null)));
                }
              },
            ),
            ElevatedButton(
              child: const Text("Chơi tiếp"),
              onPressed: () {
                Navigator.pop(ctx);
                if (context.mounted) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => gameBuilder(savedData)));
                }
              },
            ),
          ],
        ),
      );
    } else if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => gameBuilder(null)));
    }
  }

  void _showJoinRoomDialog(BuildContext context) {
    final TextEditingController _roomController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Tham gia phòng Game"),
        content: TextField(
          controller: _roomController,
          decoration: const InputDecoration(
            labelText: "Nhập mã phòng (Room ID)",
            hintText: "VD: room_caro_12345",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Đang kết nối tới phòng: ${_roomController.text}...")),
              );
            },
            child: const Text("Vào ngay"),
          ),
        ],
      ),
    );
  }
}