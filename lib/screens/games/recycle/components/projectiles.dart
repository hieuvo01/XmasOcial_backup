import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../recycle_game_main.dart';
import 'player.dart'; // Cần để check va chạm với GlitchPlayer

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
      : super(Vector2(x, y), Vector2(-speed, 0)) {
    size = Vector2(width, 15);
  }
  @override
  void render(Canvas canvas) { canvas.drawRect(size.toRect(), Paint()..color = color); }
}