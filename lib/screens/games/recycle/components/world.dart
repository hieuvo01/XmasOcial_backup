import 'dart:async' as async;
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/effects.dart';
import 'package:flame/input.dart';
import 'package:flame/palette.dart';
import 'package:flame_audio/flame_audio.dart' hide PlayerState;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/game_data.dart';
import '../recycle_game_components.dart';

class RecycleGameScreen extends StatefulWidget {
  const RecycleGameScreen({super.key});
  @override
  State<RecycleGameScreen> createState() => _RecycleGameScreenState();
}

class _RecycleGameScreenState extends State<RecycleGameScreen> {
  String currentScene = 'INTRO';
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
      body: GestureDetector(
        onTap: () => game.nextDialogue(),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned(
                bottom: 150, left: 20, right: 20,
                child: Material(
                  elevation: 10,
                  color: Colors.black.withOpacity(0.9),
                  shape: RoundedRectangleBorder(side: const BorderSide(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(5)),
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 60, height: 60, decoration: BoxDecoration(border: Border.all(color: Colors.white24)), child: const Icon(Icons.monitor, color: Colors.white, size: 30)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("* ${game.speakerName}", style: GoogleFonts.pressStart2p(color: Colors.yellowAccent, fontSize: 9)),
                              const SizedBox(height: 10),
                              Text(game.dialogueContent, style: GoogleFonts.vt323(color: Colors.white, fontSize: 20, height: 1.1)),
                              const SizedBox(height: 10),
                              Align(alignment: Alignment.bottomRight, child: Text("[Chạm để tiếp tục]", style: GoogleFonts.vt323(color: Colors.grey, fontSize: 14))),
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
    );
  }

  Widget _buildNotificationOverlay(RecycleOverworldGame game) {
    if (game.notificationText.isEmpty) return const SizedBox.shrink();
    return Positioned(
      top: 80, left: 40, right: 40,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), border: Border.all(color: Colors.yellowAccent, width: 2)),
            child: Text(game.notificationText, style: GoogleFonts.vt323(color: Colors.yellowAccent, fontSize: 24), textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }

  Widget _buildBattleMenu(RecycleBattleGame game) {
    if (game.gameState != TurnState.playerChoice) return const SizedBox.shrink();
    return Positioned(
      bottom: 20, left: 5, right: 5,
      child: Material(
        color: Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: _btn("DELETE", Colors.redAccent, () => game.onDeletePressed()))),
            Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: _btn("RESTORE", Colors.cyanAccent, () => game.onRestorePressed()))),
            Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: _btn("ITEM", Colors.greenAccent, () => game.onItemPressed()))),
            Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: _btn("MERCY", Colors.yellowAccent, () => game.onMercyPressed()))),
          ],
        ),
      ),
    );
  }

  Widget _btn(String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.black, side: BorderSide(color: color, width: 2), shape: const BeveledRectangleBorder(), padding: EdgeInsets.zero, minimumSize: const Size(60, 45)),
      onPressed: onPressed,
      child: Text(label, style: GoogleFonts.pressStart2p(color: color, fontSize: 8)),
    );
  }

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
              if (GameData.inventory.isEmpty) Text("* Túi rỗng!", style: GoogleFonts.vt323(color: Colors.grey, fontSize: 22))
              else ...GameData.inventory.map((item) => _menuBtn(item, () => game.useItem(item))),
              _menuBtn("Quay lại", () => game.backToMain()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuBtn(String text, VoidCallback onTap) {
    return TextButton(onPressed: onTap, child: Text("* $text", style: GoogleFonts.vt323(color: Colors.white, fontSize: 24)));
  }

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
            children: game.currentActs.map((act) => TextButton(onPressed: () => game.executeAct(act), child: Text("* $act", style: GoogleFonts.vt323(color: Colors.white, fontSize: 24)))).toList(),
          ),
        ),
      ),
    );
  }

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
          ElevatedButton(onPressed: () { GameData.currentHp = GameData.maxHp; _changeScene('BATTLE'); }, child: Text("KHỞI ĐỘNG LẠI", style: GoogleFonts.vt323(color: Colors.black, fontSize: 24))),
        ],
      ),
    );
  }
}

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
    if(isBossFight) { boss = GrandpaCRT(); currentActs = ["Check", "Lau màn hình", "Nói về tương lai"]; }
    else { boss = GlitchEye(); currentActs = ["Check", "Nhìn chằm chằm"]; }
    boss..size = Vector2(100, 80)..anchor = Anchor.center..position = Vector2(size.x / 2, 120);
    add(boss);
    hpText = TextComponent(text: "HP: ${GameData.currentHp}", position: Vector2(20, 20));
    add(hpText);
    battleBox = RectangleComponent(position: size / 2 + Vector2(0, 80), size: Vector2(300, 160), anchor: Anchor.center, paint: BasicPalette.white.paint()..style = PaintingStyle.stroke..strokeWidth = 3);
    add(battleBox);
    player = GlitchPlayer()..position = battleBox.position.clone()..anchor = Anchor.center;
    joystick = JoystickComponent(knob: CircleComponent(radius: 15, paint: BasicPalette.cyan.paint()), background: CircleComponent(radius: 50, paint: BasicPalette.white.withAlpha(50).paint()), margin: const EdgeInsets.only(left: 40, bottom: 120));
    add(joystick);
    dialogueText = TextBoxComponent(text: "", textRenderer: TextPaint(style: GoogleFonts.vt323(color: Colors.white, fontSize: 22)), position: Vector2(30, size.y - 140), boxConfig: TextBoxConfig(maxWidth: size.x - 60, timePerChar: 0.03));
    add(dialogueText);
    showDialogue(isBossFight ? "Grandpa CRT bắt gặp bạn và muốn kiểm tra mã nguồn của bạn!" : "Một lỗi nhỏ cản đường.");
  }

  @override
  void update(double dt) {
    super.update(dt);
    hpText.text = "HP: ${GameData.currentHp}/${GameData.maxHp} | Karma: ${GameData.karma}";
    if (gameState == TurnState.enemyTurn) {
      Vector2 finalDir = Vector2.zero();
      if (!joystick.relativeDelta.isZero()) { finalDir.x = joystick.relativeDelta.x; finalDir.y = joystick.relativeDelta.y; }
      final keys = RawKeyboard.instance.keysPressed;
      if (keys.contains(LogicalKeyboardKey.arrowLeft)) finalDir.x -= 1;
      if (keys.contains(LogicalKeyboardKey.arrowRight)) finalDir.x += 1;
      if (keys.contains(LogicalKeyboardKey.arrowUp)) finalDir.y -= 1;
      if (keys.contains(LogicalKeyboardKey.arrowDown)) finalDir.y += 1;
      double speed = 200.0;
      player.velocity.x = finalDir.x * speed;
      if (player.mode == "NORMAL") player.velocity.y = finalDir.y * speed;
      if (finalDir.length > 1.0) player.velocity.setFrom(finalDir.normalized() * speed);
      bulletTimer += dt;
      if (bulletTimer > (isBossFight ? 0.5 : 0.8)) { isBossFight ? spawnColorBars() : spawnStaticNoise(); bulletTimer = 0; }
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
    async.Timer(const Duration(seconds: 3), () { if (gameState == TurnState.dialogue) startPlayerTurn(); });
  }

  void startPlayerTurn() {
    gameState = TurnState.playerChoice;
    dialogueText.text = isSpareable ? "* Kẻ địch không muốn chiến đấu nữa." : "* Bạn sẽ làm gì?";
    overlays.add('MainMenu');
    notifyListeners();
  }

  void startEnemyTurn() {
    gameState = TurnState.enemyTurn;
    overlays.clear();
    player.position = battleBox.position.clone();
    player.setMode("NORMAL");
    add(player);
    turnTimer = 6.0;
    dialogueText.text = "CRT: 'Hệ thống đang quét... Phát hiện rác!'";
  }

  void endEnemyTurn() { showDialogue(isSpareable ? "Hành động của bạn có tác động..." : "Kẻ địch vẫn đang tấn công!"); }
  void onDeletePressed() { GameData.updateKarma(-5); friendshipMeter -= 4; showDialogue("Bạn tung cú xóa mã!"); boss.setFace("SHOCKED"); async.Timer(const Duration(seconds: 2), startEnemyTurn); }
  void onRestorePressed() { gameState = TurnState.subMenu; overlays.remove('MainMenu'); overlays.add('SubMenu'); notifyListeners(); }
  void onItemPressed() { gameState = TurnState.itemMenu; overlays.remove('MainMenu'); overlays.add('ItemMenu'); notifyListeners(); }

  void executeAct(String actName) {
    if (actName == "Lau màn hình") { friendshipMeter += 1; GameData.updateKarma(2); boss.setFace("HAPPY"); showDialogue("CRT: 'Ồ... Cảm ơn nhóc.'"); }
    else { showDialogue("Bạn thực hiện $actName."); }
    if (friendshipMeter >= 4) isSpareable = true;
    async.Timer(const Duration(seconds: 3), startEnemyTurn);
  }

  void spawnColorBars() { add(ColorBarBullet(size.x, battleBox.y + (Random().nextDouble()-0.5)*100, 80, Colors.cyan, 200)); }
  void spawnStaticNoise() { add(Bullet(Vector2(size.x, battleBox.y + (Random().nextDouble()-0.5)*100), Vector2(-150, 0))); }

  void onMercyPressed() {
    if (isSpareable) { overlays.clear(); gameState = TurnState.dialogue; dialogueText.text = "BẠN ĐÃ THA THỨ!"; FlameAudio.bgm.stop(); boss.removeFromParent(); async.Timer(const Duration(seconds: 2), () => onBattleEnd(true)); }
    else { showDialogue("Lòng trắc ẩn chưa đủ."); async.Timer(const Duration(seconds: 2), startEnemyTurn); }
  }

  void takeDamage() { GameData.currentHp -= 4; camera.viewfinder.add(MoveEffect.by(Vector2(5, 0), EffectController(duration: 0.05, repeatCount: 4, alternate: true))); if (GameData.currentHp <= 0) onBattleEnd(false); }
  void useItem(String item) { if (GameData.useItem(item)) { GameData.heal(10); showDialogue("Đã dùng $item!"); async.Timer(const Duration(seconds: 2), startEnemyTurn); } }
  void backToMain() { gameState = TurnState.playerChoice; overlays.remove('ItemMenu'); overlays.remove('SubMenu'); overlays.add('MainMenu'); notifyListeners(); }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (gameState != TurnState.enemyTurn) return KeyEventResult.ignored;
    if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.space || event.logicalKey == LogicalKeyboardKey.arrowUp)) player.jump();
    return KeyEventResult.handled;
  }
}

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

  final List<List<int>> mapLayout = [
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    [1, 2, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    [1, 0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 0, 0, 1],
    [1, 0, 1, 1, 0, 0, 0, 1, 3, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1],
    [1, 0, 0, 1, 1, 1, 0, 1, 1, 1, 0, 0, 1, 0, 1, 0, 1, 0, 0, 1],
    [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1],
    [1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1],
    [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
  ];

  @override
  Future<void> onLoad() async {
    try { FlameAudio.bgm.play('overworld.mp3', volume: 0.5); } catch (_) {}
    world = World();
    add(world);
    double tileSize = 32.0;
    for (int row = 0; row < mapLayout.length; row++) {
      for (int col = 0; col < mapLayout[row].length; col++) {
        final char = mapLayout[row][col];
        final pos = Vector2(col * tileSize, row * tileSize);
        world.add(FloorTile(pos));
        if (char == 1) world.add(WallTile(pos));
        else if (char == 2) { npcCRT = OverworldNPC(pos); world.add(npcCRT); }
        else if (char == 3) world.add(ItemPickup("USB Stick", pos + Vector2(6, 6)));
      }
    }
    player = OverworldPlayer()..position = Vector2(tileSize * 3, tileSize * 3)..anchor = Anchor.center;
    world.add(player);
    camera = CameraComponent(world: world)..follow(player);
    add(camera);
    joystick = JoystickComponent(knob: CircleComponent(radius: 20, paint: BasicPalette.cyan.paint()), background: CircleComponent(radius: 50, paint: BasicPalette.white.withAlpha(40).paint()), margin: const EdgeInsets.only(left: 40, bottom: 40));
    camera.viewport.add(joystick);
    actionButton = HudButtonComponent(button: CircleComponent(radius: 30, paint: Paint()..color = Colors.white.withAlpha(100), children: [TextComponent(text: 'A', textRenderer: TextPaint(style: GoogleFonts.pressStart2p(color: Colors.white, fontSize: 20)), anchor: Anchor.center, position: Vector2(30, 30))]), margin: const EdgeInsets.only(right: 40, bottom: 40), onPressed: () => _handleInteraction());
    camera.viewport.add(actionButton);
  }

  void showNotification(String text) {
    notificationText = text;
    if (!overlays.isActive('NotificationOverlay')) overlays.add('NotificationOverlay');
    notifyListeners();
    _notifyTimer?.cancel();
    _notifyTimer = async.Timer(const Duration(seconds: 2), () {
      notificationText = "";
      if (overlays.isActive('NotificationOverlay')) overlays.remove('NotificationOverlay');
      notifyListeners();
    });
  }

  void _handleInteraction() {
    if (showDialogue) { nextDialogue(); }
    else if (player.position.distanceTo(npcCRT.position) < 60) {
      dialogueIndex = 0;
      currentScript = GameData.inventory.contains("USB Stick")
          ? ["Cảm ơn nhóc đã tìm thấy USB!", "Đây là dữ liệu để khôi phục hệ thống.", "Sẵn sàng chưa?"]
          : ["Chào, ta là Grandpa CRT.", "Ta mất cái USB Stick rồi...", "Tìm giúp ta nhé?"];
      player.canMove = false;
      speakerName = "Grandpa CRT";
      dialogueContent = currentScript[0];
      showDialogue = true;
      overlays.add('DialogueOverlay');
      notifyListeners();
    }
  }

  void nextDialogue() {
    dialogueIndex++;
    if (dialogueIndex < currentScript.length) { dialogueContent = currentScript[dialogueIndex]; notifyListeners(); }
    else { showDialogue = false; player.canMove = true; overlays.remove('DialogueOverlay'); notifyListeners(); }
  }
}

class IntroStoryWidget extends StatefulWidget {
  final VoidCallback onIntroEnd;
  const IntroStoryWidget({super.key, required this.onIntroEnd});
  @override
  State<IntroStoryWidget> createState() => _IntroStoryWidgetState();
}

class _IntroStoryWidgetState extends State<IntroStoryWidget> {
  final List<String> _lines = ["Chào mừng đến Vùng Lãng Quên.", "Bạn là một Glitch vừa rơi xuống.", "Tìm Grandpa CRT để bắt đầu..."];
  int _idx = 0; double _op = 0.0; async.Timer? _t;
  @override
  void initState() { super.initState(); try { FlameAudio.bgm.play('start_game.flac'); } catch (_) {} _anim(); }
  void _anim() {
    if (_idx >= _lines.length) { widget.onIntroEnd(); return; }
    setState(() => _op = 1.0);
    _t = async.Timer(const Duration(seconds: 3), () {
      if (mounted) { setState(() => _op = 0.0); Future.delayed(const Duration(milliseconds: 500), () { if (mounted) { setState(() { _idx++; _anim(); }); } }); }
    });
  }
  @override
  void dispose() { _t?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) { return Scaffold(backgroundColor: Colors.black, body: Center(child: AnimatedOpacity(duration: const Duration(milliseconds: 500), opacity: _op, child: Text(_lines[_idx < _lines.length ? _idx : 0], textAlign: TextAlign.center, style: GoogleFonts.vt323(color: Colors.white, fontSize: 28))))); }
}