import 'dart:math' as math;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'core/game_data.dart';
import 'recycle_game_main.dart';

// --- OVERWORLD COMPONENTS (Các thành phần bản đồ) ---

class FloorTile extends SpriteComponent with HasGameRef<RecycleOverworldGame> {
  FloorTile(Vector2 pos) : super(position: pos, size: Vector2.all(32));

// Ví dụ sửa cho FloorTile
  @override
  Future<void> onLoad() async {
    try {
      sprite = await gameRef.loadSprite('floor.png');
    } catch (e) {
      print("Lỗi load ảnh floor.png: $e");
      // Nếu lỗi, vẽ tạm một khối màu tím để không bị đen màn hình
      add(RectangleComponent(size: size, paint: Paint()..color = Colors.purple));
    }
  }
}

class WallTile extends SpriteComponent with HasGameRef<RecycleOverworldGame>, CollisionCallbacks {
  WallTile(Vector2 pos) : super(position: pos, size: Vector2.all(32));

  @override
  Future<void> onLoad() async {
    // Phải có file assets/images/wall.png
    sprite = await gameRef.loadSprite('wall.png');
    add(RectangleHitbox()..collisionType = CollisionType.passive);
  }
}

// --- PILLAR TILE (FIX LỖI XUYÊN VẬT THỂ) ---
class PillarTile extends SpriteComponent with HasGameRef<RecycleOverworldGame>, CollisionCallbacks {
  PillarTile(Vector2 pos) : super(position: pos, size: Vector2.all(32));

  @override
  Future<void> onLoad() async {
    try { sprite = await gameRef.loadSprite('pillar.png'); } catch (e) {}
    // Thêm Hitbox cứng để Player không đi xuyên qua được
    add(RectangleHitbox()..collisionType = CollisionType.passive);
  }
}

class DecorationTile extends SpriteComponent with HasGameRef<RecycleOverworldGame> {
  final int type; // 1: Cỏ, 2: Hoa
  DecorationTile(Vector2 pos, this.type) : super(position: pos, size: Vector2.all(32));

  @override
  Future<void> onLoad() async {
    // Phải có grass.png hoặc flower.png
    sprite = await gameRef.loadSprite(type == 1 ? 'grass.png' : 'flower.png');
  }
}

class OverworldNPC extends SpriteComponent with HasGameRef<RecycleOverworldGame>, CollisionCallbacks {
  OverworldNPC(Vector2 pos) : super(position: pos, size: Vector2.all(32));

  @override
  Future<void> onLoad() async {
    // Phải có npc.png
    sprite = await gameRef.loadSprite('npc.png');
    add(RectangleHitbox()..collisionType = CollisionType.passive);
  }
}

enum PlayerState { up, down, left, right }

// Quay lại SpriteGroupComponent để dùng ảnh lẻ cho ổn định
class OverworldPlayer extends SpriteGroupComponent<PlayerState>
    with HasGameRef<RecycleOverworldGame>, CollisionCallbacks {

  bool canMove = true;
  final double speed = 150.0;
  double _stepTimer = 0; // Biến hỗ trợ tạo hiệu ứng bước đi

  OverworldPlayer() : super(
    size: Vector2(20, 30),
    anchor: Anchor.center,
    priority: 10,
    scale: Vector2.all(2.0),
  );

  @override
  Future<void> onLoad() async {
    // Sử dụng trực tiếp các file ảnh lẻ của bro để không bị lỗi cắt pixel
    sprites = {
      PlayerState.up: await gameRef.loadSprite('player_walkup.png'),
      PlayerState.down: await gameRef.loadSprite('player_walkdown.png'),
      PlayerState.left: await gameRef.loadSprite('player_walkleft.png'),
      PlayerState.right: await gameRef.loadSprite('player_walkright.png'),
    };

    current = PlayerState.down;

    // Hitbox ở chân để va chạm tường và nhặt đồ chuẩn hơn
    add(RectangleHitbox(
      size: Vector2(14, 8),
      position: Vector2(3, 22),
      collisionType: CollisionType.active,
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!canMove) return;

    final joystick = gameRef.joystick;

    if (joystick.direction != JoystickDirection.idle) {
      Vector2 delta = joystick.relativeDelta * speed * dt;

      // --- HIỆU ỨNG BƯỚC ĐI GIẢ (BOUNCE & TILT) ---
      _stepTimer += dt * 10;
      // Tạo hiệu ứng nghiêng người nhẹ qua lại
      angle = math.sin(_stepTimer) * 0.1;
      // Tạo hiệu ứng nhấp nhô lên xuống khi bước đi
      // Chỉnh scale nhẹ để tạo cảm giác vung chân
      scale.y = 2.0 + (math.sin(_stepTimer * 2).abs() * 0.1);

      // 1. Kiểm tra va chạm trục X
      if (!_willHitObstacle(Vector2(delta.x, 0))) {
        position.x += delta.x;
      }

      // 2. Kiểm tra va chạm trục Y
      if (!_willHitObstacle(Vector2(0, delta.y))) {
        position.y += delta.y;
      }

      // Cập nhật hướng nhìn
      if (delta.y.abs() > delta.x.abs()) {
        current = delta.y < 0 ? PlayerState.up : PlayerState.down;
      } else {
        current = delta.x < 0 ? PlayerState.left : PlayerState.right;
      }
    } else {
      // Khi đứng im thì trả về trạng thái cân bằng
      angle = 0;
      scale.y = 2.0;
      _stepTimer = 0;
    }

    // --- LOGIC SỰ KIỆN TRÊN MAP ---
    final tileSize = 48.0;
    final col = (position.x / tileSize).floor();
    final row = (position.y / tileSize).floor();

    if (row >= 0 && row < gameRef.mapLayout.length &&
        col >= 0 && col < gameRef.mapLayout[row].length) {

      final tileType = gameRef.mapLayout[row][col];

      switch (tileType) {
        case 7: // BẪY (Rung camera)
          gameRef.camera.viewfinder.add(MoveEffect.by(
              Vector2(1, 0),
              EffectController(duration: 0.05, alternate: true)
          ));
          if (math.Random().nextDouble() < 0.01) {
            GameData.currentHp -= 1;
            if (GameData.currentHp <= 0) gameRef.onBattleEnd(false);
          }
          break;

        case 8: // TELEPORT
          position = Vector2(1 * tileSize, 1 * tileSize);
          gameRef.showNotification("Hệ thống dịch chuyển tức thời!");
          break;

        case 9: // BATTLE
          canMove = false;
          gameRef.onEncounter();
          break;
      }
    }
  }

  bool _willHitObstacle(Vector2 offset) {
    // Hitbox quét vật cản dựa trên vị trí chân
    final nextHitboxRect = Rect.fromLTWH(
      position.x - size.x / 2 + 3 + offset.x,
      position.y - size.y / 2 + 22 + offset.y,
      14,
      8,
    );

    final obstacles = gameRef.world.children.where((c) =>
    c is WallTile || c is OverworldNPC || c is PillarTile
    );

    for (final obs in obstacles) {
      if (obs is PositionComponent) {
        final obsRect = Rect.fromLTWH(
          obs.position.x,
          obs.position.y,
          obs.size.x,
          obs.size.y,
        );

        if (nextHitboxRect.overlaps(obsRect)) {
          return true;
        }
      }
    }
    return false;
  }
}

// --- ITEM PICKUP (Vật phẩm nhặt được) ---

class ItemPickup extends SpriteComponent with HasGameRef<RecycleOverworldGame>, CollisionCallbacks {
  final String itemName;

  ItemPickup(this.itemName, Vector2 pos) : super(position: pos, size: Vector2.all(24));

  @override
  Future<void> onLoad() async {
    // Phải có file usb.png
    sprite = await gameRef.loadSprite('usb.png');
    add(RectangleHitbox()..collisionType = CollisionType.passive);

    // Hiệu ứng lơ lửng
    add(MoveEffect.by(
        Vector2(0, -4),
        EffectController(duration: 1, alternate: true, infinite: true)
    ));
  }

  @override
  void onCollisionStart(Set<Vector2> points, PositionComponent other) {
    super.onCollisionStart(points, other);
    if (other is OverworldPlayer) {
      GameData.inventory.add(itemName);
      gameRef.showNotification("Đã nhặt: $itemName");
      removeFromParent(); // Biến mất khi nhặt
    }
  }
}

// --- BATTLE COMPONENTS (Các thành phần trong trận đấu) ---

abstract class BaseEnemy extends PositionComponent {
  void setFace(String type);
}

class GrandpaCRT extends BaseEnemy {
  String currentFace = "IDLE";

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = Colors.grey[800]!;
    canvas.drawRRect(RRect.fromRectAndRadius(size.toRect(), const Radius.circular(5)), paint);
    final screenPaint = Paint()..color = Colors.blueGrey[900]!;
    canvas.drawRect(Rect.fromLTWH(5, 5, size.x - 10, size.y - 20), screenPaint);

    final eyeColor = (currentFace == "HAPPY")
        ? Colors.greenAccent
        : (currentFace == "SHOCKED" ? Colors.redAccent : Colors.white);

    final eyePaint = Paint()..color = eyeColor;

    if (currentFace == "HAPPY") {
      canvas.drawCircle(Offset(size.x * 0.3, size.y * 0.4), 5, eyePaint);
      canvas.drawCircle(Offset(size.x * 0.7, size.y * 0.4), 5, eyePaint);
    } else {
      canvas.drawRect(Rect.fromLTWH(size.x * 0.25, size.y * 0.3, 8, 8), eyePaint);
      canvas.drawRect(Rect.fromLTWH(size.x * 0.65, size.y * 0.3, 8, 8), eyePaint);
    }
  }

  @override
  void setFace(String type) => currentFace = type;
}

class GlitchEye extends BaseEnemy {
  @override
  void render(Canvas canvas) {
    canvas.drawOval(size.toRect(), Paint()..color = Colors.white);
    canvas.drawCircle(Offset(size.x/2, size.y/2), 10, Paint()..color = Colors.red);
  }
  @override
  void setFace(String type) {}
}

class Bullet extends PositionComponent with HasGameRef<RecycleBattleGame>, CollisionCallbacks {
  Vector2 v;
  Bullet(Vector2 p, this.v) { position = p; size = Vector2(10, 10); }

  @override
  Future<void> onLoad() async { add(CircleHitbox()); }

  @override
  void update(double dt) {
    super.update(dt);
    position += v * dt;
    if (position.x < -100 || position.x > gameRef.size.x + 100) removeFromParent();
  }

  @override
  void onCollision(Set<Vector2> points, PositionComponent other) {
    if (other is GlitchPlayer) {
      gameRef.takeDamage();
      removeFromParent();
    }
    super.onCollision(points, other);
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset(size.x/2, size.y/2), 4, Paint()..color = Colors.white);
  }
}

class HomingBullet extends Bullet {
  HomingBullet(Vector2 p, Vector2 v) : super(p, v);

  @override
  void update(double dt) {
    super.update(dt);
    final playerPos = gameRef.player.position;
    Vector2 direction = (playerPos - position).normalized();
    v += direction * 60 * dt;
    v = v.normalized() * 140;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset(size.x/2, size.y/2), 5, Paint()..color = Colors.orangeAccent);
  }
}

class ColorBarBullet extends Bullet {
  Color color;
  ColorBarBullet(double x, double y, double width, this.color, double speed)
      : super(Vector2(x, y), Vector2(-speed, 0)) { size = Vector2(width, 15); }

  @override
  void render(Canvas canvas) { canvas.drawRect(size.toRect(), Paint()..color = color); }
}

class GlitchPlayer extends PositionComponent with HasGameRef<RecycleBattleGame>, CollisionCallbacks {
  Vector2 velocity = Vector2.zero();
  String mode = "NORMAL";
  double gravity = 1000;
  double jumpStrength = -380;
  bool isGrounded = false;

  GlitchPlayer() { size = Vector2(16, 16); anchor = Anchor.center; }

  @override
  Future<void> onLoad() async { add(RectangleHitbox()); }

  void setMode(String m) { mode = m; velocity = Vector2.zero(); }

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
    if (mode == "JUMP") velocity.y += gravity * dt;
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