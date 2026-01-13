// File: lib/screens/games/brick_breaker_screen.dart

import 'dart:async';
import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/text.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 👇 Import GameService
import '../../services/game_service.dart';

// --- 1. MÀN HÌNH CHỨA GAME (WIDGET) ---
class BrickBreakerGameScreen extends StatelessWidget {
  const BrickBreakerGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 👇 Lấy instance của GameService từ Provider
    final gameService = Provider.of<GameService>(context, listen: false);

    return Scaffold(
      body: GameWidget(
        // 👇 Truyền service vào game engine
        game: BrickBreakerGame(gameService: gameService),
        overlayBuilderMap: {
          'GameHUD': (context, BrickBreakerGame game) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // CỤM NÚT TRÁI (THOÁT & NHẠC)
                        Row(
                          children: [
                            // NÚT THOÁT
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 28),
                              onPressed: () {
                                game.pauseEngine();
                                showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      backgroundColor: Colors.grey[900],
                                      title: const Text("Thoát Game?", style: TextStyle(color: Colors.white)),
                                      content: const Text("Bạn có muốn lưu tiến trình không?", style: TextStyle(color: Colors.white70)),
                                      actions: [
                                        TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              Navigator.pop(context);
                                            },
                                            child: const Text("Không lưu", style: TextStyle(color: Colors.redAccent))
                                        ),
                                        ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
                                            onPressed: () async {
                                              await game.saveGame();
                                              if (context.mounted) {
                                                Navigator.pop(context);
                                                Navigator.pop(context);
                                              }
                                            },
                                            child: const Text("Lưu & Thoát", style: TextStyle(color: Colors.black))
                                        )
                                      ],
                                    )
                                );
                              },
                            ),
                            // 🔥 NÚT BẬT/TẮT NHẠC
                            ValueListenableBuilder<bool>(
                              valueListenable: game.isMusicOnNotifier,
                              builder: (context, isMusicOn, child) {
                                return IconButton(
                                  icon: Icon(
                                    isMusicOn ? Icons.music_note : Icons.music_off,
                                    color: isMusicOn ? Colors.cyanAccent : Colors.grey,
                                    size: 28,
                                  ),
                                  onPressed: () {
                                    game.toggleMusic();
                                  },
                                );
                              },
                            ),
                          ],
                        ),

                        // HIỂN THỊ ĐIỂM & LEVEL
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            ValueListenableBuilder<int>(
                              valueListenable: game.scoreNotifier,
                              builder: (context, score, child) {
                                return Text("SCORE: $score", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold));
                              },
                            ),
                            ValueListenableBuilder<int>(
                              valueListenable: game.levelNotifier,
                              builder: (context, level, child) {
                                return Text("LEVEL: $level", style: const TextStyle(color: Colors.yellowAccent, fontSize: 18, fontWeight: FontWeight.bold));
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
          'GameMenu': (context, BrickBreakerGame game) {
            return Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(15), border: Border.all(color: game.isWinner ? Colors.greenAccent : Colors.redAccent, width: 2)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(game.isWinner ? "LEVEL COMPLETE!" : "GAME OVER", style: TextStyle(color: game.isWinner ? Colors.greenAccent : Colors.redAccent, fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text("Score: ${game.scoreNotifier.value}", style: const TextStyle(color: Colors.white, fontSize: 20)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
                      onPressed: () {
                        if (game.isWinner) {
                          game.nextLevel();
                        } else {
                          game.resetGame();
                        }
                      },
                      child: Text(game.isWinner ? "LEVEL TIẾP THEO" : "CHƠI LẠI", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("THOÁT", style: TextStyle(color: Colors.white70)),
                    )
                  ],
                ),
              ),
            );
          },
          'Loading': (context, game) => const Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
        },
        initialActiveOverlays: const ['Loading'],
      ),
    );
  }
}


// --- 2. GAME ENGINE CHÍNH ---
class BrickBreakerGame extends FlameGame with HasCollisionDetection, PanDetector {
  final GameService gameService;
  bool _isLevelStarted = false;
  BrickBreakerGame({required this.gameService});

  late Paddle paddle;
  bool isWinner = false;
  int currentLevel = 1;

  final ValueNotifier<int> scoreNotifier = ValueNotifier(0);
  final ValueNotifier<int> levelNotifier = ValueNotifier(1);

  // 🔥 Biến theo dõi trạng thái nhạc (Mặc định là đang bật)
  final ValueNotifier<bool> isMusicOnNotifier = ValueNotifier(true);

  late SpriteComponent _backgroundComponent;
  List<Sprite> _bgSprites = [];

  // --- HÀM PHÁT NHẠC ---
  void _playBGM() {
    if (!isMusicOnNotifier.value) return;

    try {
      // Random bài hát
      int trackNumber = Random().nextInt(14) + 1;
      String fileName = '$trackNumber.mp3';

      print("🎵 Playing BGM: $fileName");
      FlameAudio.bgm.play(fileName, volume: 0.5);
    } catch (e) {
      print("❌ Lỗi Audio: $e");
    }
  }

  // 🔥 HÀM TOGGLE MUSIC
  void toggleMusic() {
    bool newState = !isMusicOnNotifier.value;
    isMusicOnNotifier.value = newState;

    if (newState) {
      if (FlameAudio.bgm.isPlaying) {
        FlameAudio.bgm.resume();
      } else {
        _playBGM();
      }
    } else {
      FlameAudio.bgm.pause();
    }
  }

  @override
  Future<void> onLoad() async {
    // -----------------------------------------------------
    // 🔥 CẤU HÌNH ÂM THANH NGAY ĐẦU TIÊN
    // -----------------------------------------------------
    FlameAudio.audioCache.prefix = 'assets/sounds/';
    // Quan trọng: Khởi tạo module BGM
    FlameAudio.bgm.initialize();

    // Load background
    try {
      for (int i = 1; i <= 4; i++) {
        final sprite = await loadSprite('brick_breaker/bg$i.jpg');
        _bgSprites.add(sprite);
      }
    } catch (e) {
      debugPrint("❌ Lỗi load background: $e");
    }

    // Phát nhạc ngay lập tức
    _playBGM();

    // Setup Background Component
    _backgroundComponent = SpriteComponent(
      sprite: _bgSprites.isNotEmpty ? _bgSprites[0] : null,
      size: size,
      priority: -1,
    );
    add(_backgroundComponent);

    add(ScreenHitbox());

    overlays.add('Loading');

    try {
      final savedData = await gameService.loadGameState('brick_breaker');

      if (savedData != null) {
        currentLevel = savedData['level'] ?? 1;
        scoreNotifier.value = savedData['score'] ?? 0;
        print("📥 Đã tải save: Level $currentLevel - Score ${scoreNotifier.value}");
      } else {
        currentLevel = 1;
        scoreNotifier.value = 0;
        print("🆕 Không có save, chơi mới.");
      }
    } catch (e) {
      print("❌ Lỗi load game: $e");
      currentLevel = 1;
      scoreNotifier.value = 0;
    } finally {
      overlays.remove('Loading');
    }

    startLevel();
  }

  @override
  void onRemove() {
    print("🛑 Dừng nhạc nền");
    FlameAudio.bgm.stop();
    FlameAudio.bgm.dispose();
    super.onRemove();
  }

  Future<void> saveGame() async {
    if (children.whereType<Ball>().isNotEmpty) {
      await gameService.saveGameState('brick_breaker', {
        'level': currentLevel,
        'score': scoreNotifier.value,
      });
      print("💾 Đã lưu game.");
    }
  }

  void startLevel() {
    _isLevelStarted = false;

    if (_bgSprites.isNotEmpty) {
      int randomIndex = Random().nextInt(_bgSprites.length);
      _backgroundComponent.sprite = _bgSprites[randomIndex];
    }

    children.whereType<Brick>().forEach((e) => e.removeFromParent());
    children.whereType<Ball>().forEach((e) => e.removeFromParent());
    children.whereType<Paddle>().forEach((e) => e.removeFromParent());
    children.whereType<PowerUpItem>().forEach((e) => e.removeFromParent());

    isWinner = false;
    resumeEngine();
    overlays.remove('GameMenu');
    overlays.add('GameHUD');

    levelNotifier.value = currentLevel;

    _createBricksForLevel(currentLevel);

    paddle = Paddle(position: Vector2(size.x / 2, size.y - 80));
    add(paddle);

    spawnBall();

    Future.delayed(const Duration(milliseconds: 100), () {
      _isLevelStarted = true;
    });
  }

  void spawnBall({Vector2? position, Vector2? velocity}) {
    final ballPos = position ?? Vector2(size.x / 2, size.y / 2);
    final ballVel = velocity ?? Vector2((Random().nextBool() ? 1 : -1) * 200, -300);
    add(Ball(position: ballPos, initialVelocity: ballVel));
  }

  void _createBricksForLevel(int level) {
    int rows = 5 + (level - 1);
    if (rows > 12) rows = 12;
    int cols = 6 + (level ~/ 2);
    if (cols > 10) cols = 10;
    final brickWidth = size.x / cols;
    final brickHeight = size.y / 30;
    final double topOffset = 100.0;
    final colors = [Colors.redAccent, Colors.orangeAccent, Colors.yellowAccent, Colors.greenAccent, Colors.blueAccent, Colors.purpleAccent, Colors.pinkAccent, Colors.cyanAccent];
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        add(Brick(position: Vector2(col * brickWidth + (brickWidth / 2), topOffset + row * (brickHeight + 2)), size: Vector2(brickWidth - 2, brickHeight), color: colors[row % colors.length]));
      }
    }
  }

  void onPanUpdate(DragUpdateInfo info) {
    paddle.move(info.delta.global.x);
  }

  void showMenu(bool win) {
    _isLevelStarted = false;
    isWinner = win;
    pauseEngine();
    overlays.add('GameMenu');
    overlays.remove('GameHUD');

    if (win) {
      saveGame();
    } else {
      gameService.submitScore('brick_breaker', scoreNotifier.value);
      gameService.clearGameState('brick_breaker');
    }
  }

  void resetGame() {
    currentLevel = 1;
    scoreNotifier.value = 0;
    gameService.clearGameState('brick_breaker');
    startLevel();
  }

  void nextLevel() {
    currentLevel++;
    startLevel();
  }

  void increaseScore() {
    scoreNotifier.value += 10;
  }

  void maybeDropPowerUp(Vector2 position) {
    if (Random().nextDouble() < 0.08) {
      int type = Random().nextInt(3);
      PowerUpType powerType = PowerUpType.values[type];
      add(PowerUpItem(position: position, type: powerType));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_isLevelStarted) return;
    if (children.whereType<Brick>().isEmpty && isMounted) {
      if (children.whereType<Ball>().isNotEmpty) {
        showMenu(true);
      }
    }
    if (children.whereType<Ball>().isEmpty && isMounted) {
      showMenu(false);
    }
  }
}


// --- 3. CÁC OBJECT TRONG GAME (Giữ nguyên) ---

class Paddle extends RectangleComponent with HasGameRef<BrickBreakerGame>, CollisionCallbacks {
  Paddle({required Vector2 position}) : super(position: position, size: Vector2(100, 20), anchor: Anchor.center, paint: Paint()..color = Colors.cyan) { add(RectangleHitbox()); }
  void move(double dx) { position.x += dx; position.x = position.x.clamp(width / 2, gameRef.size.x - width / 2); }
  @override void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) { super.onCollisionStart(intersectionPoints, other); if (other is PowerUpItem) { other.applyEffect(); other.removeFromParent(); } }
}

class Brick extends RectangleComponent with HasGameRef<BrickBreakerGame>, CollisionCallbacks {
  Brick({required Vector2 position, required Vector2 size, required Color color}) : super(position: position, size: size, anchor: Anchor.center, paint: Paint()..color = color) { add(RectangleHitbox()); }
  @override void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) { super.onCollisionStart(intersectionPoints, other); if (other is Ball) { removeFromParent(); gameRef.increaseScore(); gameRef.maybeDropPowerUp(position); } }
}

class Ball extends CircleComponent with HasGameRef<BrickBreakerGame>, CollisionCallbacks {
  Vector2 velocity;
  double speedMultiplier = 1.0;
  final double baseSpeed = 400;
  bool hasCollidedWithPaddle = false;

  Ball({required Vector2 position, Vector2? initialVelocity})
      : velocity = initialVelocity ?? Vector2(300, 300),
        super(
          position: position,
          radius: 10,
          anchor: Anchor.center,
          paint: Paint()..color = Colors.white) {
    add(CircleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += velocity * dt * speedMultiplier;

    // --- GIA CỐ BIÊN TRÁI & PHẢI (Hậu kiểm) ---
    if (position.x <= radius) {
      position.x = radius + 1; // Ép vào trong 1px
      velocity.x = velocity.x.abs(); // Chắc chắn bay sang phải
    } else if (position.x >= gameRef.size.x - radius) {
      position.x = gameRef.size.x - radius - 1; // Ép vào trong 1px
      velocity.x = -velocity.x.abs(); // Chắc chắn bay sang trái
    }

    // --- GIA CỐ BIÊN TRÊN ---
    if (position.y <= radius) {
      position.y = radius + 1;
      if (velocity.y < 0) velocity.y = -velocity.y;
    }

    // Tránh vận tốc trục Y quá thấp gây hiện tượng đi ngang
    if (velocity.y.abs() < 20) {
      velocity.y = velocity.y > 0 ? 20 : -20;
    }

    // Rớt xuống dưới thì biến mất
    if (position.y > gameRef.size.y + radius) {
      removeFromParent();
    }

    if (hasCollidedWithPaddle &&
        position.y < gameRef.paddle.position.y - gameRef.paddle.height) {
      hasCollidedWithPaddle = false;
    }
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);

    if (other is ScreenHitbox) {
      // Đã xử lý triệt để trong update, nhưng giữ lại để đồng bộ Flame
      if (position.x <= radius || position.x >= gameRef.size.x - radius) {
        velocity.x = -velocity.x;
      }
      if (position.y <= radius) {
        velocity.y = -velocity.y;
      }
    } else if (other is Paddle) {
      if (velocity.y > 0) {
        // Đẩy banh lên trên bề mặt paddle để tránh kẹt
        position.y = other.position.y - other.size.y / 2 - radius - 1;
        velocity.y = -velocity.y.abs();

        // Tính toán góc nảy dựa trên vị trí va chạm trên thanh paddle
        double relativeIntersectX = (position.x - other.position.x);
        double normalizedRelativeIntersectionX =
        (relativeIntersectX / (other.width / 2));
        velocity.x = normalizedRelativeIntersectionX * baseSpeed * 1.5;

        velocity = velocity.normalized() * baseSpeed;
        hasCollidedWithPaddle = true;
      }
    } else if (other is Brick) {
      // Va chạm gạch: Đảo chiều Y
      velocity.y = -velocity.y;
    }
  }

  void changeColor(Color color) {
    paint.color = color;
  }
}


enum PowerUpType { speedUp, slowDown, multiBall }
class PowerUpItem extends CircleComponent with HasGameRef<BrickBreakerGame>, CollisionCallbacks {
  final PowerUpType type;
  PowerUpItem({required Vector2 position, required this.type}) : super(position: position, radius: 15, anchor: Anchor.center) { switch (type) { case PowerUpType.speedUp: paint.color = Colors.redAccent; break; case PowerUpType.slowDown: paint.color = Colors.blueAccent; break; case PowerUpType.multiBall: paint.color = Colors.greenAccent; break; } add(CircleHitbox()); }
  @override Future<void> onLoad() async { super.onLoad(); String symbol = ""; switch (type) { case PowerUpType.speedUp: symbol = ">>"; break; case PowerUpType.slowDown: symbol = "<<"; break; case PowerUpType.multiBall: symbol = "+"; break; } add(TextComponent(text: symbol, anchor: Anchor.center, position: Vector2(radius, radius), textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))); }
  @override void update(double dt) { super.update(dt); position.y += 150 * dt; if (position.y > gameRef.size.y) { removeFromParent(); } }
  void applyEffect() { switch (type) { case PowerUpType.speedUp: gameRef.children.whereType<Ball>().forEach((ball) { ball.speedMultiplier = 1.8; ball.changeColor(Colors.redAccent); }); Future.delayed(const Duration(seconds: 5), () { if (gameRef.isMounted) { gameRef.children.whereType<Ball>().forEach((ball) { ball.speedMultiplier = 1.0; ball.changeColor(Colors.white); }); } }); break; case PowerUpType.slowDown: gameRef.children.whereType<Ball>().forEach((ball) { ball.speedMultiplier = 0.6; ball.changeColor(Colors.blueAccent); }); Future.delayed(const Duration(seconds: 5), () { if (gameRef.isMounted) { gameRef.children.whereType<Ball>().forEach((ball) { ball.speedMultiplier = 1.0; ball.changeColor(Colors.white); }); } }); break; case PowerUpType.multiBall: gameRef.spawnBall(position: Vector2(gameRef.paddle.position.x, gameRef.paddle.position.y - 30), velocity: Vector2(0, -400)); break; } }
}
