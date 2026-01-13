import 'dart:async';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

// --- 1. MÀN HÌNH CHỨA GAME (WIDGET) ---
class PvZGameScreen extends StatelessWidget {
  const PvZGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: PvZGame(), // Nhúng Flame Game vào Flutter Widget
        overlayBuilderMap: {
          'GameOver': (BuildContext context, PvZGame game) {
            return Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                color: Colors.black54,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("GAME OVER!",
                        style: TextStyle(color: Colors.redAccent, fontSize: 30, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        // Reset game đơn giản bằng cách pop ra và vào lại
                        Navigator.pop(context);
                      },
                      child: const Text("Thoát"),
                    )
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }
}

// --- 2. GAME ENGINE CHÍNH ---
class PvZGame extends FlameGame with HasCollisionDetection {
  // Timer để spawn zombie
  double zombieTimer = 0;

  @override
  Future<void> onLoad() async {
    // 1. Thêm Background (Vẽ hình chữ nhật màu xanh cỏ)
    add(RectangleComponent(
      position: Vector2(0, 0),
      size: size,
      paint: Paint()..color = const Color(0xFF4CAF50), // Màu xanh cỏ
    ));

    // 2. Thêm Cây (Vẽ hình vuông màu xanh lá đậm)
    add(Plant(
        position: Vector2(100, size.y / 2), // Vị trí cây
        size: Vector2(60, 60)
    ));

    // 3. Thêm biên giới hạn bên trái (Để zombie chạm vào là thua)
    add(ScreenHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Logic sinh Zombie ngẫu nhiên mỗi 2 giây
    zombieTimer += dt;
    if (zombieTimer > 2.0) {
      zombieTimer = 0;
      // Random làn đường (lane)
      double randomY = size.y / 2; // Tạm thời 1 lane cho dễ test

      // Sinh Zombie (Hình chữ nhật màu tím)
      add(Zombie(
          position: Vector2(size.x + 50, randomY), // Xuất hiện từ ngoài màn hình phải
          size: Vector2(60, 80)
      ));
    }
  }
}

// --- 3. VIÊN ĐẠN (BULLET) - VẼ BẰNG CODE ---
class Bullet extends CircleComponent with HasGameRef<PvZGame>, CollisionCallbacks {
  final double speed = 400; // Tốc độ bay

  Bullet({required super.position, required double radius}) : super(
    radius: radius,
    paint: Paint()..color = const Color(0xFFC6FF00), // Màu xanh nõn chuối
    anchor: Anchor.center, // Neo ở giữa
  ) {
    add(CircleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    x += speed * dt; // Bay sang phải

    // Xóa đạn nếu bay ra khỏi màn hình
    if (x > gameRef.size.x) {
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    // Nếu đạn chạm Zombie
    if (other is Zombie) {
      removeFromParent(); // Xóa đạn
      other.removeFromParent(); // Xóa zombie
    }
  }
}

// --- 4. ZOMBIE (VẼ BẰNG CODE) ---
// Thay SpriteComponent bằng RectangleComponent
class Zombie extends RectangleComponent with HasGameRef<PvZGame>, CollisionCallbacks {
  final double speed = 60; // Tốc độ đi bộ

  Zombie({required super.position, required super.size}) : super(
    paint: Paint()..color = const Color(0xFF9C27B0), // Màu tím Zombie
    anchor: Anchor.center,
  ) {
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    x -= speed * dt; // Đi sang trái

    // Nếu zombie đi quá mép trái -> Game Over
    if (x < 0) {
      gameRef.overlays.add('GameOver');
      gameRef.pauseEngine(); // Dừng game
    }
  }
}

// --- 5. CÂY (PLANT - VẼ BẰNG CODE) ---
// Thay SpriteComponent bằng RectangleComponent
class Plant extends RectangleComponent with HasGameRef<PvZGame> {
  double shootTimer = 0;

  Plant({required super.position, required super.size}) : super(
    paint: Paint()..color = const Color(0xFF1B5E20), // Màu xanh lá đậm
    anchor: Anchor.center,
  );

  @override
  void update(double dt) {
    super.update(dt);

    // Tự động bắn mỗi 1 giây
    shootTimer += dt;
    if (shootTimer > 1.0) {
      shootTimer = 0;
      shoot();
    }
  }

  void shoot() {
    // Tạo đạn
    gameRef.add(Bullet(
      position: Vector2(x + width/2, y), // Bắn từ giữa cây
      radius: 10,
    ));
  }
}
