// File: lib/screens/games/game_2048_screen.dart

import 'package:flutter/material.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import '../../services/game_service.dart';

class Game2048Screen extends StatefulWidget {
  final Map<String, dynamic>? savedData;
  const Game2048Screen({super.key, this.savedData});

  @override
  State<Game2048Screen> createState() => _Game2048ScreenState();
}

class _Game2048ScreenState extends State<Game2048Screen> {
  List<int> board = List.filled(16, 0);
  int score = 0;
  bool isGameOver = false;
  bool isWon = false;

  // Biến để giữ GameService (dùng khi cần thiết, nhưng chủ yếu ta dùng context trong flow chính)
  late GameService _gameService;

  @override
  void initState() {
    super.initState();
    // Khởi tạo board rỗng trước
    _initBoardOnly();

    // Sau khi frame đầu tiên render xong thì luôn Start New Game
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 👇 SỬA Ở ĐÂY: Luôn gọi _startNewGame, bỏ qua widget.savedData
      _startNewGame(isInit: true);

      // Nếu muốn chắc ăn hơn, gọi lệnh xóa save cũ trên server luôn (tùy chọn)
      // Provider.of<GameService>(context, listen: false).clearGameState('2048');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _gameService = Provider.of<GameService>(context, listen: false);
  }

  // ⚠️ QUAN TRỌNG: Không gọi save trong dispose để tránh lỗi "unsafe ancestor".
  // Thay vào đó ta đã save sau mỗi nước đi và dùng PopScope để cảnh báo.
  @override
  void dispose() {
    super.dispose();
  }

  // --- LOGIC KHỞI TẠO CƠ BẢN ---
  void _initBoardOnly() {
    board = List.filled(16, 0);
    score = 0;
    isGameOver = false;
    isWon = false;
  }

  // --- LOGIC SAVE & LOAD ---
  void _saveGameInternal() {
    // Không lưu bàn cờ trống trơn hoặc đã thua
    if (board.every((e) => e == 0) || isGameOver) return;

    // Lưu game dùng biến _gameService đã được cache
    _gameService.saveGameState('2048', {
      'board': board,
      'score': score,
      'isWon': isWon,
      'isGameOver': isGameOver,
    });
  }

  // Helper để gọi save (cho gọn code)
  void _saveGame() {
    _saveGameInternal();
  }

  void _restoreGame(Map<String, dynamic> data) {
    try {
      setState(() {
        board = List<int>.from(data['board']);
        score = data['score'] ?? 0;
        isWon = data['isWon'] ?? false;
        isGameOver = data['isGameOver'] ?? false;
      });
    } catch (e) {
      print("Lỗi restore 2048: $e");
      _startNewGame(isInit: true);
    }
  }

  // --- LOGIC GAME LOOP ---
  void _startNewGame({bool isInit = false}) {
    // Nếu chơi lại (không phải lần đầu vào) thì xóa save cũ trên server
    if (!isInit) {
      _gameService.clearGameState('2048');
    }

    setState(() {
      board = List.filled(16, 0);
      score = 0;
      isGameOver = false;
      isWon = false;
      _spawnNumber();
      _spawnNumber();
    });

    // Lưu trạng thái khởi tạo mới ngay lập tức
    if (!isInit) _saveGame();
  }

  void _spawnNumber() {
    List<int> empty = [];
    for (int i = 0; i < 16; i++) {
      if (board[i] == 0) empty.add(i);
    }
    if (empty.isNotEmpty) {
      board[empty[Random().nextInt(empty.length)]] =
      Random().nextInt(10) == 0 ? 4 : 2;
    }
  }

  // --- LOGIC DI CHUYỂN & GỘP SỐ ---
  List<int> _mergeLine(List<int> line) {
    List<int> newLine = line.where((e) => e != 0).toList();
    for (int i = 0; i < newLine.length - 1; i++) {
      if (newLine[i] == newLine[i + 1]) {
        newLine[i] *= 2;
        score += newLine[i];
        newLine[i + 1] = 0;
        if (newLine[i] == 2048 && !isWon) {
          isWon = true;
          _saveGame();
          WidgetsBinding.instance.addPostFrameCallback((_) => _showWinDialog());
        }
      }
    }
    newLine = newLine.where((e) => e != 0).toList();
    while (newLine.length < 4) {
      newLine.add(0);
    }
    return newLine;
  }

  void _moveLeft() {
    bool hasChanged = false;
    for (int i = 0; i < 4; i++) {
      List<int> row = [
        board[i * 4],
        board[i * 4 + 1],
        board[i * 4 + 2],
        board[i * 4 + 3]
      ];
      List<int> newRow = _mergeLine(row);
      for (int j = 0; j < 4; j++) {
        if (board[i * 4 + j] != newRow[j]) hasChanged = true;
        board[i * 4 + j] = newRow[j];
      }
    }
    if (hasChanged) _afterMove();
  }

  void _moveRight() {
    bool hasChanged = false;
    for (int i = 0; i < 4; i++) {
      List<int> row = [
        board[i * 4 + 3],
        board[i * 4 + 2],
        board[i * 4 + 1],
        board[i * 4]
      ];
      List<int> newRow = _mergeLine(row);
      for (int j = 0; j < 4; j++) {
        if (board[i * 4 + (3 - j)] != newRow[j]) hasChanged = true;
        board[i * 4 + (3 - j)] = newRow[j];
      }
    }
    if (hasChanged) _afterMove();
  }

  void _moveUp() {
    bool hasChanged = false;
    for (int i = 0; i < 4; i++) {
      List<int> col = [board[i], board[i + 4], board[i + 8], board[i + 12]];
      List<int> newCol = _mergeLine(col);
      for (int j = 0; j < 4; j++) {
        if (board[i + j * 4] != newCol[j]) hasChanged = true;
        board[i + j * 4] = newCol[j];
      }
    }
    if (hasChanged) _afterMove();
  }

  void _moveDown() {
    bool hasChanged = false;
    for (int i = 0; i < 4; i++) {
      List<int> col = [board[i + 12], board[i + 8], board[i + 4], board[i]];
      List<int> newCol = _mergeLine(col);
      for (int j = 0; j < 4; j++) {
        if (board[i + (3 - j) * 4] != newCol[j]) hasChanged = true;
        board[i + (3 - j) * 4] = newCol[j];
      }
    }
    if (hasChanged) _afterMove();
  }

  void _afterMove() {
    _spawnNumber();
    if (_checkGameOver()) {
      setState(() => isGameOver = true);
      _showGameOverDialog();
    } else {
      setState(() {});
      _saveGame(); // 🔥 Lưu game sau mỗi nước đi
    }
  }

  bool _checkGameOver() {
    if (board.contains(0)) return false;
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        int index = i * 4 + j;
        if (j < 3 && board[index] == board[index + 1]) return false;
        if (i < 3 && board[index] == board[index + 4]) return false;
      }
    }
    return true;
  }

  // --- DIALOGS ---
  void _showGameOverDialog() {
    _gameService.submitScore('2048', score);
    _gameService.clearGameState('2048');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Game Over! 😞"),
        content: Text("Điểm số của bạn: $score"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startNewGame();
            },
            child: const Text("Chơi lại"),
          )
        ],
      ),
    );
  }

  void _showWinDialog() {
    _gameService.submitScore('2048', score);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("YOU WIN! 🎉"),
        content: const Text("Bạn đã đạt được ô 2048!"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Tiếp tục chơi"),
          )
        ],
      ),
    );
  }

  // Hàm hiển thị hộp thoại xác nhận thoát
  Future<bool?> _showExitDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Thoát game?"),
        content: const Text(
          "Nếu thoát game bây giờ, tiến trình chơi game của bạn sẽ bị mất.\nBạn có muốn thoát không?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Ở lại"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Thoát", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- COLORS ---
  Color _getTileColor(int value, bool isDark) {
    if (isDark) {
      switch (value) {
        case 2: return Colors.grey[800]!;
        case 4: return Colors.grey[700]!;
        case 8: return Colors.orange[900]!;
        case 16: return Colors.orange[800]!;
        case 32: return Colors.deepOrange[900]!;
        case 64: return Colors.red[900]!;
        case 128: return Colors.yellow[800]!;
        case 256: return Colors.yellow[700]!;
        default: return value > 2048 ? Colors.black : Colors.purple[900]!;
      }
    }
    switch (value) {
      case 2: return const Color(0xFFEEE4DA);
      case 4: return const Color(0xFFEDE0C8);
      case 8: return const Color(0xFFF2B179);
      case 16: return const Color(0xFFF59563);
      case 32: return const Color(0xFFF67C5F);
      case 64: return const Color(0xFFF65E3B);
      case 128: return const Color(0xFFEDCF72);
      case 256: return const Color(0xFFEDCC61);
      case 512: return const Color(0xFFEDC850);
      case 1024: return const Color(0xFFEDC53F);
      case 2048: return const Color(0xFFEDC22E);
      default: return const Color(0xFF3C3A32);
    }
  }

  Color _getNumberColor(int value, bool isDark) {
    if (isDark) return Colors.white;
    return (value == 2 || value == 4) ? const Color(0xFF776E65) : Colors.white;
  }

  // --- BUILD UI ---
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final boardColor = isDark ? Colors.grey[900] : const Color(0xFFBBADA0);

    // 🔥 Bọc Scaffold bằng PopScope để chặn thoát đột ngột
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final bool shouldPop = await _showExitDialog() ?? false;
        if (context.mounted && shouldPop) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: Text("2048",
              style:
              TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
          // Sửa nút Back trên AppBar cho đồng bộ
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () async {
              final bool shouldPop = await _showExitDialog() ?? false;
              if (context.mounted && shouldPop) {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _startNewGame(),
              tooltip: "Chơi lại",
            )
          ],
        ),
        body: GestureDetector(
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity! < -200) _moveUp();
            else if (details.primaryVelocity! > 200) _moveDown();
          },
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity! < -200) _moveLeft();
            else if (details.primaryVelocity! > 200) _moveRight();
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Bảng điểm
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: boardColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text("ĐIỂM SỐ",
                        style: TextStyle(
                            color: isDark
                                ? Colors.grey[400]
                                : const Color(0xFFEEE4DA),
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    Text("$score",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Bàn cờ
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: boardColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 16,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8),
                    itemBuilder: (context, index) {
                      int val = board[index];
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        decoration: BoxDecoration(
                          color: val == 0
                              ? (isDark
                              ? Colors.grey[850]!.withOpacity(0.5)
                              : const Color(0xFFCDC1B4))
                              : _getTileColor(val, isDark),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: val == 0
                              ? null
                              : Text(
                            '$val',
                            style: TextStyle(
                                fontSize: val > 512 ? 24 : 32,
                                fontWeight: FontWeight.bold,
                                color: _getNumberColor(val, isDark)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 30),
              Text(
                "Vuốt Lên / Xuống / Trái / Phải để chơi",
                style: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
