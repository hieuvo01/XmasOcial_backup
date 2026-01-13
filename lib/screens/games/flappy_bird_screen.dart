import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:audioplayers/audioplayers.dart';

class FlappyBirdScreen extends StatefulWidget {
  const FlappyBirdScreen({super.key});

  @override
  State<FlappyBirdScreen> createState() => _FlappyBirdScreenState();
}

class _FlappyBirdScreenState extends State<FlappyBirdScreen> with SingleTickerProviderStateMixin {
  // --- CẤU HÌNH VẬT LÝ ---
  static double birdY = 0;
  double currentVelocity = 0;

  double gravity = 5.0;
  double jumpStrength = -1.5;
  double barrierSpeed = 1.0; // Tốc độ di chuyển cảnh

  double birdWidth = 0.1;
  double birdHeight = 0.1;
  double birdHalfHeight = 0.05;
  double birdHalfWidth = 0.05;

  // --- TRẠNG THÁI GAME ---
  bool gameHasStarted = false;
  int score = 0;
  int bestScore = 0;
  bool isDayTime = true;

  // --- ÂM THANH ---
  final AudioPlayer _wingPlayer = AudioPlayer();
  final AudioPlayer _pointPlayer = AudioPlayer();
  final AudioPlayer _hitPlayer = AudioPlayer();

  // --- ANIMATION CHIM ---
  int birdFrame = 0;
  int frameCounter = 0;
  final List<String> birdSprites = [
    'assets/fb/bluebird-midflap.png',
    'assets/fb/bluebird-upflap.png',
    'assets/fb/bluebird-downflap.png',
  ];

  // --- CẤU HÌNH CỘT ---
  static const double pipeSpacing = 1.2;
  static const double barrierWidth = 0.15;
  static const int totalPipes = 3;
  static const double fixedVerticalGap = 0.4;

  // List chứa vị trí X của 3 cột
  List<double> barrierX = [];

  // List chứa chiều cao [trên, dưới] của 3 cột
  List<List<double>> barrierHeight = [];

  late Ticker _gameTicker;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    isDayTime = Random().nextBool();

    _wingPlayer.setReleaseMode(ReleaseMode.stop);
    _pointPlayer.setReleaseMode(ReleaseMode.stop);
    _hitPlayer.setReleaseMode(ReleaseMode.stop);

    // Khởi tạo cột ban đầu
    _initPipes();

    _gameTicker = createTicker((elapsed) {
      if (gameHasStarted) {
        double dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
        _lastElapsed = elapsed;
        if (dt > 0.05) dt = 0.05;
        _updateGame(dt);
      } else {
        _lastElapsed = elapsed;
      }
    });
  }

  // Hàm khởi tạo 3 cột ban đầu
  void _initPipes() {
    barrierX.clear();
    barrierHeight.clear();

    for (int i = 0; i < totalPipes; i++) {
      barrierX.add(2.0 + (i * pipeSpacing));
      barrierHeight.add(_getRandomHeight());
    }
  }

  // Hàm tính chiều cao ngẫu nhiên
  List<double> _getRandomHeight() {
    double minTop = 0.2;
    double maxTop = 2.0 - fixedVerticalGap - 0.2;
    double topHeight = minTop + Random().nextDouble() * (maxTop - minTop);
    double bottomHeight = 2.0 - fixedVerticalGap - topHeight;
    return [topHeight, bottomHeight];
  }

  @override
  void dispose() {
    _gameTicker.dispose();
    _wingPlayer.dispose();
    _pointPlayer.dispose();
    _hitPlayer.dispose();
    super.dispose();
  }

  void _playSound(String type) async {
    try {
      if (type == 'wing') {
        await _wingPlayer.stop();
        await _wingPlayer.play(AssetSource('sounds/wing.wav'));
      } else if (type == 'point') {
        await _pointPlayer.stop();
        await _pointPlayer.play(AssetSource('sounds/point.wav'));
      } else if (type == 'hit') {
        await _hitPlayer.stop();
        await _hitPlayer.play(AssetSource('sounds/hit.wav'));
      }
    } catch (e) {
      debugPrint("Sound error: $e");
    }
  }

  void _updateGame(double dt) {
    setState(() {
      currentVelocity += gravity * dt;
      birdY += currentVelocity * dt;

      for (int i = 0; i < barrierX.length; i++) {
        barrierX[i] -= barrierSpeed * dt;
      }

      frameCounter++;
      if (frameCounter % 8 == 0) {
        birdFrame = (birdFrame + 1) % 3;
      }

      for (int i = 0; i < barrierX.length; i++) {
        if (barrierX[i] < -1.5) {
          barrierX[i] += (totalPipes * pipeSpacing);
          barrierHeight[i] = _getRandomHeight();
          score++;
          _playSound('point');
        }
      }

      if (birdIsDead()) {
        _gameTicker.stop();
        _playSound('hit');
        _showDialog();
      }
    });
  }

  void startGame() {
    setState(() {
      gameHasStarted = true;
      score = 0;
      birdY = 0;
      currentVelocity = 0;
      _initPipes();
      _playSound('wing');
      _gameTicker.start();
    });
  }

  void jump() {
    setState(() {
      currentVelocity = jumpStrength;
      _playSound('wing');
    });
  }

  bool birdIsDead() {
    // Va chạm sàn (chỉ dưới, không trần)
    if (birdY + birdHalfHeight > 1) return true;

    // Va chạm cột (kiểm tra bounding box chính xác hơn)
    for (int i = 0; i < barrierX.length; i++) {
      double pipeLeft = barrierX[i] - (barrierWidth / 2);
      double pipeRight = barrierX[i] + (barrierWidth / 2);
      double birdLeft = -birdHalfWidth;
      double birdRight = birdHalfWidth;
      double birdTop = birdY - birdHalfHeight;
      double birdBottom = birdY + birdHalfHeight;

      double upperPipeBottom = -1 + barrierHeight[i][0];
      double lowerPipeTop = 1 - barrierHeight[i][1];

      // Kiểm tra chồng chéo ngang
      bool horizontalOverlap = birdRight >= pipeLeft && birdLeft <= pipeRight;

      if (horizontalOverlap) {
        // Va chạm cột trên
        if (birdTop <= upperPipeBottom) {
          return true;
        }
        // Va chạm cột dưới
        if (birdBottom >= lowerPipeTop) {
          return true;
        }
      }
    }
    return false;
  }

  Widget _buildImageScore(int number, {double height = 30}) {
    List<String> digits = number.toString().split('');
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits.map((digit) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Image.asset(
            'assets/fb/$digit.png',
            height: height,
            fit: BoxFit.contain,
            errorBuilder: (c, o, s) => Text(digit, style: const TextStyle(fontSize: 30, color: Colors.white)),
          ),
        );
      }).toList(),
    );
  }

  void _showDialog() {
    if (score > bestScore) {
      bestScore = score;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/fb/gameover.png', width: 200, fit: BoxFit.contain,
                errorBuilder: (c, o, s) => const Text("GAME OVER", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.red)),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: const Color(0xFFDED895),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF543847), width: 4)
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("SCORE", style: TextStyle(color: Color(0xFFE9603D), fontWeight: FontWeight.bold)),
                        _buildImageScore(score, height: 25),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("BEST", style: TextStyle(color: Color(0xFFE9603D), fontWeight: FontWeight.bold)),
                        _buildImageScore(bestScore, height: 25),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    gameHasStarted = false;
                    birdY = 0;
                    currentVelocity = 0;
                    _initPipes();
                    isDayTime = Random().nextBool();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                      color: Colors.lightGreen,
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(5)
                  ),
                  child: const Text("PLAY AGAIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          if (gameHasStarted) {
            jump();
          } else {
            startGame();
          }
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                isDayTime ? 'assets/fb/background-day.png' : 'assets/fb/background-night.png',
                fit: BoxFit.fill,
                errorBuilder: (c, o, s) => Container(color: Colors.lightBlue[300]),
              ),
            ),

            Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      // CHIM
                      AnimatedContainer(
                        alignment: Alignment(0, birdY),
                        duration: const Duration(milliseconds: 0),
                        child: SizedBox(
                          height: 50,
                          width: 50,
                          child: Transform.rotate(
                            angle: gameHasStarted
                                ? (currentVelocity * 5).clamp(-0.8, 0.8)
                                : 0,
                            child: Image.asset(
                              birdSprites[birdFrame],
                              fit: BoxFit.contain,
                              errorBuilder: (c, o, s) => const Icon(Icons.flutter_dash, color: Colors.yellow, size: 45),
                            ),
                          ),
                        ),
                      ),

                      // CỘT
                      ...List.generate(barrierX.length, (index) {
                        return Stack(
                          children: [
                            AnimatedContainer(
                              alignment: Alignment(barrierX[index], -1.1),
                              duration: const Duration(milliseconds: 0),
                              child: SizedBox(
                                width: 70,
                                height: MediaQuery.of(context).size.height * 3/4 * barrierHeight[index][0] / 2,
                                child: RotatedBox(
                                  quarterTurns: 2,
                                  child: Image.asset(
                                    'assets/fb/pipe-green.png',
                                    fit: BoxFit.fill,
                                    errorBuilder: (c, o, s) => Container(color: Colors.green),
                                  ),
                                ),
                              ),
                            ),
                            AnimatedContainer(
                              alignment: Alignment(barrierX[index], 1.1),
                              duration: const Duration(milliseconds: 0),
                              child: SizedBox(
                                width: 70,
                                height: MediaQuery.of(context).size.height * 3/4 * barrierHeight[index][1] / 2,
                                child: Image.asset(
                                  'assets/fb/pipe-green.png',
                                  fit: BoxFit.fill,
                                  errorBuilder: (c, o, s) => Container(color: Colors.green),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),

                      // MÀN HÌNH CHỜ
                      Container(
                        alignment: const Alignment(0, -0.3),
                        child: gameHasStarted
                            ? _buildImageScore(score, height: 50)
                            : Image.asset(
                          'assets/fb/message.png',
                          width: 200,
                          fit: BoxFit.contain,
                          errorBuilder: (c, o, s) => const Text("CHẠM ĐỂ BAY", style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold)),
                        ),
                      ),

                      // Nút back
                      Positioned(
                        top: 40, left: 10,
                        child: CircleAvatar(
                          backgroundColor: Colors.black26,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                            onPressed: () {
                              if (_gameTicker.isActive) _gameTicker.stop();
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      )
                    ],
                  ),
                ),

                // MẶT ĐẤT
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/fb/base.png'),
                        fit: BoxFit.cover,
                      )
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}