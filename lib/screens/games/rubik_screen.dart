// File: lib/screens/games/rubik_screen.dart
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cube/flutter_cube.dart';

class RubikScreen extends StatefulWidget {
  const RubikScreen({super.key});

  @override
  State<RubikScreen> createState() => _RubikScreenState();
}

class _RubikScreenState extends State<RubikScreen> with TickerProviderStateMixin {
  late Scene _scene;
  Object? _rubik;
  final List<Object> _cubies = [];

  // Animation xoay layer
  late AnimationController _rotateController;
  double _currentAngle = 0;
  bool _isRotating = false;

  // Sound
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Confetti khi solve xong (demo)
  late ConfettiController _confettiController;

  // Màu sắc
  final Color cWhite = Colors.white;
  final Color cYellow = Colors.yellow;
  final Color cRed = Colors.red;
  final Color cOrange = Colors.orange;
  final Color cGreen = Colors.green;
  final Color cBlue = Colors.blue;
  final Color cBlack = const Color(0xFF111111);

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _confettiController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onSceneCreated(Scene scene) {
    _scene = scene;
    _scene.camera.position.setValues(6, 6, 6);
    _scene.camera.target.setValues(0, 0, 0);
    _scene.light.position.setValues(10, 10, 10);
    _scene.light.ambient.setValues(0.8, 0.8, 0.8);

    _generateRubik();
  }

  void _generateRubik() {
    if (_rubik != null) _scene.world.remove(_rubik!);
    _cubies.clear();

    _rubik = Object(name: 'rubik');
    for (int x = -1; x <= 1; x++) {
      for (int y = -1; y <= 1; y++) {
        for (int z = -1; z <= 1; z++) {
          final cubie = _createCubie(x, y, z);
          _rubik!.add(cubie);
          _cubies.add(cubie);
        }
      }
    }
    _scene.world.add(_rubik!);
  }

  Object _createCubie(int x, int y, int z) {
    final cubie = Object(
      position: Vector3(x * 1.05, y * 1.05, z * 1.05),
      scale: Vector3.all(1.0),
    );

    // Core đen
    final core = Object(scale: Vector3.all(0.95));
    core.mesh.material.diffuse = Vector3(0.1, 0.1, 0.1);
    cubie.add(core);

    // Sticker với glow
    final stickerScale = Vector3(1.02, 1.02, 0.05);
    if (x == 1) _addSticker(cubie, Vector3(0.52, 0, 0), stickerScale, cRed);
    if (x == -1) _addSticker(cubie, Vector3(-0.52, 0, 0), stickerScale, cOrange);
    if (y == 1) _addSticker(cubie, Vector3(0, 0.52, 0), stickerScale, cWhite);
    if (y == -1) _addSticker(cubie, Vector3(0, -0.52, 0), stickerScale, cYellow);
    if (z == 1) _addSticker(cubie, Vector3(0, 0, 0.52), stickerScale, cGreen);
    if (z == -1) _addSticker(cubie, Vector3(0, 0, -0.52), stickerScale, cBlue);

    return cubie;
  }

  void _addSticker(Object parent, Vector3 pos, Vector3 scale, Color color) {
    final sticker = Object(position: pos, scale: scale);
    final colorVec = Vector3(color.red / 255, color.green / 255, color.blue / 255);
    sticker.mesh.material.diffuse = colorVec;
    sticker.mesh.material.ambient = colorVec * 1.2; // Glow
    parent.add(sticker);
  }

  void _rotateLayer(String axis, int layer, double angleDegrees) async {
    if (_isRotating) return;
    _isRotating = true;

    final targets = _cubies.where((c) {
      double pos = 0;
      if (axis == 'x') pos = c.position.x;
      if (axis == 'y') pos = c.position.y;
      if (axis == 'z') pos = c.position.z;
      return (pos - (layer * 1.05).toDouble()).abs() < 0.1;
    }).toList();

    final tween = Tween<double>(begin: 0, end: 1);
    final animation = tween.animate(_rotateController);

    animation.addListener(() {
      final t = animation.value;
      final angle = angleDegrees * (pi / 180.0) * t;

      for (var c in targets) {
        final origin = Vector3.copy(c.position);
        double x = origin.x;
        double y = origin.y;
        double z = origin.z;
        double newX = x, newY = y, newZ = z;

        final cosA = cos(angle);
        final sinA = sin(angle);

        if (axis == 'x') {
          newY = y * cosA - z * sinA;
          newZ = y * sinA + z * cosA;
          c.rotation.x = angle;
        } else if (axis == 'y') {
          newX = x * cosA + z * sinA;
          newZ = -x * sinA + z * cosA;
          c.rotation.y = angle;
        } else if (axis == 'z') {
          newX = x * cosA - y * sinA;
          newY = x * sinA + y * cosA;
          c.rotation.z = angle;
        }

        c.position.setValues(newX.toDouble(), newY.toDouble(), newZ.toDouble());
        c.scale.setValues(1.0, 1.0, 1.0);
        c.updateTransform();
      }
      _scene.update();
    });

    await _rotateController.forward();
    _rotateController.reset();

    // Snap vị trí và góc
    for (var c in targets) {
      c.position.x = ((c.position.x / 1.05).round() * 1.05).toDouble();
      c.position.y = ((c.position.y / 1.05).round() * 1.05).toDouble();
      c.position.z = ((c.position.z / 1.05).round() * 1.05).toDouble();

      c.rotation.x = ((c.rotation.x * 180 / pi).round() * pi / 180).toDouble();
      c.rotation.y = ((c.rotation.y * 180 / pi).round() * pi / 180).toDouble();
      c.rotation.z = ((c.rotation.z * 180 / pi).round() * pi / 180).toDouble();

      c.scale.setValues(1.0, 1.0, 1.0);
      c.updateTransform();
    }

    _playSound('rotate.mp3');
    _isRotating = false;
  }

  void _scramble() async {
    if (_isRotating) return;
    final rng = Random();
    final axes = ['x', 'y', 'z'];
    for (int i = 0; i < 20; i++) {
      final axis = axes[rng.nextInt(3)];
      final layer = rng.nextInt(3) - 1;
      final angle = rng.nextBool() ? 90.0 : -90.0;
      _rotateLayer(axis, layer, angle);
      await Future.delayed(const Duration(milliseconds: 450));
    }
  }

  void _playSound(String file) async {
    await _audioPlayer.play(AssetSource('sounds/$file'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text("Rubik 3D Pro"),
        actions: [
          IconButton(icon: const Icon(Icons.shuffle), onPressed: _scramble),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _generateRubik),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Cube(
              onSceneCreated: _onSceneCreated,
              interactive: true,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[850],
            child: Column(
              children: [
                const Text("Xoay layer", style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildLayerControl("X", 'x'),
                    _buildLayerControl("Y", 'y'),
                    _buildLayerControl("Z", 'z'),
                  ],
                ),
              ],
            ),
          ),
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
          ),
        ],
      ),
    );
  }

  Widget _buildLayerControl(String label, String axis) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white)),
        Row(
          children: [
            IconButton(icon: const Icon(Icons.arrow_left), onPressed: () => _rotateLayer(axis, -1, -90)),
            IconButton(icon: const Icon(Icons.arrow_right), onPressed: () => _rotateLayer(axis, 1, 90)),
          ],
        ),
      ],
    );
  }
}