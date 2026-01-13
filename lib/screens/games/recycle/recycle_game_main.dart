// D:/flutter_maps/lib/screens/games/recycle_game_main.dart

import 'dart:async' as async;
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/effects.dart';
import 'package:flame/input.dart';
import 'package:flame/palette.dart';
import 'package:flame/collisions.dart';
import 'package:flame_audio/flame_audio.dart' hide PlayerState;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flame/experimental.dart';
import 'core/game_data.dart';
import 'recycle_game_components.dart';
import 'package:flame_tiled/flame_tiled.dart' hide Text, Image;
// Lưu ý: Đảm bảo class GameData và enum TurnState trong core/game_data.dart đã được xóa khỏi file này để tránh lỗi trùng lặp.

class RecycleGameScreen extends StatefulWidget {
  const RecycleGameScreen({super.key});
  @override
  State<RecycleGameScreen> createState() => _RecycleGameScreenState();
}

class _RecycleGameScreenState extends State<RecycleGameScreen> {
  String currentScene = 'INTRO';

  // Lưu instance để không bị reset khi notifyListeners hoặc nhặt đồ
  RecycleOverworldGame? _overworldGame;
  RecycleBattleGame? _battleGame;

  @override
  void initState() {
    super.initState();
    FlameAudio.bgm.stop();
    GameData.reset();
  }

  @override
  void dispose() {
    FlameAudio.bgm.stop();
    _overworldGame?.dispose();
    _battleGame?.dispose();
    super.dispose();
  }

  // Hàm chuyển cảnh sạch sẽ, dọn dẹp instance cũ nếu cần
  void _changeScene(String scene) {
    setState(() {
      currentScene = scene;
      if (scene == 'BATTLE') _overworldGame = null;
      if (scene == 'OVERWORLD') _battleGame = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildCurrentScene(),
    );
  }

  Widget _buildCurrentScene() {
    switch (currentScene) {
      case 'INTRO':
        return IntroStoryWidget(
          onIntroEnd: () => _changeScene('BATTLE'),
        );

      case 'BATTLE':
        _battleGame ??= RecycleBattleGame(
          isBossFight: !GameData.isBossDefeated,
          onBattleEnd: (bool isWin) {
            FlameAudio.bgm.stop();
            if (isWin && !GameData.isBossDefeated) {
              GameData.isBossDefeated = true;
            }
            _changeScene(isWin ? 'OVERWORLD' : 'GAME_OVER');
          },
        )..addListener(() {
          if (mounted) setState(() {});
        });

        return GameWidget(
          game: _battleGame!,
          overlayBuilderMap: {
            'MainMenu': (context, RecycleBattleGame game) => _buildBattleMenu(game),
            'SubMenu': (context, RecycleBattleGame game) => _buildSubMenu(game),
            'ItemMenu': (context, RecycleBattleGame game) => _buildItemMenu(game),
          },
        );

      case 'OVERWORLD':
        _overworldGame ??= RecycleOverworldGame(
          onEncounter: () => _changeScene('BATTLE'),
        )..addListener(() {
          if (mounted) setState(() {});
        });

        return GameWidget(
          game: _overworldGame!,
          overlayBuilderMap: {
            'DialogueOverlay': (context, RecycleOverworldGame game) => _buildDialogueOverlay(game),
            'NotificationOverlay': (context, RecycleOverworldGame game) => _buildNotificationOverlay(game),
          },
        );

      case 'GAME_OVER':
        return _buildGameOverScreen();
      default:
        return const Center(child: Text("ERROR SCENE"));
    }
  }

  Widget _buildDialogueOverlay(RecycleOverworldGame game) {
    if (!game.showDialogue) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // GestureDetector giúp bắt cú chạm của bro ngay trên lớp Flutter
          GestureDetector(
            onTap: () {
              print("DEBUG: [UI] Chạm vào màn hình để Next thoại");
              game.nextDialogue(); // Gọi trực tiếp hàm next
            },
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.transparent, // Vùng đệm trong suốt để bắt chạm toàn màn hình khi đang thoại
              child: Stack(
                children: [
                  Positioned(
                    bottom: 150, left: 20, right: 20,
                    child: Material(
                      elevation: 10,
                      color: Colors.black.withOpacity(0.9),
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: Colors.white, width: 3),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 60, height: 60,
                              decoration: BoxDecoration(border: Border.all(color: Colors.white24)),
                              child: const Icon(Icons.monitor, color: Colors.white, size: 30),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("* ${game.speakerName}",
                                      style: GoogleFonts.pressStart2p(color: Colors.yellowAccent, fontSize: 9)),
                                  const SizedBox(height: 10),
                                  Text(game.dialogueContent,
                                      style: GoogleFonts.vt323(color: Colors.white, fontSize: 20, height: 1.1)),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Text("[Chạm để tiếp tục]",
                                        style: GoogleFonts.vt323(color: Colors.grey, fontSize: 14)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- OVERLAY: THÔNG BÁO NHẶT ĐỒ ---
  Widget _buildNotificationOverlay(RecycleOverworldGame game) {
    if (game.notificationText.isEmpty) return const SizedBox.shrink();
    return Positioned(
      top: 50, left: 0, right: 0,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              border: Border.all(color: Colors.yellowAccent),
            ),
            child: Text(game.notificationText,
                style: GoogleFonts.vt323(color: Colors.yellowAccent, fontSize: 26)),
          ),
        ),
      ),
    );
  }

  // --- OVERLAY: BATTLE MENU (DELETE, RESTORE, ...) ---
  Widget _buildBattleMenu(RecycleBattleGame game) {
    if (game.gameState != TurnState.playerChoice) return const SizedBox.shrink();
    return Positioned(
      bottom: 20, left: 5, right: 5,
      child: Material(
        color: Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _btn("DELETE", Colors.redAccent, () => game.onDeletePressed()))),
            Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _btn("RESTORE", Colors.cyanAccent, () => game.onRestorePressed()))),
            Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _btn("ITEM", Colors.greenAccent, () => game.onItemPressed()))),
            Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _btn("MERCY", Colors.yellowAccent, () => game.onMercyPressed()))),
          ],
        ),
      ),
    );
  }

  Widget _btn(String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        side: BorderSide(color: color, width: 2),
        shape: const BeveledRectangleBorder(),
        padding: EdgeInsets.zero,
        minimumSize: const Size(60, 45),
      ),
      onPressed: onPressed,
      child: Text(label, style: GoogleFonts.pressStart2p(color: color, fontSize: 8)),
    );
  }

  // --- OVERLAY: MENU VẬT PHẨM ---
  Widget _buildItemMenu(RecycleBattleGame game) {
    if (game.gameState != TurnState.itemMenu) return const SizedBox.shrink();
    return Positioned(
      bottom: 100, left: 50, right: 50,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.black, border: Border.all(color: Colors.white)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (GameData.inventory.isEmpty)
                Text("* Túi rỗng!", style: GoogleFonts.vt323(color: Colors.grey, fontSize: 22))
              else
                ...GameData.inventory.map((item) => _menuBtn(item, () => game.useItem(item))),
              _menuBtn("Quay lại", () => game.backToMain()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuBtn(String text, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      child: Text("* $text", style: GoogleFonts.vt323(color: Colors.white, fontSize: 24)),
    );
  }

  // --- OVERLAY: MENU HÀNH ĐỘNG (SUB-MENU) ---
  Widget _buildSubMenu(RecycleBattleGame game) {
    if (game.gameState != TurnState.subMenu) return const SizedBox.shrink();
    return Positioned(
      bottom: 110, left: 20, right: 20,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.black, border: Border.all(color: Colors.white, width: 2)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: game.currentActs.map((act) =>
                TextButton(
                  onPressed: () => game.executeAct(act),
                  child: Text("* $act", style: GoogleFonts.vt323(color: Colors.white, fontSize: 24)),
                )
            ).toList(),
          ),
        ),
      ),
    );
  }

  // --- MÀN HÌNH GAME OVER ---
  Widget _buildGameOverScreen() {
    return Container(
      color: Colors.black, width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image, color: Colors.red, size: 80),
          const SizedBox(height: 20),
          Text("SYSTEM FAILURE", style: GoogleFonts.vt323(color: Colors.red, fontSize: 50)),
          const SizedBox(height: 50),
          ElevatedButton(
            onPressed: () {
              GameData.currentHp = GameData.maxHp;
              _changeScene('BATTLE');
            },
            child: Text("KHỞI ĐỘNG LẠI", style: GoogleFonts.vt323(color: Colors.black, fontSize: 24)),
          )
        ],
      ),
    );
  }
}

// --- BATTLE LOGIC ---
class RecycleBattleGame extends FlameGame with HasCollisionDetection, KeyboardEvents, ChangeNotifier {
  final Function(bool) onBattleEnd;
  final bool isBossFight;
  RecycleBattleGame({required this.onBattleEnd, required this.isBossFight});

  late GlitchPlayer player;
  late RectangleComponent battleBox;
  late JoystickComponent joystick;
  late BaseEnemy boss;
  late TextComponent hpText;
  late TextBoxComponent dialogueText;

  int friendshipMeter = 0;
  bool isSpareable = false;
  late List<String> currentActs;
  double bulletTimer = 0;
  double turnTimer = 0;
  TurnState gameState = TurnState.dialogue;

  @override
  Future<void> onLoad() async {
    FlameAudio.bgm.stop();
    try { FlameAudio.bgm.play('fight.flac', volume: 0.4); } catch (e) {}

    if(isBossFight) {
      boss = GrandpaCRT();
      currentActs = ["Check", "Lau màn hình", "Nói về tương lai"];
    } else {
      boss = GlitchEye();
      currentActs = ["Check", "Nhìn chằm chằm"];
    }

    boss..size = Vector2(100, 80)..anchor = Anchor.center..position = Vector2(size.x / 2, 120);
    add(boss);

    hpText = TextComponent(text: "HP: ${GameData.currentHp}", position: Vector2(20, 20));
    add(hpText);

    battleBox = RectangleComponent(
        position: size / 2 + Vector2(0, 80), size: Vector2(300, 160),
        anchor: Anchor.center,
        paint: BasicPalette.white.paint()..style = PaintingStyle.stroke..strokeWidth = 3
    );
    add(battleBox);

    player = GlitchPlayer()
      ..position = battleBox.position.clone()
      ..anchor = Anchor.center;

// 1. Chỉnh lại vị trí Joystick xuống thấp hơn (bottom: 20-40)
    joystick = JoystickComponent(
      knob: CircleComponent(radius: 15, paint: BasicPalette.cyan.paint()),
      background: CircleComponent(radius: 50, paint: BasicPalette.white.withAlpha(50).paint()),
      margin: const EdgeInsets.only(left: 40, bottom: 40), // Hạ thấp xuống đáy
    );
    add(joystick);

// 2. Đẩy đoạn hội thoại lên trên một xíu (thay vì sát đáy)
    dialogueText = TextBoxComponent(
      text: "",
      textRenderer: TextPaint(style: GoogleFonts.vt323(color: Colors.white, fontSize: 22)),
      // Chỉnh position Y: size.y - 200 (đẩy lên cao hơn so với 140 cũ)
      position: Vector2(30, size.y - 200),
      boxConfig: TextBoxConfig(maxWidth: size.x - 60, timePerChar: 0.03),
    );
    add(dialogueText);

    showDialogue(isBossFight ? "Grandpa CRT bắt gặp bạn và muốn kiểm tra mã nguồn của bạn!" : "Một lỗi nhỏ cản đường.");
  }

  @override
  void onTapDown(TapDownInfo info) {
    if (gameState == TurnState.enemyTurn) {
      player.jump();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    hpText.text = "HP: ${GameData.currentHp}/${GameData.maxHp} | Karma: ${GameData.karma}";

    if (gameState == TurnState.enemyTurn) {
      Vector2 finalDir = Vector2.zero();
      if (!joystick.relativeDelta.isZero()) {
        finalDir.x = joystick.relativeDelta.x;
        finalDir.y = joystick.relativeDelta.y;
      }
      final keys = RawKeyboard.instance.keysPressed;
      if (keys.contains(LogicalKeyboardKey.arrowLeft)) finalDir.x -= 1;
      if (keys.contains(LogicalKeyboardKey.arrowRight)) finalDir.x += 1;
      if (keys.contains(LogicalKeyboardKey.arrowUp)) finalDir.y -= 1;
      if (keys.contains(LogicalKeyboardKey.arrowDown)) finalDir.y += 1;

      double speed = 200.0;
      player.velocity.x = finalDir.x * speed;
      if (player.mode == "NORMAL") {
        player.velocity.y = finalDir.y * speed;
      }
      if (finalDir.length > 1.0) {
        player.velocity.setFrom(finalDir.normalized() * speed);
      }

      bulletTimer += dt;
      if (bulletTimer > (isBossFight ? 0.5 : 0.8)) {
        isBossFight ? spawnColorBars() : spawnStaticNoise();
        bulletTimer = 0;
      }
      turnTimer -= dt;
      if (turnTimer <= 0) endEnemyTurn();
    }
  }

  void showDialogue(String text) {
    gameState = TurnState.dialogue;
    dialogueText.text = text;
    if (player.parent != null) player.removeFromParent();
    children.whereType<Bullet>().forEach((b) => b.removeFromParent());
    overlays.clear();
    Future.delayed(const Duration(seconds: 3), () { if (gameState == TurnState.dialogue) startPlayerTurn(); });
  }

  void startPlayerTurn() {
    gameState = TurnState.playerChoice;
    dialogueText.text = isSpareable ? "* Đối phương không muốn chiến đấu nữa." : "* Bạn sẽ làm gì?";

    // Ép hiện Menu
    overlays.add('MainMenu');

    // THÊM DÒNG NÀY ĐỂ FLUTTER VẼ LẠI NÚT
    notifyListeners();
    print("DEBUG: [Battle] Đã gọi startPlayerTurn và notifyListeners");
  }

  void startEnemyTurn() {
    gameState = TurnState.enemyTurn;
    overlays.clear();
    player.position = battleBox.position.clone();
    player.setMode("NORMAL");
    add(player);
    turnTimer = 6.0;

    final quotes = [
      "CRT: 'Né cho kỹ vào!'",
      "CRT: 'Mã nguồn của ngươi quá mỏng manh.'",
      "CRT: 'Hệ thống đang quét... Phát hiện rác!'"
    ];
    dialogueText.text = quotes[Random().nextInt(quotes.length)];
  }

  void endEnemyTurn() {
    showDialogue(isSpareable ? "Hành động của bạn có tác động..." : "Kẻ địch vẫn đang tấn công!");
  }

  void onDeletePressed() {
    GameData.updateKarma(-5);
    friendshipMeter -= 4;
    showDialogue("Bạn tung cú xóa mã! HP đối phương giảm.");
    boss.setFace("SHOCKED");
    Future.delayed(const Duration(seconds: 2), startEnemyTurn);
  }

  void onRestorePressed() { gameState = TurnState.subMenu; overlays.remove('MainMenu'); overlays.add('SubMenu'); }
  void onItemPressed() { gameState = TurnState.itemMenu; overlays.remove('MainMenu'); overlays.add('ItemMenu'); }

  void executeAct(String actName) {
    switch (actName) {
      case "Check":
        showDialogue("CRT: 'Ta đã bị lỗi thời từ lâu rồi.'");
        break;
      case "Lau màn hình":
        friendshipMeter += 1;
        GameData.updateKarma(2);
        boss.setFace("HAPPY");
        showDialogue("CRT: 'Ồ... ánh sáng... Cảm ơn nhóc.'");
        break;
      case "Nói về tương lai":
        if (GameData.karma > 2) {
          friendshipMeter += 1;
          boss.setFace("BLUSH");
          showDialogue("CRT: 'Thế giới bên ngoài vẫn còn xanh sao?'");
        } else {
          boss.setFace("SHOCKED");
          showDialogue("CRT: 'Ngươi chỉ mang đến sự xóa sổ!'");
        }
        break;
    }
    if (friendshipMeter >= 2) isSpareable = true;
    Future.delayed(const Duration(seconds: 3), startEnemyTurn);
  }

  void spawnColorBars() {
    final r = Random();
    add(ColorBarBullet(size.x, battleBox.y - 60 + r.nextDouble()*120, 80, Colors.cyan, 200));
    if (r.nextDouble() > 0.7) {
      add(HomingBullet(Vector2(size.x, r.nextDouble()*size.y), Vector2(-100, 0)));
    }
  }

  void onMercyPressed() {
    if (isSpareable) {
      overlays.clear();
      gameState = TurnState.dialogue;
      dialogueText.text = "BẠN ĐÃ THA THỨ!";
      FlameAudio.bgm.stop();
      boss.removeFromParent();
      Future.delayed(const Duration(seconds: 2), () => onBattleEnd(true));
    } else {
      showDialogue("Lòng trắc ẩn chưa đủ.");
      Future.delayed(const Duration(seconds: 2), startEnemyTurn);
    }
  }

  void takeDamage() {
    GameData.currentHp -= 4;
    camera.viewfinder.add(MoveEffect.by(Vector2(5, 0), EffectController(duration: 0.05, repeatCount: 4, alternate: true)));
    if (GameData.currentHp <= 0) onBattleEnd(false);
  }

  void spawnStaticNoise() {
    add(Bullet(Vector2(size.x, battleBox.y + (Random().nextDouble()-0.5)*100), Vector2(-150, 0)));
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (gameState != TurnState.enemyTurn) return KeyEventResult.ignored;
    if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.space || event.logicalKey == LogicalKeyboardKey.arrowUp)) {
      player.jump();
    }
    return KeyEventResult.handled;
  }

  void useItem(String item) {
    if (GameData.useItem(item)) {
      GameData.heal(10);
      showDialogue("Đã sử dụng $item. Hồi 10 HP!");
      Future.delayed(const Duration(seconds: 2), startEnemyTurn);
    }
  }

  void backToMain() { gameState = TurnState.playerChoice; overlays.remove('ItemMenu'); overlays.add('MainMenu'); }
}

// --- OVERWORLD LOGIC ---
class RecycleOverworldGame extends FlameGame with HasCollisionDetection, KeyboardEvents, ChangeNotifier {
  final VoidCallback onEncounter;
  RecycleOverworldGame({required this.onEncounter});

  late OverworldPlayer player;
  late JoystickComponent joystick;
  late HudButtonComponent actionButton;
  late OverworldNPC npcCRT;
  late World world;


  bool showDialogue = false;
  String speakerName = "";
  String dialogueContent = "";
  int dialogueIndex = 0;
  List<String> currentScript = [];
  String notificationText = "";
  async.Timer? _notifyTimer;


  // CHÈN HÀM NÀY VÀO ĐÂY BRO ƠI
  void showNotification(String text) {
    notificationText = text;

    // Hiển thị Overlay thông báo trên màn hình
    if (!overlays.isActive('NotificationOverlay')) {
      overlays.add('NotificationOverlay');
    }

    // Báo cho Flutter biết để vẽ lại UI
    notifyListeners();

    // Tự động ẩn thông báo sau 2 giây
    _notifyTimer?.cancel();
    _notifyTimer = async.Timer(const Duration(seconds: 2), () {
      notificationText = "";
      if (overlays.isActive('NotificationOverlay')) {
        overlays.remove('NotificationOverlay');
      }
      notifyListeners();
    });
  }



// Map này giả định kích thước khoảng 40 cột x 25 hàng
  final List<List<int>> mapLayout = [
    // Tường bao phía trên
    List.filled(40, 1),

    // Hành lang vào (The Entrance)
    [1,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
    [1,0,0,2,0,4,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
    [1,0,0,0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
    [1,1,1,1,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],

    // Căn phòng lá đỏ (The Leaf Room - đặc trưng Undertale)
    [1,1,1,1,0,1,1,1,1,0,0,0,0,0,0,0,0,0,1,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
    [1,0,0,0,0,0,0,0,0,0,6,6,6,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
    [1,0,0,0,0,0,0,0,0,6,6,6,6,6,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
    [1,0,0,0,0,0,0,0,0,0,6,6,6,0,0,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
    [1,1,1,1,0,1,1,1,1,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1],

    // Khu vực bẫy Glitch và hành lang dài
    [1,1,1,1,0,1,1,1,1,1,1,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1],
    [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
    [1,0,5,5,0,0,7,7,7,0,0,5,5,0,0,7,7,7,0,0,5,5,0,0,7,7,7,0,0,5,5,0,0,0,4,0,0,0,0,1],
    [1,0,5,5,0,0,7,7,7,0,0,5,5,0,0,7,7,7,0,0,5,5,0,0,7,7,7,0,0,5,5,0,0,0,0,0,0,0,0,1],
    [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
  ];

  @override
  Future<void> onLoad() async {
    world = World();
    add(world);

    const double tileSize = 48.0; // Kích thước mỗi ô vuông

    // 1. VÒNG LẶP DỰNG MAP
    for (int row = 0; row < mapLayout.length; row++) {
      for (int col = 0; col < mapLayout[row].length; col++) {
        final char = mapLayout[row][col];
        final pos = Vector2(col * tileSize, row * tileSize);

        // Luôn vẽ nền tím (Floor) bên dưới mọi thứ
        world.add(FloorTile(pos)..size = Vector2.all(tileSize)..priority = 0);

// Trong vòng lặp mapLayout
        switch (char) {
          case 1:
            world.add(WallTile(pos)..size = Vector2.all(tileSize)); break;
          case 2:
            npcCRT = OverworldNPC(pos)..size = Vector2.all(tileSize);
            world.add(npcCRT); break;
          case 3:
            world.add(ItemPickup("USB Stick", pos + Vector2(12, 12))); break;
          case 4:
            world.add(PillarTile(pos)..size = Vector2.all(tileSize)..priority = 15); break;

        // Đối với các ô trang trí, chỉ cần truyền pos và type (ID)
          case 5: // Cỏ
            world.add(DecorationTile(pos, 1)..size = Vector2.all(tileSize)); break;
          case 6: // LÁ ĐỎ
            world.add(DecorationTile(pos, 3)..size = Vector2.all(tileSize)); break;
          case 7: // Bẫy
            world.add(DecorationTile(pos, 4)..size = Vector2.all(tileSize)); break;
          case 8: // Cổng
            world.add(DecorationTile(pos, 5)..size = Vector2.all(tileSize)); break;
        }
      }
    }

    // 2. KHỞI TẠO PLAYER
    // Tọa độ spawn nên là một ô trống (số 0) trong mapLayout của bro
    player = OverworldPlayer()
      ..position = Vector2(2 * tileSize, 2 * tileSize)
      ..anchor = Anchor.center;
    world.add(player);



    // 3. THIẾT LẬP CAMERA (CỰC KỲ QUAN TRỌNG VỚI MAP TO)
    camera = CameraComponent(world: world)..follow(player);

    final mapWidth = mapLayout[0].length * 48.0;
    final mapHeight = mapLayout.length * 48.0;

    camera.setBounds(Rectangle.fromLTWH(0, 0, mapWidth, mapHeight));
    camera.viewfinder.zoom = 1.2; // Zoom lại gần chút cho giống Undertale


    add(camera);

    // JOYSTICK (Gắn vào viewport để nó đứng im khi camera di chuyển)
    joystick = JoystickComponent(
        knob: CircleComponent(radius: 20, paint: BasicPalette.cyan.paint()),
        background: CircleComponent(radius: 50, paint: BasicPalette.white.withAlpha(40).paint()),
        margin: const EdgeInsets.only(left: 40, bottom: 40)
    );
    camera.viewport.add(joystick);

    // NÚT TƯƠNG TÁC
    actionButton = HudButtonComponent(
      button: CircleComponent(
          radius: 30,
          paint: Paint()..color = Colors.white.withAlpha(100)..style = PaintingStyle.fill,
          children: [
            TextComponent(
                text: 'A',
                textRenderer: TextPaint(style: GoogleFonts.pressStart2p(color: Colors.white, fontSize: 20)),
                anchor: Anchor.center,
                position: Vector2(30, 30)
            )
          ]
      ),
      margin: const EdgeInsets.only(right: 40, bottom: 40),
      onPressed: () => _handleInteraction(),
    );
    camera.viewport.add(actionButton);
  }

// Trong class RecycleOverworldGame (recycle_game_main.dart)

// --- TRONG CLASS RecycleOverworldGame ---

  void _handleInteraction() {
    print("DEBUG: [Interaction] Nút A được nhấn. showDialogue: $showDialogue");

    if (showDialogue) {
      // Nếu đang hiện thoại, nhấn A để sang câu tiếp theo
      nextDialogue();
    } else {
      // Nếu không hiện thoại, kiểm tra khoảng cách tới NPC
      double distance = player.position.distanceTo(npcCRT.position);
      print("DEBUG: [Interaction] Khoảng cách tới NPC: $distance");

      if (distance < 60) {
        print("DEBUG: [Interaction] Đủ gần! Bắt đầu hội thoại.");
        _startCRTConversation();
      }
    }
  }

  void onBattleEnd(bool playerWon) {
    if (!playerWon) {
      showNotification("Hệ thống sụp đổ! Đang khởi động lại...");
      // Reset máu và đưa về vị trí spawn sau 2 giây
      Future.delayed(const Duration(seconds: 2), () {
        GameData.currentHp = GameData.maxHp;
        player.position = Vector2(3 * 48, 2 * 48); // Tọa độ spawn ban đầu
        player.canMove = true;
      });
    } else {
      showNotification("Chiến thắng! Glitch đã bị xóa bỏ.");
    }
  }

  void _startCRTConversation() {
    dialogueIndex = 0;
    // Kiểm tra xem đã nhặt USB chưa để đổi nội dung thoại
    if (GameData.inventory.contains("USB Stick")) {
      currentScript = [
        "Cảm ơn nhóc đã tìm thấy cái USB này!",
        "Đây là dữ liệu quan trọng để khôi phục hệ thống.",
        "Nhóc sẵn sàng bắt đầu hành trình chưa?"
      ];
    } else {
      currentScript = [
        "Chào nhóc, ta là Grandpa CRT.",
        "Ta bị mất cái USB Stick ở gần đây...",
        "Nhóc có thể tìm giúp ta không?"
      ];
    }

    // Khóa di chuyển và bắt đầu câu đầu tiên
    player.canMove = false;
    startDialogue("Grandpa CRT", currentScript[dialogueIndex]);
  }

  void nextDialogue() {
    dialogueIndex++;
    print("DEBUG: [Dialogue] Chuyển tới index: $dialogueIndex");

    if (dialogueIndex < currentScript.length) {
      // Vẫn còn câu thoại tiếp theo
      dialogueContent = currentScript[dialogueIndex];
      notifyListeners();
    } else {
      // ĐÃ HẾT CÂU THOẠI -> KẾT THÚC
      print("DEBUG: [Dialogue] Hết thoại, đang đóng Overlay và mở khóa di chuyển.");

      showDialogue = false;
      dialogueIndex = 0;

      // Quan trọng nhất: Mở khóa cho player đi lại
      player.canMove = true;

      // Xóa Overlay và báo cho Flutter ẩn widget
      if (overlays.isActive('DialogueOverlay')) {
        overlays.remove('DialogueOverlay');
      }

      notifyListeners();
    }
  }

  void startDialogue(String name, String content) {
    print("DEBUG: [Dialogue] Hiển thị thoại: $name - $content");
    speakerName = name;
    dialogueContent = content;
    showDialogue = true;

    if (!overlays.isActive('DialogueOverlay')) {
      overlays.add('DialogueOverlay');
    }

    notifyListeners();
  }

}

// --- INTRO STORY WIDGET ---
class IntroStoryWidget extends StatefulWidget {
  final VoidCallback onIntroEnd;
  const IntroStoryWidget({super.key, required this.onIntroEnd});
  @override
  State<IntroStoryWidget> createState() => _IntroStoryWidgetState();
}

class _IntroStoryWidgetState extends State<IntroStoryWidget> {
  final List<String> _lines = [
    "Ngày xửa ngày xưa...\nÀ không, làm gì còn ngày xưa nữa.",
    "Chào mừng đến với Vùng Lãng Quên (The Oblivion).",
    "Bạn là Glitch.\nMột lỗi nhỏ vừa rơi xuống đây.",
    "Đi tìm Grandpa CRT để biết thêm chi tiết..."
  ];
  int _currentIndex = 0;
  double _opacity = 0.0;
  async.Timer? _timer;

  @override
  void initState() {
    super.initState();
    try { FlameAudio.bgm.play('start_game.flac', volume: 0.5); } catch (_) {}
    _startAnimation();
  }
  void _startAnimation() {
    if (_currentIndex >= _lines.length) { widget.onIntroEnd(); return; }
    setState(() => _opacity = 1.0);
    _timer = async.Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _opacity = 0.0);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) { setState(() { _currentIndex++; _startAnimation(); }); }
        });
      }
    });
  }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: _opacity,
          child: Text(_lines[_currentIndex < _lines.length ? _currentIndex : 0],
              textAlign: TextAlign.center, style: GoogleFonts.vt323(color: Colors.white, fontSize: 28)),
        ),
      ),
    );
  }
}