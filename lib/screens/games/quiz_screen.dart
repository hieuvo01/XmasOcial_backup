// File: lib/screens/games/quiz_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:html_unescape/html_unescape.dart';
import 'package:translator/translator.dart'; // Chỉ dùng để dịch câu hỏi

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  int _timeLeft = 15;
  Timer? _timer;
  bool _isLoading = true;
  bool _gameOver = false;
  String? _selectedAnswer;
  late ConfettiController _confettiController;
  late AudioPlayer _audioPlayer;
  int _level = 1;
  final _translator = GoogleTranslator();
  final _unescape = HtmlUnescape();

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

  Future<void> _startNewGame() async {
    _timer?.cancel();
    setState(() {
      _isLoading = true;
      _gameOver = false;
      _score = 0;
      _currentIndex = 0;
      _timeLeft = 15;
      _questions = [];
      _selectedAnswer = null;
    });

    try {
      final amount = _level == 1 ? 10 : 15;
      final url = Uri.parse('https://opentdb.com/api.php?amount=$amount&type=multiple');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;

        // Chỉ dịch câu hỏi, giữ nguyên đáp án
        final translated = await Future.wait(results.map((q) async {
          final enQuestion = _unescape.convert(q['question']);
          final viQuestion = await _translator.translate(enQuestion, to: 'vi');

          final incorrect = (q['incorrect_answers'] as List).map((e) => _unescape.convert(e)).toList();
          final correct = _unescape.convert(q['correct_answer']);
          final answers = [...incorrect, correct]..shuffle();

          return {
            'question': viQuestion.text,
            'correct_answer': correct,
            'answers': answers,
          };
        }));

        setState(() {
          _questions = translated;
          _isLoading = false;
        });

        _startTimer();
      } else {
        throw Exception("Lỗi tải câu hỏi");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi: $e")),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _startTimer() {
    _timeLeft = 15;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        timer.cancel();
        _handleAnswer(null); // Hết giờ coi như sai
      }
    });
  }

  void _handleAnswer(String? selected) {
    _timer?.cancel();
    final correct = _questions[_currentIndex]['correct_answer'];
    bool isCorrect = selected == correct;

    if (isCorrect) {
      _score += 100 + (_timeLeft * 5);
      _playSound('correct.mp3');
      _confettiController.play();
    } else {
      _playSound('wrong.mp3');
      HapticFeedback.vibrate();
    }

    setState(() {
      _selectedAnswer = selected;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (_currentIndex < _questions.length - 1) {
        setState(() {
          _currentIndex++;
          _selectedAnswer = null;
        });
        _startTimer();
      } else {
        setState(() => _gameOver = true);
        _showGameOverDialog();
      }
    });
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Hoàn thành! 🎉", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Điểm số: $_score", style: const TextStyle(fontSize: 24, color: Colors.amber)),
            const SizedBox(height: 10),
            Text("Bạn trả lời đúng ${_score ~/ 100} / ${_questions.length} câu!"),
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
          if (_level < 3)
            ElevatedButton.icon(
              icon: const Icon(Icons.arrow_upward),
              label: const Text("Level tiếp"),
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

  void _playSound(String file) async {
    await _audioPlayer.play(AssetSource('sounds/$file'));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.blueGrey[50],
      appBar: AppBar(
        title: Text("Đố Vui Việt Hóa - Level $_level", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _startNewGame),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text("Đang tải & dịch câu hỏi..."),
          ],
        ),
      )
          : _gameOver
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Hoàn thành!", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
            Text("Điểm: $_score", style: const TextStyle(fontSize: 24, color: Colors.amber)),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.replay),
              label: const Text("Chơi lại"),
              onPressed: _startNewGame,
            ),
          ],
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Câu ${_currentIndex + 1}/${_questions.length}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text("Thời gian: $_timeLeft giây", style: TextStyle(fontSize: 18, color: _timeLeft > 5 ? Colors.green : Colors.red)),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _questions.length,
              backgroundColor: Colors.grey[300],
              color: Colors.blueAccent,
            ),
            const SizedBox(height: 30),

            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blueAccent, Colors.indigoAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.4), blurRadius: 20)],
              ),
              child: Text(
                _questions[_currentIndex]['question'],
                style: const TextStyle(fontSize: 20, color: Colors.white, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),

            Expanded(
              child: ListView(
                children: (_questions[_currentIndex]['answers'] as List<dynamic>).map((dynamic ansDyn) {
                  final String ans = ansDyn as String;
                  final isCorrect = ans == _questions[_currentIndex]['correct_answer'];
                  final isSelected = ans == _selectedAnswer;

                  Color bgColor = Colors.white;
                  Color textColor = Colors.black87;
                  if (_selectedAnswer != null) {
                    if (isCorrect) {
                      bgColor = Colors.greenAccent;
                      textColor = Colors.white;
                    } else if (isSelected) {
                      bgColor = Colors.redAccent;
                      textColor = Colors.white;
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: bgColor,
                          foregroundColor: textColor,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 5,
                        ),
                        onPressed: _selectedAnswer == null ? () => _handleAnswer(ans) : null,
                        child: Text(ans, style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}