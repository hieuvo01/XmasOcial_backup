// File: lib/screens/games/bau_cua_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BauCuaScreen extends StatefulWidget {
  const BauCuaScreen({super.key});

  @override
  State<BauCuaScreen> createState() => _BauCuaScreenState();
}

class Mascot {
  String id;
  String name;
  String asset;
  Color color;
  String? unlockedSkin;

  Mascot(this.id, this.name, this.asset, this.color, {this.unlockedSkin});
}

class _BauCuaScreenState extends State<BauCuaScreen> with SingleTickerProviderStateMixin {
  final List<Mascot> mascots = [
    Mascot('deer', 'Nai', '🦌', Colors.brown),
    Mascot('gourd', 'Bầu', '🍐', Colors.green),
    Mascot('chicken', 'Gà', '🐓', Colors.orange),
    Mascot('fish', 'Cá', '🐟', Colors.blue),
    Mascot('crab', 'Cua', '🦀', Colors.redAccent),
    Mascot('shrimp', 'Tôm', '🦐', Colors.deepOrange),
  ];

  List<String> resultDice = ['🦌', '🍐', '🐓'];
  Map<String, int> bets = {};
  int balance = 1000;
  int level = 1;
  int winStreak = 0;
  bool isRolling = false;
  late AnimationController _controller;
  late ConfettiController _confettiController;
  late AudioPlayer _audioPlayer;
  DateTime? lastLogin;
  final List<int> betLevels = [50, 100, 200];
  int selectedBetAmount = 100;
  bool _hasCheckedDaily = false; // Flag tránh gọi nhiều lần

  @override
  void initState() {
    super.initState();
    for (var m in mascots) {
      bets[m.id] = 0;
    }
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
    _audioPlayer = AudioPlayer();

    // Load data và check daily reward sau khi mount xong
    _loadDataAndCheckDaily();
  }

  Future<void> _loadDataAndCheckDaily() async {
    await _loadData();
    // Đợi frame đầu tiên render xong rồi mới check daily (context an toàn)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasCheckedDaily && mounted) {
        _checkDailyReward();
        _hasCheckedDaily = true;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _confettiController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final newBalance = prefs.getInt('balance') ?? 1000;
    final newLevel = prefs.getInt('level') ?? 1;
    final newLastLogin = DateTime.tryParse(prefs.getString('lastLogin') ?? '');
    if (mounted) {
      setState(() {
        balance = newBalance;
        level = newLevel;
        lastLogin = newLastLogin;
        if (level >= 5) mascots[0].unlockedSkin = '🦌💛';
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('balance', balance);
    prefs.setInt('level', level);
    prefs.setString('lastLogin', DateTime.now().toIso8601String());
  }

  void _checkDailyReward() {
    if (lastLogin == null || DateTime.now().difference(lastLogin!).inDays >= 1) {
      final reward = 200 + (level * 50);
      if (mounted) {
        setState(() {
          balance += reward;
        });
        _showToast("Daily reward: +$reward xu!");
        _saveData();
      }
    }
  }

  void _placeBet(String id, int amount) {
    if (isRolling) return;
    if (balance >= amount) {
      setState(() {
        bets[id] = bets[id]! + amount;
        balance -= amount;
      });
      _saveData();
    } else {
      _handleNoMoney();
    }
  }

  void _resetBet(String id) {
    if (isRolling) return;
    setState(() {
      balance += bets[id]!;
      bets[id] = 0;
    });
    _saveData();
  }

  void _handleNoMoney() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Hết tiền bro! 😢"),
        content: const Text("Xem ads để nhận 500 xu? (Giả lập 5s)"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Timer(const Duration(seconds: 5), () {
                if (mounted) {
                  setState(() {
                    balance += 500;
                  });
                  _showToast("Nhận 500 xu từ ads!");
                  _saveData();
                }
              });
            },
            child: const Text("Xem ads"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Thôi"),
          ),
        ],
      ),
    );
  }

  void _rollDice() {
    if (isRolling || bets.values.every((v) => v == 0)) return;

    setState(() => isRolling = true);
    _controller.repeat();
    _playSound('shake.mp3');

    Timer(const Duration(seconds: 2), () {
      _controller.stop();
      Random random = Random();
      setState(() {
        resultDice = [
          mascots[random.nextInt(6)].asset,
          mascots[random.nextInt(6)].asset,
          mascots[random.nextInt(6)].asset,
        ];
        isRolling = false;
        _calculateResult();
      });
    });
  }

  void _calculateResult() {
    int totalWin = 0;
    bool isJackpot = resultDice.toSet().length == 1;
    double multiplier = 1.0 + (winStreak * 0.5);

    bets.forEach((key, betAmount) {
      if (betAmount > 0) {
        String mascotAsset = mascots.firstWhere((m) => m.id == key).asset;
        int count = resultDice.where((d) => d == mascotAsset).length;
        if (count > 0) {
          int win = (betAmount + (betAmount * count)) * multiplier.toInt();
          if (isJackpot) win *= 2;
          totalWin += win;
        }
      }
    });

    if (totalWin > 0) {
      setState(() {
        balance += totalWin;
        winStreak++;
        if (totalWin > 1000) _confettiController.play();
        _playSound('win.mp3');
        levelUp();
      });
    } else {
      winStreak = 0;
      _playSound('lose.mp3');
    }
    _showResultDialog(totalWin);
    setState(() {
      for (var k in bets.keys) {
        bets[k] = 0;
      }
    });
    _saveData();
  }

  void levelUp() {
    if (balance > level * 1000) {
      level++;
      _showToast("Level up! Level $level - Unlock bonus!");
      if (level == 5) mascots[0].unlockedSkin = '🦌💛';
    }
  }

  void _showResultDialog(int winAmount) {
    showDialog(
      context: context,
      builder: (_) => Stack(
        children: [
          AlertDialog(
            title: const Text("Kết quả! 🎉"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: resultDice.map((e) => Text(e, style: const TextStyle(fontSize: 40))).toList(),
                ),
                const SizedBox(height: 20),
                Text(winAmount > 0 ? "Bạn thắng: +$winAmount xu (Streak x${1 + (winStreak * 0.5)})" : "Thua rồi bro!"),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tiếp tục"))],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
            ),
          ),
        ],
      ),
    );
  }

  void _playSound(String file) async {
    await _audioPlayer.play(AssetSource('sounds/$file'));
  }

  void _showToast(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Bầu Cua Level $level", style: TextStyle(color: textColor)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text("$balance xu", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.red[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.redAccent, width: 2),
              ),
              child: Center(
                child: isRolling
                    ? RotationTransition(
                  turns: _controller,
                  child: const Icon(Icons.autorenew, size: 80, color: Colors.grey),
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: resultDice.map((e) => Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 50)),
                  )).toList(),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: betLevels.map((level) => Padding(
                padding: const EdgeInsets.all(4.0),
                child: ChoiceChip(
                  label: Text("$level"),
                  selected: selectedBetAmount == level,
                  onSelected: (bool selected) {
                    setState(() => selectedBetAmount = level);
                  },
                ),
              )).toList(),
            ),
          ),

          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GridView.builder(
                itemCount: mascots.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.8,
                ),
                itemBuilder: (context, index) {
                  final m = mascots[index];
                  String displayAsset = m.unlockedSkin ?? m.asset;
                  return GestureDetector(
                    onTap: () => _placeBet(m.id, selectedBetAmount),
                    onLongPress: () => _resetBet(m.id),
                    child: Container(
                      decoration: BoxDecoration(
                        color: m.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: m.color, width: 2),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(displayAsset, style: const TextStyle(fontSize: 40)),
                          Text(m.name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                            child: Text("${bets[m.id]}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isRolling ? null : _rollDice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                child: Text(isRolling ? "Đang lắc..." : "LẮC NGAY", style: const TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}