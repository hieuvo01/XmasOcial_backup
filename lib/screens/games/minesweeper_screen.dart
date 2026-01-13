// File: lib/screens/games/minesweeper_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class MinesweeperScreen extends StatefulWidget {
  const MinesweeperScreen({super.key});

  @override
  State<MinesweeperScreen> createState() => _MinesweeperScreenState();
}

class Cell {
  int row, col;
  bool isMine;
  bool isRevealed;
  bool isFlagged;
  int neighborMines;

  Cell({
    required this.row,
    required this.col,
    this.isMine = false,
    this.isRevealed = false,
    this.isFlagged = false,
    this.neighborMines = 0,
  });
}

class _MinesweeperScreenState extends State<MinesweeperScreen> {
  final int rows = 12;
  final int cols = 9;
  final int totalMines = 15;

  late List<List<Cell>> grid;
  bool isGameOver = false;
  bool isWon = false;
  int flagsLeft = 0;
  Timer? _timer;
  int _secondsElapsed = 0;

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startNewGame() {
    _timer?.cancel();
    setState(() {
      isGameOver = false;
      isWon = false;
      flagsLeft = totalMines;
      _secondsElapsed = 0;

      // 1. Tạo Grid rỗng
      grid = List.generate(rows, (r) {
        return List.generate(cols, (c) {
          return Cell(row: r, col: c);
        });
      });

      // 2. Rải mìn ngẫu nhiên
      int placedMines = 0;
      Random random = Random();
      while (placedMines < totalMines) {
        int r = random.nextInt(rows);
        int c = random.nextInt(cols);
        if (!grid[r][c].isMine) {
          grid[r][c].isMine = true;
          placedMines++;
        }
      }

      // 3. Tính số mìn xung quanh cho mỗi ô
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          if (!grid[r][c].isMine) {
            grid[r][c].neighborMines = _countNeighbors(r, c);
          }
        }
      }
    });

    // Bắt đầu đếm giờ
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isGameOver && !isWon) {
        setState(() => _secondsElapsed++);
      }
    });
  }

  int _countNeighbors(int r, int c) {
    int count = 0;
    for (int i = -1; i <= 1; i++) {
      for (int j = -1; j <= 1; j++) {
        int nr = r + i;
        int nc = c + j;
        if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
          if (grid[nr][nc].isMine) count++;
        }
      }
    }
    return count;
  }

  void _revealCell(int r, int c) {
    if (isGameOver || isWon || grid[r][c].isRevealed || grid[r][c].isFlagged) return;

    setState(() {
      grid[r][c].isRevealed = true;

      if (grid[r][c].isMine) {
        // === BÙM! THUA ===
        isGameOver = true;
        _timer?.cancel();
        _revealAllMines();
        _showEndDialog(false);
      } else if (grid[r][c].neighborMines == 0) {
        // Nếu ô trống (số 0), mở loang ra xung quanh
        _floodFill(r, c);
      }

      _checkWin();
    });
  }

  void _floodFill(int r, int c) {
    for (int i = -1; i <= 1; i++) {
      for (int j = -1; j <= 1; j++) {
        int nr = r + i;
        int nc = c + j;
        if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
          if (!grid[nr][nc].isRevealed && !grid[nr][nc].isMine) {
            grid[nr][nc].isRevealed = true;
            // Nếu ô mới mở cũng là 0 thì đệ quy tiếp
            if (grid[nr][nc].neighborMines == 0) {
              _floodFill(nr, nc);
            }
          }
        }
      }
    }
  }

  void _toggleFlag(int r, int c) {
    if (isGameOver || isWon || grid[r][c].isRevealed) return;
    setState(() {
      grid[r][c].isFlagged = !grid[r][c].isFlagged;
      flagsLeft += grid[r][c].isFlagged ? -1 : 1;
    });
  }

  void _revealAllMines() {
    for (var row in grid) {
      for (var cell in row) {
        if (cell.isMine) cell.isRevealed = true;
      }
    }
  }

  void _checkWin() {
    int unrevealedSafeCells = 0;
    for (var row in grid) {
      for (var cell in row) {
        if (!cell.isMine && !cell.isRevealed) unrevealedSafeCells++;
      }
    }
    if (unrevealedSafeCells == 0) {
      isWon = true;
      _timer?.cancel();
      _showEndDialog(true);
    }
  }

  void _showEndDialog(bool won) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(won ? "Chiến thắng! 😎" : "Nổ rồi! 💥"),
        content: Text(won ? "Bạn mất $_secondsElapsed giây." : "Chúc may mắn lần sau!"),
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

  Color _getNumberColor(int n, bool isDark) {
    switch (n) {
      case 1: return Colors.blue;
      case 2: return Colors.green;
      case 3: return Colors.red;
      case 4: return Colors.purple;
      case 5: return Colors.orange;
      default: return isDark ? Colors.white : Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final cellUnrevealedColor = isDark ? Colors.grey[800] : Colors.blueGrey[100];
    final cellRevealedColor = isDark ? Colors.grey[900] : Colors.grey[300];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Dò Mìn", style: TextStyle(color: textColor)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _startNewGame)],
      ),
      body: Column(
        children: [
          // Header Status
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            color: isDark ? Colors.grey[900] : Colors.blue[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [const Icon(Icons.flag, color: Colors.red), const SizedBox(width: 8), Text("$flagsLeft", style: TextStyle(fontSize: 20, color: textColor))]),
                Row(children: [const Icon(Icons.timer, color: Colors.blue), const SizedBox(width: 8), Text("$_secondsElapsed", style: TextStyle(fontSize: 20, color: textColor))]),
              ],
            ),
          ),

          // Grid
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal, // Cho phép cuộn ngang nếu màn hình nhỏ
                child: SizedBox(
                  width: cols * 40.0, // Fixed width
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      childAspectRatio: 1.0,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                    ),
                    itemCount: rows * cols,
                    itemBuilder: (context, index) {
                      int r = index ~/ cols;
                      int c = index % cols;
                      Cell cell = grid[r][c];

                      return GestureDetector(
                        onTap: () => _revealCell(r, c),
                        onLongPress: () => _toggleFlag(r, c),
                        child: Container(
                          decoration: BoxDecoration(
                            color: cell.isRevealed
                                ? (cell.isMine ? Colors.redAccent : cellRevealedColor)
                                : cellUnrevealedColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: _buildCellContent(cell, isDark),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("Giữ (Long press) để cắm cờ 🚩", style: TextStyle(color: Colors.grey)),
          )
        ],
      ),
    );
  }

  Widget _buildCellContent(Cell cell, bool isDark) {
    if (!cell.isRevealed) {
      if (cell.isFlagged) return const Icon(Icons.flag, color: Colors.red, size: 20);
      return const SizedBox();
    }
    if (cell.isMine) {
      return const Icon(Icons.adb, color: Colors.black, size: 20); // Icon Boom
    }
    if (cell.neighborMines > 0) {
      return Text(
        "${cell.neighborMines}",
        style: TextStyle(
          color: _getNumberColor(cell.neighborMines, isDark),
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      );
    }
    return const SizedBox();
  }
}
