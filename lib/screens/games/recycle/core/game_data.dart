import 'package:flame/components.dart';
import 'package:flutter/material.dart';

enum TurnState { playerChoice, subMenu, itemMenu, dialogue, enemyTurn, gameOver, win }

class GameData {
// Thêm 'static' vào trước 'const' như thế này bro nhé:
  static const int T_FLOOR = 0;
  static const int T_WALL = 1;
  static const int T_NPC = 2;
  static const int T_ITEM = 3;
  static const int T_PILLAR = 4;
  static const int T_GRASS = 5;
  static const int T_FLOWER = 6;
  static int currentHp = 20;
  static int maxHp = 20;
  static List<String> inventory = ["USB Stick"];
  static Vector2 lastOverworldPosition = Vector2(-100, 0);
  static bool isBossDefeated = false;
  static int karma = 0;
  static bool metSirTeddy = false;

// Thêm dòng này vào class GameData

  static final ValueNotifier<String?> notificationNotifier = ValueNotifier(null);
  static void updateKarma(int change) {
    karma += change;
    debugPrint("Hệ thống Karma: $karma");
  }

  static void heal(int amount) {
    currentHp = (currentHp + amount).clamp(0, maxHp);
  }

  static bool useItem(String item) {
    if (inventory.contains(item)) {
      inventory.remove(item);
      return true;
    }
    return false;
  }

  static void reset() {
    currentHp = 20;
    inventory = ["USB Stick"];
    lastOverworldPosition = Vector2(-100, 0);
    isBossDefeated = false;
    karma = 0;
  }
}