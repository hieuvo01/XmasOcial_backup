// File: lib/screens/games/chess_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Dùng từ khóa 'hide Color' để chặn xung đột tên với màu sắc Flutter
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import 'package:chess/chess.dart' as chess_lib;

import '../../services/game_service.dart';
import '../../services/message_service.dart'; // Import socket service

enum ChessLevel { easy, medium, hard }

class ChessScreen extends StatefulWidget {
  final Map<String, dynamic>? savedData;

  // Tham số Online
  final String? roomId;
  final bool isOnline;
  final bool isHost; // Host cầm Trắng (White), Guest cầm Đen (Black)
  final String? inviteMessageId;

  const ChessScreen({
    super.key,
    this.savedData,
    this.roomId,
    this.isOnline = false,
    this.isHost = true,
    this.inviteMessageId,
  });

  @override
  State<ChessScreen> createState() => _ChessScreenState();
}

class _ChessScreenState extends State<ChessScreen> {
  late ChessBoardController controller;
  chess_lib.Chess gameLogic = chess_lib.Chess();

  // Offline Variables
  bool isAiThinking = false;
  ChessLevel _currentLevel = ChessLevel.easy;

  // Online Variables
  bool _canMove = true;
  PlayerColor _myColor = PlayerColor.white;

  @override
  void initState() {
    super.initState();
    controller = ChessBoardController();

    if (widget.isOnline) {
      _setupOnlineGame();
    } else {
      _setupOfflineGame();
    }
  }

  // --- SETUP ONLINE ---
  void _setupOnlineGame() {
    _myColor = widget.isHost ? PlayerColor.white : PlayerColor.black;
    _canMove = widget.isHost;

    final socket = Provider.of<MessageService>(context, listen: false).socket;

    if (socket != null) {
      print("🔌 [Chess] Đang join vào room: ${widget.roomId}");
      socket.emit('join_game_room', widget.roomId);

      // 1. Nhận nước đi của đối thủ
      socket.on('opponent_move', (data) {
        print("📩 [Chess] Đã nhận được nước đi: $data");

        if (mounted) {
          String fen = data['fen'];
          controller.loadFen(fen);
          gameLogic.load(fen);

          setState(() {
            _canMove = true; // Mở khóa bàn cờ
            _checkGameOver(); // Check xem mình có bị thua không
          });
        }
      });

      // 2. Đối thủ thoát
      socket.on('opponent_left', (_) {
        if (mounted) _showOpponentLeftDialog();
      });
    }
  }


  // --- SETUP OFFLINE ---
  void _setupOfflineGame() {
    if (widget.savedData != null) {
      if (widget.savedData!['level'] != null) {
        try {
          _currentLevel = ChessLevel.values[widget.savedData!['level']];
        } catch (_) {}
      }
      if (widget.savedData!['fen'] != null) {
        try {
          String savedFen = widget.savedData!['fen'];
          controller.loadFen(savedFen);
          gameLogic.load(savedFen);
        } catch (_) {}
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDifficultyDialog();
      });
    }
  }

  @override
  void dispose() {
    // Nếu chơi Offline thì lưu game lần cuối khi thoát
    if (!widget.isOnline) {
      _saveGame();
    }
    // Nếu chơi Online thì báo rời phòng
    else if (widget.roomId != null) {
      final socket = Provider.of<MessageService>(context, listen: false).socket;
      socket?.emit('leave_game_room', widget.roomId);
      socket?.off('opponent_move');
      socket?.off('opponent_left');
    }
    super.dispose();
  }

  // --- HÀM LƯU GAME ---
  void _saveGame() {
    // Chỉ lưu khi chơi với bot
    if (widget.isOnline) return;

    // Không lưu bàn cờ trống
    if (gameLogic.fen == chess_lib.Chess.DEFAULT_POSITION) return;

    final gameService = Provider.of<GameService>(context, listen: false);

    // Nếu game đã kết thúc (thắng/thua/hòa) thì xóa save để lần sau chơi mới
    if (gameLogic.in_checkmate || gameLogic.in_draw || gameLogic.in_stalemate) {
      gameService.clearGameState('chess');
      return;
    }

    // Lưu trạng thái hiện tại
    final data = {
      'fen': controller.getFen(),
      'level': _currentLevel.index
    };
    gameService.saveGameState('chess', data);
  }

// --- LOGIC DI CHUYỂN ---
  void _onUserMove() {
    // 1. Cập nhật logic bàn cờ cục bộ từ UI
    gameLogic.load(controller.getFen());

    // 2. QUAN TRỌNG: Gửi nước đi cho đối thủ TRƯỚC (nếu đang online)
    if (widget.isOnline) {
      _handleOnlineMove();
    } else {
      // Offline: Lưu game ngay sau khi người đi (để lỡ tắt app đột ngột)
      _saveGame();

      // Nếu offline thì cho AI đi
      if (!gameLogic.game_over) {
        _makeAiMove();
      }
    }

    // 3. Sau khi gửi xong mới kiểm tra thắng thua để hiện thông báo
    _checkGameOver();
  }

  void _handleOnlineMove() {
    setState(() => _canMove = false); // Khóa bàn cờ đợi đối thủ

    // Gửi FEN mới lên server
    final socket = Provider.of<MessageService>(context, listen: false).socket;
    socket?.emit('make_game_move', {
      'roomId': widget.roomId,
      'moveData': {
        'fen': controller.getFen(),
      }
    });
  }

  // --- AI LOGIC (CHỈ DÙNG CHO OFFLINE) ---
  void _makeAiMove() async {
    if (gameLogic.game_over) return;
    setState(() => isAiThinking = true);
    await Future.delayed(const Duration(milliseconds: 600));

    chess_lib.Move? bestMove;
    if (_currentLevel == ChessLevel.easy) {
      bestMove = _getRandomMove();
    } else {
      bestMove = _getGreedyMove();
    }

    if (!mounted) return;

    if (bestMove != null) {
      gameLogic.move(bestMove);
      controller.loadFen(gameLogic.fen);

      // Lưu game sau khi bot đi
      _saveGame();

      _checkGameOver();
    } else {
      // Fallback
      var fallback = _getRandomMove();
      if (fallback != null) {
        gameLogic.move(fallback);
        controller.loadFen(gameLogic.fen);

        // Lưu game sau khi bot đi (fallback)
        _saveGame();

        _checkGameOver();
      }
    }
    setState(() => isAiThinking = false);
  }

  chess_lib.Move? _getRandomMove() {
    final moves = gameLogic.moves();
    if (moves.isEmpty) return null;
    var randomMove = moves[Random().nextInt(moves.length)];
    gameLogic.move(randomMove);
    var moveObject = gameLogic.history.last.move;
    gameLogic.undo();
    return moveObject;
  }

  chess_lib.Move? _getGreedyMove() {
    final moves = gameLogic.moves();
    if (moves.isEmpty) return null;

    chess_lib.Move? bestMove;
    int maxScore = -9999;

    var movesList = List.from(moves);
    movesList.shuffle();

    for (var move in movesList) {
      gameLogic.move(move);
      var currentMoveObject = gameLogic.history.last.move;
      int score = _calculateMaterialScore();
      if (score > maxScore) {
        maxScore = score;
        bestMove = currentMoveObject;
      }
      gameLogic.undo();
    }
    return bestMove;
  }

  int _calculateMaterialScore() {
    String fenBoard = gameLogic.fen.split(' ')[0];
    int score = 0;
    for (int i = 0; i < fenBoard.length; i++) {
      String char = fenBoard[i];
      int val = 0;
      switch (char.toLowerCase()) {
        case 'p': val = 10; break;
        case 'n': val = 30; break;
        case 'b': val = 30; break;
        case 'r': val = 50; break;
        case 'q': val = 90; break;
        default: val = 0;
      }
      if (val > 0) {
        if (char == char.toLowerCase()) {
          score += val;
        } else {
          score -= val;
        }
      }
    }
    return score;
  }

  bool _checkGameOver() {
    // 👇 FIX: Dùng Provider
    final gameService = Provider.of<GameService>(context, listen: false);

    if (gameLogic.in_checkmate) {
      String winnerMsg;
      if (widget.isOnline) {
        // Nếu đang là lượt của White mà bị chiếu -> Black thắng
        bool whiteLost = (gameLogic.turn == chess_lib.Color.WHITE);
        bool iAmWhite = (_myColor == PlayerColor.white);

        if (whiteLost) {
          winnerMsg = iAmWhite ? "Bạn đã thua! 😢" : "Bạn đã thắng! 🎉";
        } else {
          winnerMsg = iAmWhite ? "Bạn đã thắng! 🎉" : "Bạn đã thua! 😢";
        }
      } else {
        winnerMsg = gameLogic.turn == chess_lib.Color.WHITE ? "Máy thắng" : "Bạn thắng";
        if (gameLogic.turn == chess_lib.Color.BLACK) {
          int score = _currentLevel == ChessLevel.easy ? 100 : 300;
          gameService.submitScore('chess', score);
        }
      }

      _showGameOverDialog("Chiếu tướng! $winnerMsg");
      if (!widget.isOnline) gameService.clearGameState('chess');
      return true;
    }
    else if (gameLogic.in_draw || gameLogic.in_stalemate || gameLogic.in_threefold_repetition) {
      _showGameOverDialog("Hòa cờ!");
      if (!widget.isOnline) {
        gameService.submitScore('chess', 50);
        gameService.clearGameState('chess');
      }
      return true;
    }
    return false;
  }

  void _resetGame() {
    // 👇 FIX: Dùng Provider
    final gameService = Provider.of<GameService>(context, listen: false);

    controller.resetBoard();
    gameLogic.reset();
    gameService.clearGameState('chess');
    WidgetsBinding.instance.addPostFrameCallback((_) => _showDifficultyDialog());
    setState(() {});
  }

  void _undoMove() {
    if (gameLogic.history.length < 2) return;
    gameLogic.undo();
    gameLogic.undo();
    controller.loadFen(gameLogic.fen);

    // Undo xong cũng save lại trạng thái mới
    if(!widget.isOnline) _saveGame();

    setState(() {});
  }

  // --- DIALOGS ---
  void _showGameOverDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Kết thúc"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Đóng Dialog
              if (widget.isOnline) {
                Navigator.pop(context); // Online: Thoát màn hình game
              } else {
                _resetGame(); // Offline: Reset chơi lại
              }
            },
            child: Text(widget.isOnline ? "Thoát" : "Ván mới"),
          )
        ],
      ),
    );
  }

  void _showOpponentLeftDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Đối thủ đã thoát"),
        content: const Text("Bạn đã thắng vì đối thủ bỏ cuộc!"),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("Về trang chủ"),
          ),
        ],
      ),
    );
  }

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
              _buildSimpleBtn(context, "Dễ (Random)", ChessLevel.easy, 0xFF4CAF50),
              const SizedBox(height: 10),
              _buildSimpleBtn(context, "Vừa (AI Ăn Quân)", ChessLevel.medium, 0xFF2196F3),
              const SizedBox(height: 10),
              _buildSimpleBtn(context, "Khó (Như Vừa)", ChessLevel.hard, 0xFFF44336),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSimpleBtn(BuildContext context, String label, ChessLevel level, int colorHex) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(colorHex),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: () {
          setState(() {
            _currentLevel = level;
          });
          Navigator.pop(context);
        },
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  String _getLevelName() {
    switch(_currentLevel) {
      case ChessLevel.easy: return "Dễ";
      case ChessLevel.medium: return "Vừa";
      case ChessLevel.hard: return "Khó";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
            widget.isOnline ? "Cờ Vua Online" : "Cờ Vua (${_getLevelName()})",
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          if (!widget.isOnline) ...[
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _showDifficultyDialog,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetGame,
            )
          ]
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),

          // --- INFO BAR: AI hoặc ONLINE STATUS ---
          if (widget.isOnline)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                    color: _canMove ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _canMove ? Colors.green : Colors.red)
                ),
                child: Text(
                  _canMove
                      ? "👉 Đến lượt bạn (${_myColor == PlayerColor.white ? 'Trắng' : 'Đen'})"
                      : "⏳ Đợi đối thủ...",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _canMove ? Colors.green : Colors.red
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: isAiThinking ? Border.all(color: Colors.red, width: 2) : null
              ),
              child: Row(
                children: [
                  const Icon(Icons.computer),
                  const SizedBox(width: 10),
                  Text(isAiThinking ? "Đang tính..." : "Máy (AI)"),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // --- BÀN CỜ ---
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: IgnorePointer(
                // Online: Khóa nếu chưa đến lượt. Offline: Khóa nếu AI đang nghĩ.
                ignoring: widget.isOnline ? !_canMove : isAiThinking,
                child: ChessBoard(
                  controller: controller,
                  boardColor: isDark ? BoardColor.brown : BoardColor.green,
                  // Online: Nếu là Host thì bàn cờ xoay về Trắng, Guest xoay về Đen
                  boardOrientation: widget.isOnline ? _myColor : PlayerColor.white,
                  enableUserMoves: true,
                  onMove: _onUserMove,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // --- PLAYER INFO (Chỉ hiện Offline) ---
          if (!widget.isOnline)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.person),
                      SizedBox(width: 10),
                      Text("Bạn (Trắng)"),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.undo),
                    onPressed: isAiThinking ? null : _undoMove,
                  )
                ],
              ),
            ),
        ],
      ),
    );
  }
}
