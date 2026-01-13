// File: lib/screens/games/snake_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/game_service.dart';
import '../../services/message_service.dart';
import '../leaderboard_screen.dart';

// --- ENUM CÁC LOẠI ITEM MỞ RỘNG ---
enum ItemType {
  normal,       // 🍎 Táo đỏ (+1 điểm)
  doublePoint,  // 🍏 Táo xanh (+2 điểm)
  speedUp,      // ⚡ Tăng tốc (Khó hơn)
  slowDown,     // 🐌 Giảm tốc (Dễ hơn)
  cutTail,      // ✂️ Cắt đuôi (Rắn ngắn lại)
  ghost,        // 👻 Đi xuyên tường
  mystery       // 🎁 Hộp bí ẩn (Hên xui)
}

class SnakeScreen extends StatefulWidget {
  final Map<String, dynamic>? savedData;
  final String? roomId;
  final bool isOnline;
  final bool isHost;

  const SnakeScreen({
    super.key,
    this.savedData,
    this.roomId,
    this.isOnline = false,
    this.isHost = true,
  });

  @override
  State<SnakeScreen> createState() => _SnakeScreenState();
}

enum Direction { up, down, left, right }

class _SnakeScreenState extends State<SnakeScreen> {
  // Biến lưu reference Provider để dùng trong dispose an toàn
  late GameService _gameServiceRef;

  // Theme
  late Color currentGridColor1;
  late Color currentGridColor2;
  final List<Map<String, Color>> themes = [
    {'c1': const Color(0xFF2E2E2E), 'c2': const Color(0xFF252525)}, // Dark Theme
    {'c1': const Color(0xFF1A1A2E), 'c2': const Color(0xFF16213E)}, // Midnight Blue
    {'c1': const Color(0xFF2C3E50), 'c2': const Color(0xFF34495E)}, // Deep Sea
  ];

  final int squaresPerRow = 20;
  final int squaresPerCol = 30;
  late int totalSquares;
  late AudioPlayer _bgmPlayer;
  bool isMusicPlaying = false;

  // Game State
  List<int> snakePos1 = [];
  List<int> snakePos2 = [];
  List<int> foodPositions = []; // 🔄 THAY ĐỔI: List positions cho nhiều items
  Map<int, ItemType> foodTypes = {}; // 🔄 THAY ĐỔI: Type cho từng item

  Direction dir1 = Direction.down;
  Direction dir2 = Direction.up;
  Direction lastMoveDir1 = Direction.down;
  Direction lastMoveDir2 = Direction.up;

  bool isPlaying = false;
  int score1 = 0;
  int score2 = 0;

  Timer? gameLoopTimer;
  int baseSpeed = 250;
  int currentSpeed = 250;
  Timer? buffTimer;

  // Trạng thái Buff đặc biệt
  bool isGhostMode = false; // Đi xuyên tường

  final String assetPath = 'assets/images/snake';

  @override
  void initState() {
    super.initState();
    _bgmPlayer = AudioPlayer();
    _randomizeTheme();
    totalSquares = squaresPerRow * squaresPerCol;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playRandomBackgroundMusic();

      // 🔥 FIX LOGIC LOAD GAME:
      // Nếu chơi Offline VÀ không có dữ liệu truyền vào từ bên ngoài
      if (!widget.isOnline && widget.savedData == null) {
        _loadSavedGameFromServer(); // Tự động gọi API lấy save
      }
    });

    if (widget.isOnline) {
      _setupOnlineGame();
      _initOnlineBoard();
    } else {
      // Nếu có dữ liệu truyền vào từ Menu thì dùng luôn
      if (widget.savedData != null && widget.savedData!.isNotEmpty) {
        print("📥 Có savedData từ menu, đang restore...");
        _restoreGame(widget.savedData!);
      } else {
        // Chưa init vội, chờ _loadSavedGameFromServer chạy xong
        // Nếu không có save trên server thì nó sẽ tự init sau
      }
    }
  }

  Future<void> _loadSavedGameFromServer() async {
    try {
      print("📡 Đang tự động tìm file save trên server...");
      final gameService = Provider.of<GameService>(context, listen: false);

      // Gọi hàm loadGameState từ service (Bro đảm bảo service có hàm này nha)
      // Hàm này trả về Map<String, dynamic>?
      final savedData = await gameService.loadGameState('snake');

      if (savedData != null && savedData.isNotEmpty) {
        print("✅ Tìm thấy save trên server! Đang khôi phục...");
        if (mounted) {
          _restoreGame(savedData);
        }
      } else {
        print("⚠️ Không có save nào trên server. Tạo game mới.");
        if (mounted && snakePos1.isEmpty) {
          _initGame();
          setState(() {}); // Cập nhật UI để vẽ rắn mới
        }
      }
    } catch (e) {
      print("❌ Lỗi khi tự tải save: $e");
      if (mounted && snakePos1.isEmpty) {
        _initGame();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _gameServiceRef = Provider.of<GameService>(context, listen: false);
  }

  @override
  void dispose() {
    gameLoopTimer?.cancel();
    buffTimer?.cancel();
    _bgmPlayer.stop();
    _bgmPlayer.dispose();

    // Lưu game nếu đang chơi dở (Offline)
    if (!widget.isOnline && snakePos1.isNotEmpty) {
      _saveGameSafe();
    }
    super.dispose();
  }

  void _saveGameSafe() {
    // Chỉ lưu nếu rắn còn sống và dài hơn 3 đốt
    if (snakePos1.length > 3) {
      _gameServiceRef.saveGameState('snake', {
        'snakePos': snakePos1,
        'foodPositions': foodPositions, // 🔄 Lưu list mới
        'foodTypes': foodTypes.map((key, value) => MapEntry(key.toString(), value.index)), // Lưu map dưới dạng string key
        'score': score1,
        'speed': currentSpeed,
        'direction': dir1.index,
        'isGhostMode': isGhostMode, // Lưu trạng thái xuyên tường
      });
    }
  }

  void _randomizeTheme() {
    final random = Random();
    final theme = themes[random.nextInt(themes.length)];
    currentGridColor1 = theme['c1']!;
    currentGridColor2 = theme['c2']!;
  }

  void _playRandomBackgroundMusic() async {
    try {
      int trackId = Random().nextInt(5) + 1;
      String trackPath = 'sounds/sound_pack/$trackId.mp3';
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(0.3);
      await _bgmPlayer.play(AssetSource(trackPath)); // 🔥 FIX: Sử dụng play trực tiếp với AssetSource để tự play
      if (mounted) setState(() => isMusicPlaying = true);
    } catch (e) {
      print("❌ Lỗi chơi nhạc: $e"); // Log lỗi để debug
    }
  }

  void _toggleMusic() {
    if (isMusicPlaying) {
      _bgmPlayer.pause();
    } else {
      _bgmPlayer.resume();
    }
    setState(() => isMusicPlaying = !isMusicPlaying);
  }

  // --- SETUP ONLINE ---
  void _setupOnlineGame() {
    final socket = Provider.of<MessageService>(context, listen: false).socket;
    if (socket == null) return;

    socket.off('opponent_input');
    socket.off('game_state_update');
    socket.off('game_over');

    if (widget.isHost) {
      socket.on('opponent_input', (data) {
        if (!mounted) return;
        Direction oppDir = Direction.values[data['dir']];
        _handleOpponentChangeDir(oppDir);
      });
    }

    if (!widget.isHost) {
      socket.on('game_state_update', (data) {
        if (!mounted) return;
        try {
          setState(() {
            if (!isPlaying) isPlaying = true;
            if (data['snake1'] != null) snakePos1 = (data['snake1'] as List).cast<int>();
            if (data['snake2'] != null) snakePos2 = (data['snake2'] as List).cast<int>();
            if (data['foodPositions'] != null) foodPositions = (data['foodPositions'] as List).cast<int>(); // 🔄 Sync list
            if (data['foodTypes'] != null) {
              foodTypes = {};
              (data['foodTypes'] as Map).forEach((key, value) => foodTypes[int.parse(key)] = ItemType.values[value]);
            }
            if (data['score1'] != null) score1 = data['score1'] as int;
            if (data['score2'] != null) score2 = data['score2'] as int;
            if (data['dir1'] != null) dir1 = Direction.values[data['dir1'] as int];
            if (data['dir2'] != null) dir2 = Direction.values[data['dir2'] as int];
          });
        } catch (e) { print("Error parse data: $e"); }
      });

      socket.on('game_over', (data) {
        if (!mounted) return;
        _handleOnlineGameOver(data['winner'] ?? 'draw');
      });
    }
  }

  void _handleOpponentChangeDir(Direction newDir) {
    if (lastMoveDir2 == Direction.down && newDir == Direction.up) return;
    if (lastMoveDir2 == Direction.up && newDir == Direction.down) return;
    if (lastMoveDir2 == Direction.left && newDir == Direction.right) return;
    if (lastMoveDir2 == Direction.right && newDir == Direction.left) return;
    dir2 = newDir;
  }

  // --- INIT GAME ---
  void _initGame() {
    int start = (squaresPerRow * squaresPerCol) ~/ 2;
    snakePos1 = [start, start + squaresPerRow, start + squaresPerRow * 2];
    snakePos2 = [];
    dir1 = Direction.up;
    lastMoveDir1 = Direction.up;
    score1 = 0;
    baseSpeed = 250;
    currentSpeed = baseSpeed;
    isGhostMode = false;
    foodPositions.clear();
    foodTypes.clear();
    _generateFoods(); // 🔄 Sinh nhiều items
  }

  void _initOnlineBoard() {
    int start1 = totalSquares - squaresPerRow * 2 - 5;
    snakePos1 = [start1, start1 + squaresPerRow, start1 + squaresPerRow * 2];
    dir1 = Direction.up;
    lastMoveDir1 = Direction.up;

    int start2 = squaresPerRow * 2 + 5;
    snakePos2 = [start2, start2 - squaresPerRow, start2 - squaresPerRow * 2];
    dir2 = Direction.down;
    lastMoveDir2 = Direction.down;

    score1 = 0;
    score2 = 0;
    baseSpeed = 250;
    currentSpeed = baseSpeed;
    isGhostMode = false;
    foodPositions.clear();
    foodTypes.clear();
    _generateFoods(); // 🔄 Sinh nhiều items
  }

  void _startGame() {
    // Nếu là Online Guest thì không được tự start
    if (widget.isOnline && !widget.isHost) return;

    // 🔥 FIX LOGIC TIẾP TỤC GAME:
    // 1. Nếu chơi Online -> Luôn reset
    // 2. Nếu chơi Offline VÀ chưa có rắn (snakePos1 rỗng) -> Reset (Chơi mới)
    // 3. Nếu chơi Offline VÀ đang có rắn -> KHÔNG RESET (Tiếp tục)

    if (widget.isOnline || snakePos1.isEmpty) {
      // Đây là trường hợp chơi mới
      if (widget.isOnline) {
        // Online giữ nguyên logic cũ
      } else {
        _initGame(); // Chỉ gọi init khi thực sự muốn chơi mới
        currentSpeed = baseSpeed; // Reset tốc độ
      }
    }
    // Ngược lại, nếu snakePos1 đang có dữ liệu -> Bỏ qua _initGame() để giữ nguyên hiện trường

    setState(() => isPlaying = true);
    gameLoopTimer?.cancel();

    if (widget.isOnline) {
      _sendGameStateToGuest();
    }

    // Bắt đầu chạy Timer
    _scheduleNextTick();
  }

  void _scheduleNextTick() {
    gameLoopTimer?.cancel();

    // 🔥 FIX: Check mounted
    if (!mounted) return;

    gameLoopTimer = Timer(Duration(milliseconds: currentSpeed), () {
      if (mounted && isPlaying) {
        _updateGameLoop();
        _scheduleNextTick();
      }
    });
  }

  void _updateGameLoop() {
    // 🔥 FIX: Nếu màn hình tắt rồi thì đừng tính toán gì nữa
    if (!mounted) {
      gameLoopTimer?.cancel();
      return;
    }

    setState(() {
      _moveSnake(1);
      if (widget.isOnline) {
        _moveSnake(2);
        _checkMultiplayerCollisions();
        _sendGameStateToGuest();
      }
    });
  }

  void _moveSnake(int snakeId) {
    List<int> currentSnake = snakeId == 1 ? snakePos1 : snakePos2;
    Direction currentDir = snakeId == 1 ? dir1 : dir2;

    if (snakeId == 1) lastMoveDir1 = currentDir; else lastMoveDir2 = currentDir;

    int newHead = currentSnake.first;
    switch (currentDir) {
      case Direction.down: newHead += squaresPerRow; break;
      case Direction.up: newHead -= squaresPerRow; break;
      case Direction.right: newHead += 1; break;
      case Direction.left: newHead -= 1; break;
    }

    // Xử lý xuyên tường (Ghost Mode)
    if (isGhostMode && snakeId == 1) {
      if (newHead < 0) newHead += totalSquares; // Dưới lên trên
      else if (newHead >= totalSquares) newHead -= totalSquares; // Trên xuống dưới
      if (currentDir == Direction.right && newHead % squaresPerRow == 0) newHead -= squaresPerRow;
      if (currentDir == Direction.left && newHead % squaresPerRow == squaresPerRow - 1) newHead += squaresPerRow;
    }

    if (!widget.isOnline && snakeId == 1) {
      bool wallHit = _isWallCollision(newHead, currentDir);

      if (!isGhostMode && wallHit) {
        _gameOver();
        return;
      }

      if (snakePos1.contains(newHead)) {
        _gameOver();
        return;
      }

      if (newHead < 0) newHead = totalSquares + newHead;
      if (newHead >= totalSquares) newHead = newHead - totalSquares;
    }

    currentSnake.insert(0, newHead);

    // 🔄 THAY ĐỔI: Check ăn bất kỳ food nào trong list
    bool ateFood = false;
    ItemType? eatenType;
    int? eatenPos;

    for (int pos in foodPositions) {
      if (newHead == pos) {
        ateFood = true;
        eatenType = foodTypes[pos];
        eatenPos = pos;
        break;
      }
    }

    if (ateFood) {
      int points = 1;
      if (eatenType == ItemType.doublePoint) points = 2;

      if (snakeId == 1) score1 += points; else score2 += points;

      _activateItemEffect(snakeId, eatenType!);
      foodPositions.remove(eatenPos);
      foodTypes.remove(eatenPos);
      _generateFoods(); // 🔄 Sinh 2 cái mới sau khi ăn

      if (baseSpeed > 100) baseSpeed -= 2;

      if (buffTimer == null || !buffTimer!.isActive) {
        currentSpeed = baseSpeed;
      }
    } else {
      currentSnake.removeLast();
    }
  }

  void _activateItemEffect(int snakeId, ItemType itemType) {
    buffTimer?.cancel();

    // Reset hiệu ứng Ghost
    isGhostMode = false;

    switch (itemType) {
      case ItemType.speedUp:
        currentSpeed = 100;
        _showToast("⚡ TĂNG TỐC! (5s)");
        break;
      case ItemType.slowDown:
        currentSpeed = 400;
        _showToast("🐌 LÀM CHẬM! (5s)");
        break;
      case ItemType.doublePoint:
        _showToast("🍏 NHÂN ĐÔI ĐIỂM!");
        currentSpeed = baseSpeed;
        break;
      case ItemType.cutTail:
        _cutSnakeTail(snakeId);
        _showToast("✂️ CẮT ĐUÔI RẮN!");
        currentSpeed = baseSpeed;
        break;
      case ItemType.ghost:
        isGhostMode = true;
        _showToast("👻 XUYÊN TƯỜNG (7s)!");
        currentSpeed = baseSpeed;
        break;
      case ItemType.mystery:
        _handleMysteryBox(snakeId);
        break;
      case ItemType.normal:
      default:
        currentSpeed = baseSpeed;
        break;
    }

    if (itemType == ItemType.speedUp || itemType == ItemType.slowDown || itemType == ItemType.ghost) {
      int duration = itemType == ItemType.ghost ? 7 : 5;
      buffTimer = Timer(Duration(seconds: duration), () {
        if (mounted) {
          currentSpeed = baseSpeed;
          isGhostMode = false; // Hết ghost
          _showToast("Hết hiệu ứng!");
        }
      });
    }
  }

  void _cutSnakeTail(int snakeId) {
    List<int> targetSnake = snakeId == 1 ? snakePos1 : snakePos2;
    if (targetSnake.length > 5) {
      int cutAmount = 3;
      if (targetSnake.length - cutAmount < 3) cutAmount = targetSnake.length - 3;
      targetSnake.removeRange(targetSnake.length - cutAmount, targetSnake.length);
    }
  }

  void _handleMysteryBox(int snakeId) {
    Random r = Random();
    int luck = r.nextInt(3); // 0, 1, 2
    if (luck == 0) {
      score1 += 5; // Ăn 5 điểm
      _showToast("🎁 MAY MẮN: +5 ĐIỂM!");
    } else if (luck == 1) {
      // Siêu tốc độ trong 2s
      currentSpeed = 80;
      buffTimer = Timer(const Duration(seconds: 2), () {
        if(mounted) currentSpeed = baseSpeed;
      });
      _showToast("🎁 QUÁ NHANH: ZOOM!!");
    } else {
      // Bị đảo ngược điều khiển (Code logic này phức tạp, tạm thời trừ điểm)
      if (score1 > 2) score1 -= 2;
      _showToast("🎁 XUI XẺO: -2 ĐIỂM!");
    }
    currentSpeed = baseSpeed; // Reset speed về base nếu không dính speed
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        duration: const Duration(milliseconds: 1000),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height * 0.7, // Hiện cao lên chút
            left: 50,
            right: 50
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  void _onUserSwipe(DragUpdateDetails details) {
    Direction myLastDir = (widget.isOnline && !widget.isHost) ? lastMoveDir2 : lastMoveDir1;

    double dx = details.delta.dx.abs();
    double dy = details.delta.dy.abs();

    if (dx > dy) {
      // Horizontal swipe
      if (details.delta.dx > 0) {
        if (myLastDir != Direction.left) dir1 = Direction.right;
      } else {
        if (myLastDir != Direction.right) dir1 = Direction.left;
      }
    } else {
      // Vertical swipe
      if (details.delta.dy > 0) {
        if (myLastDir != Direction.up) dir1 = Direction.down;
      } else {
        if (myLastDir != Direction.down) dir1 = Direction.up;
      }
    }

    if (widget.isOnline) {
      if (!widget.isHost) {
        Provider.of<MessageService>(context, listen: false).socket?.emit('make_game_move', {
          'roomId': widget.roomId, 'dir': dir2.index
        });
        setState(() => dir2 = dir1); // Đồng bộ dir2 nếu là guest
      } else {
        setState(() {});
      }
    } else {
      setState(() {});
    }
  }

  void _checkMultiplayerCollisions() {
    int head1 = snakePos1.first;
    int head2 = snakePos2.first;
    bool p1Die = false;
    bool p2Die = false;

    if (_isWallCollision(head1, dir1)) p1Die = true;
    if (_isWallCollision(head2, dir2)) p2Die = true;

    if (snakePos1.sublist(1).contains(head1)) p1Die = true;
    if (snakePos2.sublist(1).contains(head2)) p2Die = true;
    if (snakePos2.contains(head1)) p1Die = true;
    if (snakePos1.contains(head2)) p2Die = true;
    if (head1 == head2) { p1Die = true; p2Die = true; }

    if (p1Die || p2Die) {
      gameLoopTimer?.cancel();
      String result = 'draw';
      if (p1Die && !p2Die) result = 'guest_win';
      if (!p1Die && p2Die) result = 'host_win';

      Provider.of<MessageService>(context, listen: false).socket?.emit('game_over_signal', {
        'roomId': widget.roomId, 'winner': result
      });
      _handleOnlineGameOver(result);
    }
  }

  void _sendGameStateToGuest() {
    Provider.of<MessageService>(context, listen: false).socket?.emit('update_game_state', {
      'roomId': widget.roomId,
      'snake1': snakePos1, 'snake2': snakePos2,
      'foodPositions': foodPositions, // 🔄 Sync list
      'foodTypes': foodTypes.map((key, value) => MapEntry(key.toString(), value.index)), // Sync map
      'score1': score1, 'score2': score2,
      'dir1': dir1.index, 'dir2': dir2.index
    });
  }

  bool _isWallCollision(int head, Direction dir) {
    if (dir == Direction.left && head % squaresPerRow == squaresPerRow - 1) return true;
    if (dir == Direction.right && head % squaresPerRow == 0) return true;
    if (head < 0 || head >= totalSquares) return true;
    return false;
  }

  // 🔄 THAY ĐỔI: Sinh 2 items mới
  void _generateFoods() {
    Random random = Random();
    for (int i = 0; i < 2; i++) { // Sinh 2 cái
      int newPos;
      do {
        newPos = random.nextInt(totalSquares);
      } while (snakePos1.contains(newPos) || snakePos2.contains(newPos) || foodPositions.contains(newPos));

      int chance = random.nextInt(100);
      ItemType newType;
      if (chance < 50) {
        newType = ItemType.normal; // 50% Táo đỏ
      } else if (chance < 65) {
        newType = ItemType.doublePoint; // 15% Táo xanh
      } else if (chance < 75) {
        newType = ItemType.speedUp; // 10% Sét
      } else if (chance < 85) {
        newType = ItemType.cutTail; // 10% Kéo
      } else if (chance < 92) {
        newType = ItemType.slowDown; // 7% Sên
      } else if (chance < 97) {
        newType = ItemType.ghost; // 5% Ma
      } else {
        newType = ItemType.mystery; // 3% Hộp bí ẩn
      }

      foodPositions.add(newPos);
      foodTypes[newPos] = newType;

      // Optional: Nếu item xấu (cutTail, mystery, slowDown), set timer để biến mất sau 10s nếu không ăn
      if ([ItemType.cutTail, ItemType.mystery, ItemType.slowDown].contains(newType)) {
        Timer(Duration(seconds: 10), () {
          if (mounted && foodPositions.contains(newPos)) {
            setState(() {
              foodPositions.remove(newPos);
              foodTypes.remove(newPos);
            });
          }
        });
      }
    }
  }

  void _restoreGame(Map<String, dynamic> data) {
    try {
      if (data['snakePos'] != null) {
        snakePos1 = List<int>.from(data['snakePos']);
      }

      if (snakePos1.isEmpty) {
        print("⚠️ Dữ liệu save bị rỗng snakePos. Init mới.");
        _initGame();
        return;
      }

      // 🔄 Restore list foods
      if (data['foodPositions'] != null) {
        foodPositions = List<int>.from(data['foodPositions']);
      }
      if (data['foodTypes'] != null) {
        foodTypes = {};
        (data['foodTypes'] as Map).forEach((key, value) => foodTypes[int.parse(key)] = ItemType.values[value]);
      }

      score1 = data['score'] ?? 0;
      currentSpeed = data['speed'] ?? 250;
      baseSpeed = currentSpeed;

      int dirIndex = data['direction'] ?? 1;
      dir1 = Direction.values.length > dirIndex ? Direction.values[dirIndex] : Direction.down;

      if (data['isGhostMode'] != null) isGhostMode = data['isGhostMode'];

      lastMoveDir1 = dir1;

      isPlaying = false;

      print("✅ Restore hoàn tất! Điểm: $score1, Rắn dài: ${snakePos1.length}");
      setState(() {});

    } catch (e) {
      print("❌ Lỗi nghiêm trọng trong _restoreGame: $e");
      _initGame(); // Fallback an toàn
    }
  }

  void _gameOver() {
    if (!mounted) return;
    gameLoopTimer?.cancel();
    buffTimer?.cancel();
    if (score1 > 0) {
      _gameServiceRef.submitScore('snake', score1);
    }
    _gameServiceRef.clearGameState('snake');

    setState(() { isPlaying = false; snakePos1 = []; });

    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Game Over! 🐍"),
        content: Text("Điểm số: $score1"),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.leaderboard, color: Colors.amber),
            label: const Text("Xem BXH", style: TextStyle(color: Colors.amber)),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LeaderboardScreen()),
              );
            },
          ),
          TextButton(
            onPressed: () {
              if (mounted && Navigator.canPop(context)) {
                Navigator.pop(context); // Đóng Dialog
                _initGame();
                _startGame();
              }
            },
            child: const Text("Chơi lại"),
          )
        ],
      ),
    );
  }

  void _handleOnlineGameOver(String result) {
    if (!mounted) return;
    setState(() => isPlaying = false); // 🔥 FIX: Set isPlaying = false để dừng game loop hoàn toàn

    String msg = "";
    if (result == 'draw') msg = "HÒA! Hai đầu đụng nhau!";
    else if (result == 'host_win') msg = widget.isHost ? "BẠN THẮNG! 🎉" : "BẠN THUA! 💀";
    else msg = widget.isHost ? "BẠN THUA! 💀" : "BẠN THẮNG! 🎉";

    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("KẾT THÚC"),
        content: Text(msg, style: const TextStyle(fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: const Text("Thoát"),
          )
        ],
      ),
    );
  }

  // --- LOGIC VẼ RẮN & ITEM ---
  String _getSnakeAsset(int index, List<int> snakeList) {
    if (snakeList.isEmpty) return '$assetPath/body_vertical.png';
    int posIndex = snakeList.indexOf(index);
    if (posIndex == 0) { // HEAD
      if (snakeList.length < 2) return '$assetPath/head_down.png';
      int nextBody = snakeList[1];
      if (nextBody == index + 1) return '$assetPath/head_left.png';
      if (nextBody == index - 1) return '$assetPath/head_right.png';
      if (nextBody == index + squaresPerRow) return '$assetPath/head_up.png';
      if (nextBody == index - squaresPerRow) return '$assetPath/head_down.png';
      return '$assetPath/head_down.png';
    }
    if (posIndex == snakeList.length - 1) { // TAIL
      int prevBody = snakeList[posIndex - 1];
      if (prevBody == index + 1) return '$assetPath/tail_left.png';
      if (prevBody == index - 1) return '$assetPath/tail_right.png';
      if (prevBody == index + squaresPerRow) return '$assetPath/tail_up.png';
      if (prevBody == index - squaresPerRow) return '$assetPath/tail_down.png';
      return '$assetPath/tail_up.png';
    }
    // BODY
    int prev = snakeList[posIndex - 1];
    int next = snakeList[posIndex + 1];
    if ((prev == index - 1 && next == index + 1) || (prev == index + 1 && next == index - 1)) return '$assetPath/body_horizontal.png';
    if ((prev == index - squaresPerRow && next == index + squaresPerRow) || (prev == index + squaresPerRow && next == index - squaresPerRow)) return '$assetPath/body_vertical.png';
    if ((prev == index - squaresPerRow && next == index - 1) || (prev == index - 1 && next == index - squaresPerRow)) return '$assetPath/body_topleft.png';
    if ((prev == index - squaresPerRow && next == index + 1) || (prev == index + 1 && next == index - squaresPerRow)) return '$assetPath/body_topright.png';
    if ((prev == index + squaresPerRow && next == index - 1) || (prev == index - 1 && next == index + squaresPerRow)) return '$assetPath/body_downleft.png';
    if ((prev == index + squaresPerRow && next == index + 1) || (prev == index + 1 && next == index + squaresPerRow)) return '$assetPath/body_downright.png';
    return '$assetPath/body_vertical.png';
  }

  Widget _getItemWidget(ItemType type) {
    switch (type) {
      case ItemType.doublePoint: // Táo xanh lá
        return ColorFiltered(
          colorFilter: const ColorFilter.mode(Colors.greenAccent, BlendMode.modulate),
          child: Image.asset('$assetPath/apple.png', fit: BoxFit.contain),
        );
      case ItemType.speedUp: // Sét
        return Container(
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.blueGrey),
          padding: const EdgeInsets.all(2),
          child: const Icon(Icons.flash_on, color: Colors.yellowAccent, size: 14),
        );
      case ItemType.slowDown: // Sên
        return Container(
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
          padding: const EdgeInsets.all(2),
          child: const Icon(Icons.snowshoeing, color: Colors.cyanAccent, size: 14),
        );
      case ItemType.cutTail: // Kéo
        return Container(
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.orangeAccent),
          padding: const EdgeInsets.all(2),
          child: const Icon(Icons.content_cut, color: Colors.white, size: 14),
        );
      case ItemType.ghost: // Ma
        return Container(
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.purpleAccent),
          padding: const EdgeInsets.all(2),
          child: const Icon(Icons.group_work, color: Colors.white, size: 14),
        );
      case ItemType.mystery: // Hộp quà
        return Container(
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.pinkAccent),
          padding: const EdgeInsets.all(2),
          child: const Icon(Icons.card_giftcard, color: Colors.white, size: 14),
        );
      case ItemType.normal:
      default:
        return Image.asset('$assetPath/apple.png', fit: BoxFit.contain);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: Text(widget.isOnline ? "Đấu Rắn Online" : "Rắn Săn Mồi", style: const TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(isMusicPlaying ? Icons.music_note : Icons.music_off),
            onPressed: _toggleMusic,
          ),
        ],
      ),
      body: Column(
        children: [
          // SCORE BOARD
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildScoreCard(score1, "BẠN", Colors.greenAccent),
                if (widget.isOnline) _buildScoreCard(score2, "ĐỐI THỦ", Colors.redAccent),
              ],
            ),
          ),

          // GAME BOARD
          Expanded(
            child: GestureDetector(
              onPanUpdate: _onUserSwipe, // 🔥 FIX: Sử dụng onPanUpdate để vuốt nhạy hơn (nhận cử chỉ nhanh hơn)
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: totalSquares,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: squaresPerRow),
                  itemBuilder: (context, index) {
                    int row = index ~/ squaresPerRow;
                    int col = index % squaresPerRow;
                    Color cellColor = (row + col) % 2 == 0 ? currentGridColor1 : currentGridColor2;

                    Widget? childWidget;

                    // 🔥 RẮN 1: Bỏ border trắng, tăng glow neon cho đẹp hơn
                    if (snakePos1.contains(index)) {
                      childWidget = Container(
                        // Bỏ margin để sát hơn
                        decoration: BoxDecoration(
                          // Bỏ color trắng để loại border trắng
                          borderRadius: BorderRadius.circular(2), // Giảm radius cho sharp hơn
                          boxShadow: [ // 🔄 Tăng glow neon
                            BoxShadow(
                              color: isGhostMode ? Colors.purpleAccent.withOpacity(0.7) : Colors.lightGreenAccent.withOpacity(0.7),
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        // Bỏ padding để image fill hết cell
                        child: ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            isGhostMode ? Colors.purpleAccent : Colors.lightGreenAccent,
                            BlendMode.srcIn,
                          ),
                          child: Image.asset(_getSnakeAsset(index, snakePos1), fit: BoxFit.cover), // 🔥 fit: BoxFit.cover để đầy cell, đẹp hơn
                        ),
                      );
                    }
                    // RẮN 2: Tương tự bỏ border trắng, tăng glow
                    else if (snakePos2.contains(index)) {
                      childWidget = Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(0.7),
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.mode(Colors.redAccent, BlendMode.srcIn),
                          child: Image.asset(_getSnakeAsset(index, snakePos2), fit: BoxFit.cover),
                        ),
                      );
                    }
                    // 🔄 ITEMS: Vẽ nhiều nếu có
                    else if (foodPositions.contains(index)) {
                      childWidget = Padding(padding: const EdgeInsets.all(2), child: _getItemWidget(foodTypes[index]!));
                    }

                    return Container(color: cellColor, child: childWidget);
                  },
                ),
              ),
            ),
          ),

          // BUTTONS START / CONTINUE
          if (widget.isOnline && !isPlaying && widget.isHost)
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                onPressed: _startGame,
                icon: const Icon(Icons.play_circle_filled, color: Colors.black),
                label: const Text("BẮT ĐẦU NGAY", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),

          if (widget.isOnline && !widget.isHost && snakePos1.isEmpty)
            const Padding(padding: EdgeInsets.all(20), child: Text("Đang chờ chủ phòng...", style: TextStyle(color: Colors.white54))),

          // NÚT CHƠI / TIẾP TỤC (Offline)
          if (!widget.isOnline && !isPlaying)
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: snakePos1.isNotEmpty ? Colors.orangeAccent : Colors.greenAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)
                ),
                onPressed: _startGame,
                icon: Icon(snakePos1.isNotEmpty ? Icons.play_arrow : Icons.videogame_asset, color: Colors.black),
                label: Text(
                    snakePos1.isNotEmpty ? "TIẾP TỤC GAME" : "CHƠI MỚI",
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(int score, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          Text("$score", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}