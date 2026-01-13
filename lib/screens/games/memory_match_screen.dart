// File: lib/screens/games/memory_match_screen.dart
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

class MemoryMatchScreen extends StatefulWidget {
  const MemoryMatchScreen({super.key});

  @override
  State<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class CardModel {
  final String id;
  final String frontEmoji;
  bool isFlipped;
  bool isMatched;
  bool isHighlighted;

  CardModel({
    required this.id,
    required this.frontEmoji,
    this.isFlipped = false,
    this.isMatched = false,
    this.isHighlighted = false,
  });
}

class _MemoryMatchScreenState extends State<MemoryMatchScreen> {
  final List<String> _emojiPool = [
    '😺', '🐶', '🐼', '🦁', '🐙', '🦄', '🍎', '🍔', '🍕', '🎮', '🚀', '🌈', '⭐', '❤️', '🔥', '💎',
  ];

  List<CardModel> _cards = [];
  int _score = 0;
  int _moves = 0;
  int _timeLeft = 60;
  Timer? _timer;
  CardModel? _firstCard;
  bool _isProcessing = false;
  int _level = 1;
  late ConfettiController _confettiController;
  late AudioPlayer _audioPlayer;
  List<String> _highlightedCardIds = [];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _audioPlayer = AudioPlayer();
    _startNewGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _confettiController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startNewGame() {
    _timer?.cancel();
    _timeLeft = 60 + (_level * 15);
    _score = 0;
    _moves = 0;
    _firstCard = null;
    _isProcessing = false;
    _highlightedCardIds.clear();

    int pairCount = _level == 1 ? 8 : (_level == 2 ? 12 : 18);
    List<String> selectedEmojis = (_emojiPool..shuffle()).take(pairCount).toList();
    List<String> gameEmojis = [...selectedEmojis, ...selectedEmojis]..shuffle();

    setState(() {
      _cards = List.generate(
        gameEmojis.length,
            (i) => CardModel(id: '$i', frontEmoji: gameEmojis[i]),
      );
    });

    _startTimer();
    _confettiController.stop();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        timer.cancel();
        _showGameOver("Hết giờ bro! 😅");
      }
    });
  }

  void _onCardTap(CardModel card) {
    if (_isProcessing || card.isFlipped || card.isMatched) return;

    _playSound('click.mp3');
    setState(() {
      card.isFlipped = true;
    });

    if (_firstCard == null) {
      _firstCard = card;
    } else {
      _moves++;
      _isProcessing = true;

      if (_firstCard!.frontEmoji == card.frontEmoji) {
        _playSound('match.mp3');
        setState(() {
          _firstCard!.isMatched = true;
          card.isMatched = true;
          _score += 100 + (_timeLeft * 2);
          _highlightedCardIds = [_firstCard!.id, card.id];
          _firstCard = null;
        });

        Timer(const Duration(milliseconds: 800), () {
          if (mounted) {
            setState(() {
              _highlightedCardIds.clear();
            });
          }
        });

        _isProcessing = false;
        _checkWin();
      } else {
        Timer(const Duration(milliseconds: 800), () {
          setState(() {
            _firstCard!.isFlipped = false;
            card.isFlipped = false;
            _firstCard = null;
            _isProcessing = false;
          });
        });
      }
    }
  }

  void _checkWin() {
    if (_cards.every((c) => c.isMatched)) {
      _timer?.cancel();
      _playSound('win.mp3');
      _confettiController.play();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Thắng lớn! 🎉", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Hoàn thành Level $_level trong $_moves bước!"),
              Text("Điểm: $_score", style: const TextStyle(fontSize: 24, color: Colors.amber)),
              if (_level < 4)
                Text(
                  "Level ${_level + 1}: ${_level == 1 ? '5x5 (12 cặp) + mờ thẻ' : _level == 2 ? '6x6 (18 cặp) + rung khi sai' : 'Infinite Mode!'}",
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _startNewGame();
              },
              child: const Text("Chơi lại"),
            ),
            if (_level < 4)
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_upward), // Fix: Dùng icon có sẵn
                label: const Text("Level tiếp"), // Fix: Thêm label bắt buộc
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => _level++);
                  _startNewGame();
                },
              ),
          ],
        ),
      );
    }
  }

  void _showGameOver(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Game Over 😢"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startNewGame();
            },
            child: const Text("Chơi lại"),
          ),
        ],
      ),
    );
  }

  void _playSound(String file) async {
    await _audioPlayer.play(AssetSource('sounds/$file'));
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8)],
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.blueGrey[50],
      appBar: AppBar(
        title: Text("Lật Hình - Level $_level", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _startNewGame),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildInfoChip("Điểm: $_score", Colors.amber),
                    _buildInfoChip("Bước: $_moves", Colors.orange),
                    _buildInfoChip("Thời gian: $_timeLeft", _timeLeft > 10 ? Colors.green : Colors.red),
                  ],
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: GridView.builder(
                    itemCount: _cards.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _level == 1 ? 4 : (_level == 2 ? 5 : 6),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemBuilder: (context, index) {
                      final card = _cards[index];
                      final isHighlighted = _highlightedCardIds.contains(card.id);

                      return GestureDetector(
                        onTap: () => _onCardTap(card),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                          transform: Matrix4.identity()..scale(isHighlighted ? 1.15 : 1.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: card.isMatched
                                  ? [Colors.greenAccent, Colors.teal]
                                  : card.isFlipped
                                  ? [Colors.blueAccent, Colors.indigo]
                                  : [Colors.grey[800]!, Colors.grey[900]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: (card.isFlipped || card.isMatched || isHighlighted
                                    ? Colors.blueAccent
                                    : Colors.black)
                                    .withOpacity(isHighlighted ? 0.8 : 0.5),
                                blurRadius: isHighlighted ? 16 : 12,
                                spreadRadius: isHighlighted ? 4 : 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: card.isFlipped || card.isMatched ? 1.0 : 0.0,
                              child: Text(
                                card.frontEmoji,
                                style: const TextStyle(fontSize: 40),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),

          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Colors.green, Colors.blue, Colors.pink, Colors.yellow],
              numberOfParticles: 150,
            ),
          ),
        ],
      ),
    );
  }
}