// File: lib/screens/games/tic_tac_toe_screen.dart
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import '../../services/message_service.dart';
import '../../services/auth_service.dart';

class TicTacToeScreen extends StatefulWidget {
  // Thêm tham số hỗ trợ Online
  final String? roomId;
  final bool isOnline;
  final bool isHost;
  final String? inviteMessageId;

  const TicTacToeScreen({
    super.key,
    this.roomId,
    this.isOnline = false,
    this.isHost = true,
    this.inviteMessageId,
  });

  @override
  State<TicTacToeScreen> createState() => _TicTacToeScreenState();
}

class _TicTacToeScreenState extends State<TicTacToeScreen> {
  // Cấu hình
  int gridSize = 10;
  final int winCondition = 5;

  late List<String> board;
  bool isPlayerTurn = true; // Offline: true = X, false = O
  String winner = '';
  bool isDraw = false;
  bool isVsComputer = true;

  // Biến Online
  bool _canMove = true;
  String _mySymbol = 'X';

  // Biến hỗ trợ zoom/pan
  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();

    if (widget.isOnline) {
      // Nếu Online: Bắt buộc dùng bàn cờ 15x15 cho chuẩn thi đấu
      gridSize = 15;
      isVsComputer = false; // Tắt chế độ máy
      _setupOnlineGame();
    } else {
      // Offline mặc định 10x10
      gridSize = 10;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDifficultyDialog();
      });
    }

    _initBoard();
  }

  void _initBoard() {
    board = List.filled(gridSize * gridSize, '');
    isPlayerTurn = true;
    winner = '';
    isDraw = false;
    _transformationController.value = Matrix4.identity();
  }

  void _setupOnlineGame() {
    _mySymbol = widget.isHost ? 'X' : 'O';
    _canMove = widget.isHost; // Host đi trước

    final socket = Provider.of<MessageService>(context, listen: false).socket;

    if (socket != null) {
      // --- THÊM DÒNG NÀY ĐỂ JOIN VÀO ROOM ---
      print("🔌 Đang join vào room: ${widget.roomId}");
      socket.emit('join_game_room', widget.roomId);
      // ---------------------------------------

      // 1. Nhận nước đi đối thủ
      socket.on('opponent_move', (data) {
        if (mounted) {
          print("Nhận nước đi: $data"); // Log ra để check
          int index = data['index'];
          String symbol = data['symbol'];

          setState(() {
            board[index] = symbol;
            _checkOnlineWinner(symbol);

            if (winner == '' && !isDraw) {
              _canMove = true; // Mở khóa để mình đánh
            }
          });
        }
      });

      // 2. Đối thủ thoát
      socket.on('opponent_left', (_) {
        if (mounted) _showOpponentLeftDialog();
      });
    }
  }


  // --- UI DIALOGS ---
  void _showDifficultyDialog() {
    if (widget.isOnline) return; // Online không được chỉnh size

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Chọn kích thước bàn cờ", textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLevelButton(ctx, "Nhỏ (5x5)", 5, Colors.green),
              const SizedBox(height: 10),
              _buildLevelButton(ctx, "Vừa (10x10)", 10, Colors.orange),
              const SizedBox(height: 10),
              _buildLevelButton(ctx, "Lớn (15x15)", 15, Colors.red),
              const SizedBox(height: 10),
              const Text("(Luật: 5 con liên tiếp là thắng)", style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.grey)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLevelButton(BuildContext ctx, String label, int size, Color color) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: () {
          setState(() {
            gridSize = size;
            _initBoard();
          });
          Navigator.pop(ctx);
        },
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- XỬ LÝ TAP ---
  void _handleTap(int index) {
    if (board[index] != '' || winner != '') return;

    // Logic Online Check
    if (widget.isOnline && !_canMove) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Chưa đến lượt của bạn bro ơi!"), duration: Duration(milliseconds: 500)),
      );
      return;
    }

    setState(() {
      if (widget.isOnline) {
        // --- ONLINE MOVE ---
        board[index] = _mySymbol;
        _canMove = false; // Khóa lại

        // Gửi Socket
        final socket = Provider.of<MessageService>(context, listen: false).socket;
        socket?.emit('make_game_move', {
          'roomId': widget.roomId,
          'moveData': {'index': index, 'symbol': _mySymbol}
        });

        _checkOnlineWinner(_mySymbol);

      } else {
        // --- OFFLINE MOVE ---
        board[index] = 'X';
        isPlayerTurn = false;

        if (_checkWinner(index, 'X')) {
          winner = 'X';
        } else if (!board.contains('')) {
          isDraw = true;
        }

        if (winner == '' && !isDraw && isVsComputer) {
          Future.delayed(const Duration(milliseconds: 300), _computerMove);
        }
      }
    });
  }

  // --- AI LOGIC (Chỉ chạy Offline) ---
  void _computerMove() {
    if (widget.isOnline || winner != '' || isDraw) return;

    int bestScore = -1;
    int bestMove = -1;
    List<int> availableMoves = [];

    for (int i = 0; i < board.length; i++) {
      if (board[i] == '') availableMoves.add(i);
    }

    if (availableMoves.isEmpty) return;

    // Nếu bàn trống, đánh giữa
    if (availableMoves.length == board.length) {
      int center = (gridSize * gridSize) ~/ 2;
      _makeMove(center, 'O');
      return;
    }

    for (int index in availableMoves) {
      int attackScore = _calculatePoint(index, 'O');
      int defenseScore = _calculatePoint(index, 'X');
      int currentScore = attackScore + defenseScore;

      if (currentScore > bestScore) {
        bestScore = currentScore;
        bestMove = index;
      }
    }

    if (bestMove != -1) {
      _makeMove(bestMove, 'O');
    } else {
      final random = Random();
      _makeMove(availableMoves[random.nextInt(availableMoves.length)], 'O');
    }
  }

  void _makeMove(int index, String player) {
    setState(() {
      board[index] = player;
      isPlayerTurn = true;
      if (_checkWinner(index, player)) {
        winner = player;
      } else if (!board.contains('')) {
        isDraw = true;
      }
    });
  }

  int _calculatePoint(int index, String player) {
    int totalScore = 0;
    int row = index ~/ gridSize;
    int col = index % gridSize;
    List<List<int>> directions = [[0, 1], [1, 0], [1, 1], [1, -1]];

    for (var dir in directions) {
      int count = 1;
      int openEnds = 0;
      int dr = dir[0];
      int dc = dir[1];

      for (int i = 1; i <= 4; i++) {
        int r = row + dr * i;
        int c = col + dc * i;
        if (r >= 0 && r < gridSize && c >= 0 && c < gridSize) {
          if (board[r * gridSize + c] == player) count++;
          else if (board[r * gridSize + c] == '') { openEnds++; break; }
          else break;
        }
      }

      for (int i = 1; i <= 4; i++) {
        int r = row - dr * i;
        int c = col - dc * i;
        if (r >= 0 && r < gridSize && c >= 0 && c < gridSize) {
          if (board[r * gridSize + c] == player) count++;
          else if (board[r * gridSize + c] == '') { openEnds++; break; }
          else break;
        }
      }

      if (count >= 5) return 100000000;
      if (count == 4) {
        if (openEnds == 2) return 1000000;
        if (openEnds == 1) return 50000;
      }
      if (count == 3) {
        if (openEnds == 2) return 10000;
        if (openEnds == 1) return 500;
      }
      if (count == 2) {
        if (openEnds == 2) return 100;
        if (openEnds == 1) return 10;
      }
      totalScore += count;
    }
    return totalScore;
  }

  // --- CHECK WINNER ---
  bool _checkWinner(int lastMoveIndex, String player) {
    int row = lastMoveIndex ~/ gridSize;
    int col = lastMoveIndex % gridSize;
    List<List<int>> directions = [[0, 1], [1, 0], [1, 1], [1, -1]];

    for (var dir in directions) {
      int count = 1;
      int dr = dir[0];
      int dc = dir[1];

      for (int i = 1; i < winCondition; i++) {
        int r = row + dr * i;
        int c = col + dc * i;
        if (r < 0 || r >= gridSize || c < 0 || c >= gridSize) break;
        if (board[r * gridSize + c] == player) count++; else break;
      }
      for (int i = 1; i < winCondition; i++) {
        int r = row - dr * i;
        int c = col - dc * i;
        if (r < 0 || r >= gridSize || c < 0 || c >= gridSize) break;
        if (board[r * gridSize + c] == player) count++; else break;
      }
      if (count >= winCondition) return true;
    }
    return false;
  }

  // Wrapper check winner cho Online để hiện popup đúng
  void _checkOnlineWinner(String playerToCheck) {
    // Để check winner online, ta cần quét toàn bàn cờ hoặc lưu index cuối
    // Ở đây để đơn giản ta quét lại bàn cờ vì hàm check cũ cần lastMoveIndex
    // Cách tốt nhất: loop qua tất cả ô đã đánh của playerToCheck

    // Tuy nhiên, logic tối ưu hơn là tái sử dụng _checkWinner.
    // Ta sẽ tạm thời loop check các ô vừa đánh (hoặc toàn bộ ô của player đó)
    // Để code gọn, ta dùng cách đơn giản:

    bool hasWinner = false;
    for(int i=0; i< board.length; i++) {
      if (board[i] == playerToCheck) {
        if (_checkWinner(i, playerToCheck)) {
          hasWinner = true;
          break;
        }
      }
    }

    if (hasWinner) {
      winner = playerToCheck;
      _showEndGameDialog(
          title: winner == _mySymbol ? "CHÚC MỪNG! BẠN THẮNG 🎉" : "TIẾC QUÁ! BẠN THUA RỒI 😢"
      );
    } else if (!board.contains('')) {
      isDraw = true;
      _showEndGameDialog(title: "HÒA NHAU!");
    }
  }

  // --- DIALOGS ---
  void _showEndGameDialog({required String title}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Kết thúc"),
        content: Text(title, style: const TextStyle(fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Thoát game
            },
            child: const Text("Thoát"),
          ),
          if (!widget.isOnline)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _initBoard());
              },
              child: const Text("Chơi lại"),
            ),
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

  @override
  void dispose() {
    if (widget.isOnline && widget.roomId != null) {
      final socket = Provider.of<MessageService>(context, listen: false).socket;
      // --- THÊM ĐOẠN NÀY ---
      // Nếu mình là Host thoát, hoặc cả 2 thoát (tùy logic bro muốn)
      // Ở đây mình gửi tín hiệu kết thúc luôn cho chắc
      if (widget.inviteMessageId != null) {
        socket?.emit('game_finished', {
          'roomId': widget.roomId,
          'gameType': 'caro',
          'inviteMessageId': widget.inviteMessageId
        });
      }
      socket?.emit('leave_game_room', widget.roomId);
      socket?.off('opponent_move');
      socket?.off('opponent_left');
    }
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final cardColor = isDark ? Colors.grey[850] : Colors.white;

    // Tính toán kích thước
    const double cellSize = 40.0;
    double boardWidth = cellSize * gridSize;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
            widget.isOnline ? "Caro Online" : "Caro ($gridSize x $gridSize)",
            style: TextStyle(color: textColor)
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          if (!widget.isOnline) // Chỉ hiện nút setting khi offline
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _showDifficultyDialog,
            )
        ],
      ),
      body: Column(
        children: [
          // Header Status
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: widget.isOnline
                ? Container( // UI Trạng thái Online
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                  color: _canMove ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _canMove ? Colors.green : Colors.red)
              ),
              child: Text(
                _canMove ? "👉 Đến lượt bạn ($_mySymbol)" : "⏳ Đợi đối thủ...",
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold,
                    color: _canMove ? Colors.green : Colors.red
                ),
              ),
            )
                : Text( // UI Trạng thái Offline
              winner != ''
                  ? '🏆 ${winner == 'X' ? 'BẠN THẮNG!' : 'MÁY THẮNG!'} 🏆'
                  : isDraw ? 'HÒA!' : 'Lượt: ${isPlayerTurn ? "Bạn (X)" : "Máy (O)"}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: winner != '' ? Colors.green : textColor,
              ),
            ),
          ),

          const Divider(),

          // BÀN CỜ (ZOOM & PAN)
          Expanded(
            child: Center(
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: 0.5,
                maxScale: 3.0,
                boundaryMargin: const EdgeInsets.all(100),
                child: Container(
                  width: boardWidth,
                  height: boardWidth,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black : Colors.grey[200],
                    border: Border.all(color: isDark ? Colors.grey[700]! : Colors.black, width: 2),
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: gridSize * gridSize,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridSize,
                      crossAxisSpacing: 1,
                      mainAxisSpacing: 1,
                    ),
                    itemBuilder: (context, index) {
                      String val = board[index];
                      return GestureDetector(
                        onTap: () => _handleTap(index), // Tap xử lý cả Online/Offline
                        child: Container(
                          color: cardColor,
                          child: Center(
                            child: val == ''
                                ? null
                                : Text(
                              val,
                              style: TextStyle(
                                fontSize: cellSize * 0.6,
                                fontWeight: FontWeight.bold,
                                color: val == 'X' ? Colors.blue : Colors.red,
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

          // Footer (Chỉ hiện khi Offline)
          if (!widget.isOnline) ...[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Dùng 2 ngón tay để phóng to/thu nhỏ bàn cờ",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _initBoard()),
                    icon: const Icon(Icons.refresh),
                    label: const Text("Chơi lại"),
                  ),
                  const SizedBox(width: 20),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        isVsComputer = !isVsComputer;
                        _initBoard();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isVsComputer ? "Chế độ: Đấu với Máy" : "Chế độ: 2 Người chơi"))
                      );
                    },
                    icon: Icon(isVsComputer ? Icons.people : Icons.computer),
                    label: Text(isVsComputer ? "Đấu bạn bè" : "Đấu với máy"),
                  ),
                ],
              ),
            )
          ]
        ],
      ),
    );
  }
}
