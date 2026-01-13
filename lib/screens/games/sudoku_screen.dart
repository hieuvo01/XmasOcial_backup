// File: lib/screens/games/sudoku_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // 👇 THÊM PROVIDER
import 'package:sudoku_dart/sudoku_dart.dart';
import 'package:flutter_maps/services/game_service.dart';

class SudokuScreen extends StatefulWidget {
  final Map<String, dynamic>? savedData;
  const SudokuScreen({super.key, this.savedData});

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> {
  Sudoku? _sudoku;
  List<int> _userAnswer = List.filled(81, -1);

  // THÊM: Biến lưu đáp án riêng biệt để dễ restore
  List<int> _solution = [];

  int? _selectedCellIndex;
  int _mistakes = 0;
  final int _maxMistakes = 3;
  Level _currentLevel = Level.easy;

  @override
  void initState() {
    super.initState();
    if (widget.savedData != null) {
      _restoreGame(widget.savedData!);
    } else {
      _newGame();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDifficultyDialog();
      });
    }
  }

  @override
  void dispose() {
    // Chỉ lưu nếu game chưa kết thúc
    if (_mistakes < _maxMistakes && _sudoku != null) {
      _saveGame();
    }
    super.dispose();
  }

  void _saveGame() {
    final data = {
      'puzzle': _sudoku!.puzzle,
      'solution': _solution, // Lưu biến solution riêng
      'userAnswer': _userAnswer,
      'mistakes': _mistakes,
      'levelIndex': _currentLevel.index,
    };
    // 👇 FIX: Dùng Provider
    Provider.of<GameService>(context, listen: false).saveGameState('sudoku', data);
  }

  void _restoreGame(Map<String, dynamic> data) {
    try {
      _currentLevel = Level.values[data['levelIndex'] ?? 0];
      _mistakes = data['mistakes'] ?? 0;
      _userAnswer = List<int>.from(data['userAnswer']);

      // 1. Khôi phục Solution vào biến riêng
      _solution = List<int>.from(data['solution']);

      // 2. Tái tạo Sudoku Object để hiển thị đề bài
      List<int> puzzle = List<int>.from(data['puzzle']);

      // Fix lỗi constructor: Chỉ truyền puzzle
      _sudoku = Sudoku(puzzle);

      setState(() {});
    } catch (e) {
      print("Lỗi restore: $e");
      _newGame();
    }
  }

  void _newGame() {
    _sudoku = Sudoku.generate(_currentLevel);

    // Lưu đáp án ra biến riêng ngay khi tạo game mới
    _solution = List<int>.from(_sudoku!.solution);

    _userAnswer = List.filled(81, -1);
    for (int i = 0; i < 81; i++) {
      if (_sudoku!.puzzle[i] != -1) {
        _userAnswer[i] = _sudoku!.puzzle[i];
      }
    }

    setState(() {
      _selectedCellIndex = null;
      _mistakes = 0;
    });
  }

  // ... (Phần UI _showDifficultyDialog và _buildLevelButton giữ nguyên) ...
  // Hộp thoại chọn độ khó
  void _showDifficultyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Chọn độ khó", textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLevelButton(context, "Dễ (Nhiều gợi ý)", Level.easy, Colors.green),
              const SizedBox(height: 10),
              _buildLevelButton(context, "Trung bình", Level.medium, Colors.blue),
              const SizedBox(height: 10),
              _buildLevelButton(context, "Khó", Level.hard, Colors.orange),
              const SizedBox(height: 10),
              _buildLevelButton(context, "Chuyên gia (Ít gợi ý)", Level.expert, Colors.red),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Đóng"),
            )
          ],
        );
      },
    );
  }

  Widget _buildLevelButton(BuildContext context, String label, Level level, Color color) {
    bool isSelected = _currentLevel == level;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: isSelected ? const BorderSide(color: Colors.white, width: 3) : null,
          elevation: isSelected ? 10 : 2,
        ),
        onPressed: () {
          setState(() {
            _currentLevel = level;
            _newGame();
          });
          Navigator.pop(context);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected) const Icon(Icons.check, size: 18),
            if (isSelected) const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _onNumberPadTap(int number) {
    if (_selectedCellIndex == null) return;

    if (_sudoku!.puzzle[_selectedCellIndex!] != -1) return;

    // SỬA: So sánh với _solution thay vì _sudoku!.solution
    if (_userAnswer[_selectedCellIndex!] == _solution[_selectedCellIndex!]) return;

    setState(() {
      _userAnswer[_selectedCellIndex!] = number;

      // SỬA: So sánh với _solution
      if (number != _solution[_selectedCellIndex!]) {
        _mistakes++;
      }
    });

    if (_mistakes >= _maxMistakes) {
      _showGameOverDialog();
    } else {
      _checkWinCondition();
    }
  }

  void _checkWinCondition() {
    bool isFull = !_userAnswer.contains(-1);
    if (isFull) {
      bool isCorrect = true;
      for (int i = 0; i < 81; i++) {
        // SỬA: So sánh với _solution
        if (_userAnswer[i] != _solution[i]) {
          isCorrect = false;
          break;
        }
      }
      if (isCorrect) {
        int baseScore = 0;
        switch(_currentLevel) {
          case Level.easy: baseScore = 100; break;
          case Level.medium: baseScore = 200; break;
          case Level.hard: baseScore = 300; break;
          case Level.expert: baseScore = 500; break;
        }
        int finalScore = baseScore - (_mistakes * 20);
        if (finalScore < 0) finalScore = 10;

        // 👇 FIX: Dùng Provider
        final gameService = Provider.of<GameService>(context, listen: false);
        gameService.submitScore('sudoku', finalScore);
        gameService.clearGameState('sudoku');

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text("Chiến thắng! 🏆"),
            content: Text("Bạn đã giải thành công Sudoku!\nĐiểm số: $finalScore"),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _newGame();
                  },
                  child: const Text("Chơi ván mới")
              )
            ],
          ),
        );
      }
    }
  }

  void _showGameOverDialog() {
    // 👇 FIX: Dùng Provider
    Provider.of<GameService>(context, listen: false).clearGameState('sudoku');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Thua cuộc 😞"),
        content: const Text("Bạn đã sai quá 3 lần!"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _newGame();
            },
            child: const Text("Thử lại"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final gridLineColor = isDark ? Colors.grey[600]! : Colors.black;

    if (_sudoku == null) {
      return Scaffold(backgroundColor: bgColor, body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Sudoku (${_getLevelName()})", style: TextStyle(color: textColor, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showDifficultyDialog,
            tooltip: "Đổi độ khó",
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0, left: 8.0),
              child: Text(
                "Lỗi: $_mistakes/$_maxMistakes",
                style: TextStyle(
                    color: _mistakes >= 2 ? Colors.red : textColor,
                    fontWeight: FontWeight.bold
                ),
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: gridLineColor, width: 2)),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 81,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 9),
                      itemBuilder: (context, index) {
                        int value = _userAnswer[index];
                        bool isGiven = _sudoku!.puzzle[index] != -1;
                        bool isSelected = _selectedCellIndex == index;
                        bool isWrong = false;

                        if (!isGiven && value != -1) {
                          // SỬA: So sánh với _solution
                          if (value != _solution[index]) isWrong = true;
                        }

                        int row = index ~/ 9;
                        int col = index % 9;

                        return GestureDetector(
                          onTap: () => setState(() => _selectedCellIndex = index),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.blue.withOpacity(0.3)
                                  : (isGiven ? (isDark ? Colors.grey[800] : Colors.grey[300]) : (isDark ? Colors.grey[900] : Colors.white)),
                              border: Border(
                                top: BorderSide(width: (row % 3 == 0) ? 2.0 : 0.5, color: gridLineColor),
                                left: BorderSide(width: (col % 3 == 0) ? 2.0 : 0.5, color: gridLineColor),
                                right: col == 8 ? BorderSide(width: 0.5, color: gridLineColor) : BorderSide.none,
                                bottom: row == 8 ? BorderSide(width: 0.5, color: gridLineColor) : BorderSide.none,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                value == -1 ? '' : value.toString(),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: isGiven ? FontWeight.bold : FontWeight.normal,
                                  color: isGiven
                                      ? (isDark ? Colors.white : Colors.black)
                                      : (isWrong ? Colors.red : Colors.blueAccent),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.only(bottom: 30),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ...List.generate(9, (index) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(18),
                      backgroundColor: isDark ? Colors.grey[800] : Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _onNumberPadTap(index + 1),
                    child: Text("${index + 1}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  );
                }),
                IconButton(
                  onPressed: () {
                    if (_selectedCellIndex != null &&
                        _sudoku!.puzzle[_selectedCellIndex!] == -1) {
                      setState(() => _userAnswer[_selectedCellIndex!] = -1);
                    }
                  },
                  icon: const Icon(Icons.backspace_outlined),
                  color: Colors.redAccent,
                  iconSize: 32,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getLevelName() {
    switch (_currentLevel) {
      case Level.easy: return "Dễ";
      case Level.medium: return "Vừa";
      case Level.hard: return "Khó";
      case Level.expert: return "Chuyên gia";
    }
  }
}
