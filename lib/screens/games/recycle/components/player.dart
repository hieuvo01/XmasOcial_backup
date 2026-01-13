import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../recycle_game_components.dart';
import '../recycle_game_main.dart';

// --- BATTLE PLAYER ---
class GlitchPlayer extends PositionComponent with HasGameRef<RecycleBattleGame>, CollisionCallbacks {
  Vector2 velocity = Vector2.zero();
  String mode = "NORMAL";
  double gravity = 1000;
  double jumpStrength = -380;
  bool isGrounded = false;

  GlitchPlayer() {
    size = Vector2(16, 16);
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async { add(RectangleHitbox()); }

  void setMode(String m) {
    mode = m;
    velocity = Vector2.zero();
  }

  void jump() {
    if (mode == "JUMP" && isGrounded) {
      velocity.y = jumpStrength;
      isGrounded = false;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final box = gameRef.battleBox;
    if (mode == "JUMP") { velocity.y += gravity * dt; }
    position += velocity * dt;

    double limitX = box.size.x / 2 - size.x / 2;
    double limitY = box.size.y / 2 - size.y / 2;
    position.x = position.x.clamp(box.position.x - limitX, box.position.x + limitX);
    position.y = position.y.clamp(box.position.y - limitY, box.position.y + limitY);

    if (mode == "JUMP" && position.y >= box.position.y + limitY) {
      position.y = box.position.y + limitY;
      velocity.y = 0;
      isGrounded = true;
    }
  }

  @override
  void render(Canvas canvas) {
    final p = Paint()..color = (mode == "JUMP" ? Colors.blue : Colors.red);
    canvas.drawRect(size.toRect(), p);
    canvas.drawRect(size.toRect(), Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1);
  }
}

// --- OVERWORLD PLAYER ---
class OverworldPlayer extends PositionComponent with HasGameRef<RecycleOverworldGame>, CollisionCallbacks {
  bool canMove = true;
  Vector2 _lastSafePosition = Vector2.zero();
  final double speed = 150.0;

  OverworldPlayer() {
    size = Vector2(24, 28);
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(size: Vector2(16, 12), position: Vector2(4, 16)));
    _lastSafePosition = position.clone();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!canMove) return;
    _lastSafePosition = position.clone();
    final joystick = gameRef.joystick;
    if (joystick.direction != JoystickDirection.idle) {
      Vector2 moveDir = Vector2.zero();
      if (joystick.relativeDelta.x > 0.2) moveDir.x = 1;
      else if (joystick.relativeDelta.x < -0.2) moveDir.x = -1;
      if (joystick.relativeDelta.y > 0.2) moveDir.y = 1;
      else if (joystick.relativeDelta.y < -0.2) moveDir.y = -1;

      if (!moveDir.isZero()) { position.add(moveDir.normalized() * speed * dt); }
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is WallTile) { position = _lastSafePosition; }
  }

  @override
  void render(Canvas canvas) {
    final framePaint = Paint()..color = const Color(0xFFB0B0B0);
    final screenPaint = Paint()..color = const Color(0xFF333333);
    final legPaint = Paint()..color = Colors.white;
    canvas.drawRect(const Rect.fromLTWH(8, 22, 2, 6), legPaint);
    canvas.drawRect(const Rect.fromLTWH(14, 22, 2, 6), legPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(2, 4, 20, 18), const Radius.circular(3)), framePaint);
    canvas.drawRect(const Rect.fromLTWH(5, 7, 14, 12), screenPaint);
  }
}