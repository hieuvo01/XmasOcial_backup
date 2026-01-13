import 'dart:math';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/palette.dart';
import 'package:flame/collisions.dart';
import 'package:flame_audio/flame_audio.dart'; // Import Audio
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

import 'package:google_fonts/google_fonts.dart';



// --- ENUM TRẠNG THÁI GAME ---
enum TurnState {
  playerChoice, // Lượt chọn (DELETE / RESTORE)
  subMenu,      // Menu con của RESTORE (Act)
  dialogue,     // Đang thoại
  enemyTurn,    // Lượt Boss tấn công (Né đạn)
  gameOver,
  win
}

// --- MÀN HÌNH UI (FLUTTER) ---
class UndertaleGameScreen extends StatelessWidget {
  const UndertaleGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GameWidget(
        game: RecycleBattleGame(),
        overlayBuilderMap: {
          // MENU CHÍNH: 4 Nút Lớn
          'MainMenu': (BuildContext context, RecycleBattleGame game) {
            return game.gameState == TurnState.playerChoice
                ? Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildBtn(context, "DELETE", Colors.redAccent,
                          () => game.onDeletePressed()), // Thay Fight
                  _buildBtn(context, "RESTORE", Colors.cyanAccent,
                          () => game.onRestorePressed()), // Thay Act
                  _buildBtn(context, "ITEM", Colors.greenAccent,
                          () => game.onItemPressed()),
                  _buildBtn(context, "MERCY", Colors.yellowAccent,
                          () => game.onMercyPressed()),
                ],
              ),
            )
                : const SizedBox.shrink();
          },
          // SUB-MENU: Các lựa chọn khi bấm RESTORE
          'SubMenu': (BuildContext context, RecycleBattleGame game) {
            return game.gameState == TurnState.subMenu
                ? Positioned(
              bottom: 100,
              left: 50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: game.currentActs
                    .map((act) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        side: const BorderSide(
                            color: Colors.white)),
                    onPressed: () => game.executeAct(act),
                    child: Text("* $act",
                        style: GoogleFonts.vt323(
                            color: Colors.white, fontSize: 20)),
                  ),
                ))
                    .toList(),
              ),
            )
                : const SizedBox.shrink();
          },
          'RestartMenu': (BuildContext context, RecycleBattleGame game) {
            return Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black),
                icon: const Icon(Icons.refresh),
                label: const Text("KHỞI ĐỘNG LẠI HỆ THỐNG",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const UndertaleGameScreen())),
              ),
            );
          },
        },
      ),
    );
  }

  Widget _buildBtn(BuildContext context, String label, Color color,
      VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        side: BorderSide(color: color, width: 2),
        shape: const BeveledRectangleBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
      ),
      onPressed: onPressed,
      child: Text(label,
          style: GoogleFonts.pressStart2p(color: color, fontSize: 10)),
    );
  }
}

// --- GAME ENGINE: PROJECT RECYCLE ---
class RecycleBattleGame extends FlameGame
    with HasCollisionDetection, KeyboardEvents {
  late GlitchPlayer player;
  late RectangleComponent battleBox;
  late JoystickComponent joystick;
  late GrandpaCRT boss; // Boss đầu tiên
  late TextComponent hpText;
  late TextComponent dialogueText;

  int maxHp = 20;
  int currentHp = 20;

  // Logic Cốt truyện
  int friendshipMeter = 0; // Điểm thân thiện với CRT
  bool isSpareable = false;
  List<String> currentActs = [
    "Check",
    "Lau màn hình",
    "Hỏi về quá khứ"
  ]; // Các hành động Restore

  // Logic Đạn
  double bulletTimer = 0;
  double turnTimer = 0;

  TurnState gameState = TurnState.dialogue;

  @override
  Future<void> onLoad() async {
    // 0. Phát nhạc nền
    startBgm();

    // 1. HP Text (Style Glitch)
    hpText = TextComponent(
      text: "HP: $currentHp / $maxHp",
      textRenderer: TextPaint(
          style: GoogleFonts.vt323(
              color: Colors.greenAccent,
              fontSize: 24,
              fontWeight: FontWeight.bold)),
      position: Vector2(20, 20),
    );
    add(hpText);

    // 2. Boss: Grandpa CRT
    boss = GrandpaCRT()
      ..position = Vector2(size.x / 2, 120)
      ..size = Vector2(100, 80) // TV hình chữ nhật
      ..anchor = Anchor.center;
    add(boss);

    // 3. Battle Box (Khung chứa Tim)
    battleBox = RectangleComponent(
      position: size / 2 + Vector2(0, 80),
      size: Vector2(320, 150),
      anchor: Anchor.center,
      paint: BasicPalette.white.paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    add(battleBox);

    // 4. Player: Glitch Soul
    player = GlitchPlayer()
      ..position = size / 2 + Vector2(0, 80)
      ..size = Vector2(16, 16)
      ..anchor = Anchor.center;
    // Chưa add vội

    // 5. Joystick
    final knobPaint = BasicPalette.cyan.withAlpha(200).paint();
    joystick = JoystickComponent(
      knob: CircleComponent(radius: 15, paint: knobPaint),
      background: CircleComponent(
          radius: 50, paint: BasicPalette.white.withAlpha(50).paint()),
      margin: const EdgeInsets.only(left: 40, bottom: 120),
    );
    add(joystick);

    // 6. Dialogue Box
    dialogueText = TextComponent(
      text: "",
      textRenderer: TextPaint(
          style: GoogleFonts.vt323(color: Colors.white, fontSize: 28)),
      position: Vector2(40, size.y - 140),
      size: Vector2(size.x - 80, 100),
    );
    add(dialogueText);

    // Mở màn
    showDialogue("Grandpa CRT chặn đường bạn!\n(Trông ổng có vẻ bụi bặm)");
  }

  void startBgm() {
    try {
      // Đảm bảo file assets/audio/fight.flac tồn tại
      FlameAudio.bgm.play('fight.flac', volume: 0.5);
    } catch (e) {
      print("Lỗi âm thanh: $e");
    }
  }

  @override
  void onRemove() {
    // Tắt nhạc khi thoát game
    FlameAudio.bgm.stop();
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Logic trong lượt Enemy (Né đạn)
    if (gameState == TurnState.enemyTurn) {
      bulletTimer += dt;

      // LOGIC TẤN CÔNG NÂNG CẤP
      // Nếu giây chẵn -> Dùng chiêu khó (Sọc màu)
      // Nếu giây lẻ -> Dùng chiêu dễ (Nhiễu sóng)
      bool useHardAttack = (turnTimer.toInt() % 2 == 0);

      if (useHardAttack) {
        if (bulletTimer > 0.8) {
          spawnColorBars(); // Chiêu mới
          bulletTimer = 0;
        }
      } else {
        if (bulletTimer > 0.4) {
          spawnStaticNoise(); // Chiêu cũ
          bulletTimer = 0;
        }
      }

      turnTimer -= dt;
      if (turnTimer <= 0) endEnemyTurn();
    }
  }

  // --- HỆ THỐNG HỘI THOẠI & TURN ---
  void showDialogue(String text) {
    gameState = TurnState.dialogue;
    dialogueText.text = ""; // Reset text

    // Hiệu ứng gõ chữ (Typewriter Effect thủ công)
    String fullText = text;

    // Xóa vật thể chiến đấu
    if (player.parent != null) player.removeFromParent();
    children.whereType<Bullet>().forEach((b) => b.removeFromParent());
    children
        .whereType<ColorBarBullet>()
        .forEach((b) => b.removeFromParent()); // Xóa cả sọc màu
    overlays.remove('MainMenu');
    overlays.remove('SubMenu');

    // Hiện full text luôn
    dialogueText.text = fullText;

    Future.delayed(const Duration(seconds: 3), () {
      if (gameState == TurnState.dialogue) startPlayerTurn();
    });
  }

  void startPlayerTurn() {
    gameState = TurnState.playerChoice;

    // Cập nhật mặt Boss dựa trên tình huống
    if (isSpareable) {
      dialogueText.text = "CRT đang mỉm cười (^_^) chờ bạn.";
      boss.setFace("HAPPY");
    } else {
      dialogueText.text = "Bạn sẽ làm gì với ông cụ này?";
      boss.setFace("NORMAL");
    }

    overlays.add('MainMenu');
  }

  void startEnemyTurn() {
    gameState = TurnState.enemyTurn;
    dialogueText.text = "";
    overlays.remove('MainMenu');
    overlays.remove('SubMenu');

    player.position = battleBox.position.clone();
    player.setMode("NORMAL"); // Reset màu về trắng khi né đạn (tùy chọn)
    add(player);

    turnTimer = 5.0; // Né trong 5s (tăng lên xíu cho khó)
  }

  void endEnemyTurn() {
    if (friendshipMeter >= 2) {
      showDialogue(
          "CRT: 'Mắt tao sáng hẳn ra rồi!'\n(Ông cụ có vẻ không muốn đánh nữa)");
      isSpareable = true;
      boss.setFace("HAPPY");
    } else {
      showDialogue("CRT lầm bầm về thế hệ trẻ...");
      boss.setFace("ANGRY");
    }
  }

  // --- XỬ LÝ CÁC NÚT (HANDLERS) ---
  void onDeletePressed() {
    // Tấn công (Genocide Route)
    player.setMode("DELETE"); // ĐỔI MÀU ĐỎ
    showDialogue("Bạn tung cú DELETE cực mạnh!\nCRT mất 100 máu (O_O!)");
    boss.setFace("SHOCKED");
    Future.delayed(const Duration(seconds: 2), startEnemyTurn);
  }

  void onRestorePressed() {
    // Mở Sub-Menu chọn hành động (Pacifist Route)
    player.setMode("RESTORE"); // ĐỔI MÀU XANH
    gameState = TurnState.subMenu;
    overlays.remove('MainMenu');
    overlays.add('SubMenu');
    dialogueText.text = "Chọn cách tiếp cận:";
  }

  void executeAct(String actName) {
    // Xử lý từng hành động cụ thể
    if (actName == "Check") {
      showDialogue(
          "GRANDPA CRT - ATK 5 DEF 0\nThích kể chuyện ngày xưa. Sợ nam châm.");
    } else if (actName == "Lau màn hình") {
      friendshipMeter++;
      showDialogue("Bạn dùng tay áo lau bụi cho CRT.\nÔng cụ đỏ mặt (^///^).");
      boss.setFace("BLUSH");
    } else if (actName == "Hỏi về quá khứ") {
      showDialogue("Bạn hỏi về thời 1990.\nCRT say sưa kể chuyện 30 phút...");
    }

    // Sau khi Act xong thì đến lượt Boss tấn công
    Future.delayed(const Duration(seconds: 3), startEnemyTurn);
  }

  void onItemPressed() {
    showDialogue("Bạn lục túi...\nChỉ có bụi và vài dòng code rác.");
    Future.delayed(
        const Duration(seconds: 2), startPlayerTurn); // Quay lại chọn tiếp
  }

  void onMercyPressed() {
    if (isSpareable) {
      gameState = TurnState.win;
      boss.setFace("HAPPY");
      dialogueText.text =
      "CRT: 'Cảm ơn nhóc! Ghé nhà tao sạc pin nhé.'\n(BẠN ĐÃ CHIẾN THẮNG)";
      overlays.remove('MainMenu');
      overlays.add('RestartMenu');
      boss.add(OpacityEffect.fadeOut(
          EffectController(duration: 1))); // Boss biến mất dần
    } else {
      showDialogue("CRT chưa chịu đâu. Hãy thử RESTORE thêm.");
      Future.delayed(const Duration(seconds: 2), startEnemyTurn);
    }
  }

  // --- HỆ THỐNG ĐẠN ---

  // 1. Static Noise (Nhiễu sóng)
  void spawnStaticNoise() {
    Random r = Random();
    double startY = battleBox.position.y -
        battleBox.size.y / 2 +
        r.nextDouble() * battleBox.size.y;
    bool fromLeft = r.nextBool();

    double startX =
    fromLeft ? battleBox.position.x - 200 : battleBox.position.x + 200;

    // Cập nhật: Giảm tốc độ từ 200 -> 140 cho dễ né
    double velX = fromLeft ? 140 : -140;

    add(Bullet(Vector2(startX, startY), Vector2(velX, 0)));
  }

  // 2. Color Bars (Sọc màu TV) - CHIÊU MỚI
  void spawnColorBars() {
    final box = battleBox;
    double startX = box.position.x + box.size.x / 2 + 50;

    // Cập nhật: Tăng khoảng hở gap từ 50 -> 75
    double gapSize = 75.0;

    // Tính toán để khe hở không bị sát mép trên hoặc mép dưới quá
    double minGapY = box.position.y - box.size.y / 2 + 20;
    double maxGapY = box.position.y + box.size.y / 2 - gapSize - 20;

    double gapY = minGapY + Random().nextDouble() * (maxGapY - minGapY);

    // Thanh trên
    double heightTop = gapY - (box.position.y - box.size.y / 2);
    if (heightTop > 0) {
      // Giảm tốc độ bay từ 150 -> 130
      add(ColorBarBullet(startX, box.position.y - box.size.y / 2,
          heightTop, Colors.red, 130));
    }

    // Thanh dưới
    double startBottom = gapY + gapSize;
    double heightBottom = (box.position.y + box.size.y / 2) - startBottom;
    if (heightBottom > 0) {
      // Giảm tốc độ bay từ 150 -> 130
      add(ColorBarBullet(startX, startBottom,
          heightBottom, Colors.blue, 130));
    }
  }

  void takeDamage() {
    if (gameState == TurnState.gameOver || gameState == TurnState.win) return;
    currentHp -= 4;
    hpText.text = "HP: $currentHp / $maxHp";

    // Rung camera
    camera.viewfinder.add(MoveEffect.by(Vector2(5, 5),
        EffectController(duration: 0.1, alternate: true, repeatCount: 3)));

    if (currentHp <= 0) {
      gameState = TurnState.gameOver;
      hpText.text = "SYSTEM FAILURE";
      dialogueText.text = "Dữ liệu của bạn đã bị xóa vĩnh viễn...";
      player.removeFromParent();
      overlays.remove('MainMenu');
      overlays.remove('SubMenu');
      overlays.add('RestartMenu');
    }
  }

  @override
  KeyEventResult onKeyEvent(
      KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (gameState != TurnState.enemyTurn) return KeyEventResult.ignored;

    final speed = 150.0; // Đồng bộ tốc độ (Cũ là 200)

    Vector2 dir = Vector2.zero();
    if (!joystick.delta.isZero()) return KeyEventResult.ignored;
    if (keysPressed.contains(LogicalKeyboardKey.arrowUp)) dir.y -= 1;
    if (keysPressed.contains(LogicalKeyboardKey.arrowDown)) dir.y += 1;
    if (keysPressed.contains(LogicalKeyboardKey.arrowLeft)) dir.x -= 1;
    if (keysPressed.contains(LogicalKeyboardKey.arrowRight)) dir.x += 1;

    if (dir != Vector2.zero()) {
      // Normalized để đi chéo không bị nhanh hơn + Cảm giác cứng cáp (Snappy)
      dir = dir.normalized();
      player.velocity = dir * speed;
    } else {
      player.velocity = Vector2.zero();
    }
    return KeyEventResult.handled;
  }
}

// --- CLASS NHÂN VẬT ---

// 1. Grandpa CRT (Boss TV)
class GrandpaCRT extends PositionComponent with HasPaint {
  String faceState = "NORMAL";

  void setFace(String state) {
    faceState = state;
  }

  @override
  void render(Canvas canvas) {
    // Opacity Fix
    final currentOpacity = paint.color.opacity;

    Paint framePaint = Paint()
      ..color = Colors.grey[800]!.withOpacity(currentOpacity);
    Paint screenPaint = Paint()
      ..color = const Color(0xFF112211).withOpacity(currentOpacity);

    canvas.drawRRect(
        RRect.fromRectAndRadius(size.toRect(), const Radius.circular(10)),
        framePaint);
    Rect screenRect = Rect.fromLTWH(10, 10, size.x - 20, size.y - 20);
    canvas.drawRect(screenRect, screenPaint);

    TextPaint facePaint = TextPaint(
        style: GoogleFonts.vt323(
            color: Colors.greenAccent.withOpacity(currentOpacity),
            fontSize: 24,
            fontWeight: FontWeight.bold));

    String faceText = "O _ O";
    if (faceState == "ANGRY") faceText = "> _ <";
    if (faceState == "HAPPY") faceText = "^ _ ^";
    if (faceState == "BLUSH") faceText = "^///^";
    if (faceState == "SHOCKED") faceText = "O [] O";

    facePaint.render(canvas, faceText, Vector2(size.x / 2, size.y / 2),
        anchor: Anchor.center);

    Paint antPaint = Paint()
      ..color = Colors.grey.withOpacity(currentOpacity)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(20, 0), Offset(0, -20), antPaint);
    canvas.drawLine(Offset(size.x - 20, 0), Offset(size.x, -20), antPaint);
  }
}

// 2. Glitch Player (Nâng cấp Visual)
class GlitchPlayer extends PositionComponent
    with HasGameRef<RecycleBattleGame>, CollisionCallbacks {
  Vector2 velocity = Vector2.zero();

  // Màu sắc hiện tại
  Color bodyColor = Colors.cyanAccent;

  // Biến dùng cho hiệu ứng rung giật
  final Random _rng = Random();

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(
        size: size * 0.6, position: size * 0.2, anchor: Anchor.topLeft));
  }

  // Hàm đổi màu dựa theo mode
  void setMode(String mode) {
    if (mode == "DELETE") {
      bodyColor = Colors.redAccent;
    } else if (mode == "RESTORE") {
      bodyColor = Colors.cyanAccent;
    } else {
      bodyColor = Colors.white;
    }
  }

  @override
  void render(Canvas canvas) {
    // --- HIỆU ỨNG GLITCH ---
    double jitterX = (_rng.nextDouble() - 0.5) * 3;
    double jitterY = (_rng.nextDouble() - 0.5) * 3;

    // Vẽ bóng mờ
    Paint ghostPaint = Paint()..color = bodyColor.withOpacity(0.5);
    canvas.drawRect(
        Rect.fromLTWH(jitterX * 2, jitterY * 2, size.x, size.y), ghostPaint);

    // Vẽ thân chính
    Paint mainPaint = Paint()..color = bodyColor;
    canvas.drawRect(
        Rect.fromLTWH(jitterX, jitterY, size.x, size.y), mainPaint);

    // Vẽ mắt
    Paint eyePaint = Paint()..color = Colors.black;
    canvas.drawRect(Rect.fromLTWH(3 + jitterX, 4 + jitterY, 4, 4), eyePaint);
    canvas.drawRect(Rect.fromLTWH(10 + jitterX, 4 + jitterY, 4, 4), eyePaint);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.gameState != TurnState.enemyTurn) return;

    // --- CẬP NHẬT DI CHUYỂN "THÔ" (RETRO) ---
    final double moveSpeed = 150.0; // Giảm tốc độ

    velocity = Vector2.zero(); // Reset velocity mỗi frame

    if (!gameRef.joystick.delta.isZero()) {
      // Normalized() giúp tốc độ luôn ổn định dù kéo mạnh hay nhẹ
      velocity = gameRef.joystick.delta.normalized() * moveSpeed;
    }

    position += velocity * dt;

    final box = gameRef.battleBox;
    // Padding để không dính sát tường
    double padding = 2;
    double minX = box.position.x - box.size.x / 2 + size.x / 2 + padding;
    double maxX = box.position.x + box.size.x / 2 - size.x / 2 - padding;
    double minY = box.position.y - box.size.y / 2 + size.y / 2 + padding;
    double maxY = box.position.y + box.size.y / 2 - size.y / 2 - padding;
    position.x = position.x.clamp(minX, maxX);
    position.y = position.y.clamp(minY, maxY);
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Bullet || other is ColorBarBullet) {
      gameRef.takeDamage();
      if (other is Bullet) other.removeFromParent();
      // ColorBarBullet xuyên thấu nên không remove
    }
  }
}

// 3. Bullet (Đạn nhiễu)
class Bullet extends PositionComponent
    with HasGameRef<RecycleBattleGame>, CollisionCallbacks {
  final Vector2 velocity;
  Bullet(Vector2 pos, this.velocity) {
    position = pos;
    size = Vector2(40, 4);
  }
  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
        size.toRect(), Paint()..color = Colors.white.withOpacity(0.8));
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += velocity * dt;
    if (position.x > gameRef.size.x + 100 || position.x < -100)
      removeFromParent();
  }
}

// 4. Color Bar Bullet (Sọc Màu TV)
// Thêm HasPaint để tránh lỗi Undefined name 'paint'
class ColorBarBullet extends PositionComponent
    with HasGameRef<RecycleBattleGame>, CollisionCallbacks, HasPaint {
  final double speed;

  ColorBarBullet(
      double startX, double startY, double height, Color color, this.speed) {
    position = Vector2(startX, startY);
    size = Vector2(30, height);

    // Lưu màu
    paint = Paint()..color = color.withOpacity(0.8);
  }

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), paint);
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x -= speed * dt;

    if (position.x < gameRef.battleBox.position.x - 200) {
      removeFromParent();
    }
  }
}
