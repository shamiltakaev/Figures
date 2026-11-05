import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  bool _isGameRunning = false;
  final List<GameShape> _shapes = [];
  final List<Particle> _particles = [];
  final List<TrailParticle> _trailParticles = [];
  
  late AnimationController _gameLoopController;
  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _soundPlayer = AudioPlayer();
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    // Игровой цикл обновления кадров через AnimationController
    _gameLoopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_updateGame);
  }

  void _startGame() async {
    setState(() {
      _isGameRunning = true;
    });

    // Фоновая музыка и звуки лопания
    // Для работы звуков положите веселую детскую мелодию в assets/music.mp3
    // и звук щелчка в assets/pop.mp3, затем укажите их в pubspec.yaml
    try {
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(0.15);
      await _musicPlayer.play(AssetSource('music.mp3'));
    } catch (_) {}

    // Генерируем 15 начальных компактных фигур
    final Size size = MediaQuery.of(context).size;
    for (int i = 0; i < 15; i++) {
      _shapes.add(GameShape.random(size, _random));
    }

    _gameLoopController.repeat();
  }

  void _updateGame() {
    if (!_isGameRunning) return;
    final Size size = MediaQuery.of(context).size;

    setState(() {
      // 1. Обновление фигур и добавление круглого шлейфа
      for (var shape in _shapes) {
        shape.update(size, _random);
        if (_random.nextDouble() < 0.4) {
          _trailParticles.add(TrailParticle(
            x: shape.x + (_random.nextDouble() - 0.5) * 10,
            y: shape.y + (_random.nextDouble() - 0.5) * 10,
            color: shape.color,
          ));
        }
      }

      // 2. Обновление частиц шлейфа
      _trailParticles.removeWhere((p) {
        p.update();
        return p.alpha <= 0 || p.size <= 0;
      });

      // 3. Обновление частиц взрыва
      _particles.removeWhere((p) {
        p.update();
        return p.alpha <= 0;
      });
    });
  }

  void _handleTap(Offset localPosition) {
    if (!_isGameRunning) return;

    for (int i = _shapes.length - 1; i >= 0; i--) {
      final s = _shapes[i];
      final double dist = sqrt(pow(s.x - localPosition.dx, 2) + pow(s.y - localPosition.dy, 2));

      // Область клика увеличена для удобства (в 1.8 раза от радиуса фигуры)
      if (dist <= s.size * 1.8) {
        try {
          _soundPlayer.play(AssetSource('pop.mp3'));
        } catch (_) {}

        // Взрыв круглыми искорками (звёзды полностью убраны)
        for (int j = 0; j < 12; j++) {
          _particles.add(Particle(s.x, s.y, s.color, _random));
        }

        // Возрождаем фигуру в случайном месте
        _shapes[i] = GameShape.random(MediaQuery.of(context).size, _random);
        break; 
      }
    }
  }

  @override
  void dispose() {
    _gameLoopController.dispose();
    _musicPlayer.dispose();
    _soundPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Мягкий статичный пастельно-голубой фон
      backgroundColor: const Color(0xFFEEF7FF),
      body: Stack(
        children: [
          // Полноэкранный холст игры, обрабатывающий мультитач (несколько нажатий одновременно)
          Positioned.fill(
            child: Listener(
              onPointerDown: (event) => _handleTap(event.localPosition),
              child: CustomPaint(
                painter: GamePainter(
                  shapes: _shapes,
                  particles: _particles,
                  trailParticles: _trailParticles,
                ),
              ),
            ),
          ),
          // Кнопка Старта
          if (!_isGameRunning)
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4757),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  elevation: 10,
                ),
                onPressed: _startGame,
                child: const Text('Начать Игру 🎮'),
              ),
            ),
        ],
      ),
    );
  }
}

// Отрисовка элементов игры на Canvas
class GamePainter extends CustomPainter {
  final List<GameShape> shapes;
  final List<Particle> particles;
  final List<TrailParticle> trailParticles;

  GamePainter({
    required this.shapes,
    required this.particles,
    required this.trailParticles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // 1. Отрисовка круглого шлейфа
    for (var p in trailParticles) {
      paint.color = p.color.withOpacity(p.alpha);
      canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
    }

    // 2. Отрисовка фигур (круги и пятиугольники)
    for (var s in shapes) {
      paint.color = s.color;
      canvas.save();
      canvas.translate(s.x, s.y);
      canvas.rotate(s.angle);

      if (s.isCircle) {
        canvas.drawCircle(Offset.zero, s.size, paint);
      } else {
        final path = Path();
        for (int i = 0; i < 5; i++) {
          double a = (i * 2 * pi / 5) - pi / 2;
          Offset point = Offset(s.size * cos(a), s.size * sin(a));
          if (i == 0) path.moveTo(point.dx, point.dy); else path.lineTo(point.dx, point.dy);
        }
        path.close();
        canvas.drawPath(path, paint);
      }
      canvas.restore();
    }

    // 3. Отрисовка круглых взрывных искорок
    for (var p in particles) {
      paint.color = p.color.withOpacity(p.alpha);
      canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Модели объектов
class GameShape {
  double x, y, vx, vy, size, angle, rotationSpeed;
  Color color;
  bool isCircle;

  GameShape({
    required this.x, required this.y, required this.vx, required this.vy,
    required this.size, required this.color, required this.isCircle,
    required this.angle, required this.rotationSpeed,
  });

  factory GameShape.random(Size size, Random r) {
    final colors = [const Color(0xFFFF4757), const Color(0xFF2ED573), 
                    const Color(0xFF1E90FF), const Color(0xFFFFA502), 
                    const Color(0xFF9B59B6), const Color(0xFF00D2D3)];
    double shapeSize = r.nextDouble() * 10 + 25; // Компактный размер фигуры
    return GameShape(
      size: shapeSize,
      x: r.nextDouble() * (size.width - shapeSize * 2) + shapeSize,
      y: r.nextDouble() * (size.height - shapeSize * 2) + shapeSize,
      vx: (r.nextDouble() * 4 + 5) * (r.nextBool() ? 1 : -1),
      vy: (r.nextDouble() * 4 + 5) * (r.nextBool() ? 1 : -1),
      color: colors[r.nextInt(colors.length)],
      isCircle: r.nextBool(),
      angle: r.nextDouble() * pi * 2,
      rotationSpeed: (r.nextDouble() - 0.5) * 0.05,
    );
  }

  void update(Size size, Random r) {
    // Хаотичное виляние траектории
    vx += (r.nextDouble() - 0.5) * 0.8;
    vy += (r.nextDouble() - 0.5) * 0.8;

    double speed = sqrt(vx * vx + vy * vy);
    if (speed > 10) { vx = (vx / speed) * 10; vy = (vy / speed) * 10; }
    else if (speed < 4) { vx = (vx / speed) * 4; vy = (vy / speed) * 4; }

    x += vx; y += vy;
    angle += rotationSpeed;

    if (x - size < 0) { x = size; vx *= -1; }
    if (x + size > size.width) { x = size.width - size; vx *= -1; }
    if (y - size < 0) { y = size; vy *= -1; }
    if (y + size > size.height) { y = size.height - size; vy *= -1; }
  }
}

class TrailParticle {
  double x, y, size, alpha, fadeSpeed;
  Color color;
  TrailParticle({required this.x, required this.y, required this.color})
      : size = Random().nextDouble() * 2 + 3,
        alpha = 0.8,
        fadeSpeed = Random().nextDouble() * 0.02 + 0.02;

  void update() { alpha -= fadeSpeed; size -= 0.1; }
}

class Particle {
  double x, y, vx, vy, size, alpha;
  Color color;
  Particle(this.x, this.y, this.color, Random r)
      : alpha = 1.0, size = r.nextDouble() * 3 + 4 {
    double a = r.nextDouble() * 2 * pi;
    double s = r.nextDouble() * 5 + 3;
    vx = cos(a) * s; vy = sin(a) * s;
  }

  void update() { x += vx; y += vy; alpha -= 0.05; }
}
