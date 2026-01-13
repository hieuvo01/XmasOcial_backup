import 'package:flame/components.dart';
import 'package:flutter/material.dart';

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
    final eyePaint = Paint()..color = (currentFace == "HAPPY") ? Colors.greenAccent : (currentFace == "SHOCKED" ? Colors.redAccent : Colors.white);

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