import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/sound_service.dart';
import '../../design/theme.dart';
import '../../models/pet.dart';
import '../../models/pet_action.dart';

class CatchFoodGame extends StatefulWidget {
  final Pet pet;
  final ValueChanged<int> onClose;

  const CatchFoodGame({super.key, required this.pet, required this.onClose});

  @override
  State<CatchFoodGame> createState() => _CatchFoodGameState();
}

class _CatchFoodGameState extends State<CatchFoodGame> {
  static const _foodEmojis = ['🍖', '🍗', '🍪', '🥩', '🐟', '🥛', '🥕', '🍣'];
  static const _trapEmojis = ['💣', '☠️', '🌶️'];
  static const double _petWidth = 0.18;

  final _rand = Random();
  final List<_FallingItem> _items = [];
  double _petX = 0.5;
  int _score = 0;
  int _combo = 0;
  int _maxCombo = 0;
  int _timeLeft = 30;
  int _difficulty = 1;
  bool _gameOver = false;
  String _feedback = '';
  Timer? _spawnTimer;
  Timer? _countdownTimer;
  Timer? _animTimer;
  Timer? _feedbackTimer;
  Size? _size;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _spawnTimer?.cancel();
    _countdownTimer?.cancel();
    _animTimer?.cancel();
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _start() {
    _scheduleSpawn();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _timeLeft--;
        if (_timeLeft == 20 || _timeLeft == 10) {
          _difficulty++;
          _scheduleSpawn();
          _showFeedback('¡Nivel $_difficulty!');
        }
        if (_timeLeft <= 0) _endGame();
      });
    });
    _animTimer = Timer.periodic(
        const Duration(milliseconds: 33), (_) => _tick());
  }

  void _scheduleSpawn() {
    _spawnTimer?.cancel();
    final interval = max(0.25, 0.7 - _difficulty * 0.15);
    _spawnTimer = Timer.periodic(
        Duration(milliseconds: (interval * 1000).round()), (_) => _spawn());
  }

  void _spawn() {
    if (_gameOver) return;
    final isTrap = _rand.nextInt(10) < (1 + _difficulty ~/ 2);
    final isGolden = !isTrap && _rand.nextInt(20) == 0;
    final pool = isTrap ? _trapEmojis : _foodEmojis;
    setState(() {
      _items.add(_FallingItem(
        emoji: isGolden ? '⭐' : pool[_rand.nextInt(pool.length)],
        x: 0.1 + _rand.nextDouble() * 0.8,
        y: -0.05,
        isTrap: isTrap,
        golden: isGolden,
      ));
    });
  }

  void _tick() {
    if (_gameOver || _size == null) return;
    final speed = 0.012 + _difficulty * 0.003;
    final petY = (_size!.height - 60) / _size!.height;
    final caught = <_FallingItem>[];
    final landed = <_FallingItem>[];
    for (final it in _items) {
      it.y += speed;
      if (it.y >= petY - 0.05 &&
          it.y < petY + 0.05 &&
          (it.x - _petX).abs() < _petWidth) {
        caught.add(it);
        if (it.isTrap) {
          _score = max(0, _score - 2);
          _combo = 0;
          _showFeedback('💥 -2');
          HapticFeedback.heavyImpact();
        } else if (it.golden) {
          _score += 10;
          _combo++;
          _maxCombo = max(_maxCombo, _combo);
          _showFeedback('⭐ +10!');
          SoundService.instance.playReward();
          HapticFeedback.mediumImpact();
        } else {
          final bonus = max(1, _combo ~/ 3);
          _score += 1 + bonus;
          _combo++;
          _maxCombo = max(_maxCombo, _combo);
          if (_combo >= 5) _showFeedback('¡$_combo combo!');
          SoundService.instance.play(PetAction.eat);
          HapticFeedback.lightImpact();
        }
      } else if (it.y > 1.05) {
        landed.add(it);
        if (!it.isTrap) _combo = 0;
      }
    }
    if (caught.isNotEmpty || landed.isNotEmpty) {
      setState(() {
        _items.removeWhere((e) => caught.contains(e) || landed.contains(e));
      });
    } else {
      setState(() {});
    }
  }

  void _showFeedback(String text) {
    _feedbackTimer?.cancel();
    setState(() => _feedback = text);
    _feedbackTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted && _feedback == text) setState(() => _feedback = '');
    });
  }

  void _endGame() {
    _spawnTimer?.cancel();
    _countdownTimer?.cancel();
    _animTimer?.cancel();
    setState(() => _gameOver = true);
    SoundService.instance.playReward();
  }

  int get _reward => _score * 2 + _maxCombo * 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BuddyTheme.consoleBG,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _size = constraints.biggest;
                  return Stack(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFFFFF2D9),
                              Color(0xFFFFE0BC),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: 60,
                          color: const Color(0xFFBA8B5E),
                        ),
                      ),
                      ..._items.map((it) => Positioned(
                            left: it.x * constraints.maxWidth - 18,
                            top: it.y * constraints.maxHeight - 18,
                            child: Text(
                              it.emoji,
                              style: TextStyle(
                                  fontSize: it.golden ? 48 : 36,
                                  shadows: it.golden
                                      ? const [
                                          Shadow(
                                              color: Colors.yellow,
                                              blurRadius: 8)
                                        ]
                                      : null),
                            ),
                          )),
                      Positioned(
                        left: _petX * constraints.maxWidth - 32,
                        top: constraints.maxHeight - 60 - 32,
                        child: AnimatedScale(
                          scale: _combo >= 5 ? 1.15 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Image.asset(
                            widget.pet.character.portraitAsset,
                            width: 64,
                            height: 64,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onPanUpdate: (d) {
                            final newX =
                                d.localPosition.dx / constraints.maxWidth;
                            setState(() => _petX = newX.clamp(0.05, 0.95));
                          },
                        ),
                      ),
                      if (_feedback.isNotEmpty)
                        Positioned(
                          top: constraints.maxHeight * 0.4,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Text(
                              _feedback,
                              style: BuddyTheme.pixel(
                                size: 28,
                                weight: FontWeight.bold,
                                color: _combo > 0
                                    ? BuddyTheme.actionPink
                                    : Colors.red,
                              ),
                            ),
                          ),
                        ),
                      if (_gameOver) _gameOverView(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: BuddyTheme.consoleBG,
      child: Row(
        children: [
          _closeButton(),
          Expanded(
            child: Column(
              children: [
                Text('${widget.pet.name} tiene hambre',
                    style:
                        BuddyTheme.pixel(size: 13, weight: FontWeight.bold)),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _stat('🍴', '$_score'),
                    const SizedBox(width: 12),
                    _stat('⚡', 'Lv$_difficulty'),
                    const SizedBox(width: 12),
                    _stat('⏱', '${_timeLeft}s'),
                  ],
                ),
                if (_combo >= 3)
                  Text('🔥 COMBO x$_combo',
                      style: BuddyTheme.pixel(
                          size: 12,
                          weight: FontWeight.bold,
                          color: Colors.orange)),
              ],
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _stat(String icon, String value) {
    return Text('$icon $value',
        style: BuddyTheme.pixel(
            size: 11, color: BuddyTheme.darkInk.withValues(alpha: 0.7)));
  }

  Widget _closeButton() {
    return GestureDetector(
      onTap: () => widget.onClose(0),
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: BuddyTheme.buttonBG,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.close, size: 18, color: BuddyTheme.darkInk),
      ),
    );
  }

  Widget _gameOverView() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 20)
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('¡Terminó!',
                style: BuddyTheme.pixel(size: 22, weight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('$_score puntos',
                style: BuddyTheme.pixel(
                    size: 16,
                    color: BuddyTheme.darkInk.withValues(alpha: 0.7))),
            const SizedBox(height: 4),
            Text('Combo máx: $_maxCombo',
                style: BuddyTheme.pixel(size: 12, color: Colors.orange)),
            const SizedBox(height: 12),
            Text('→ $_reward🪙',
                style: BuddyTheme.pixel(
                    size: 18,
                    weight: FontWeight.bold,
                    color: BuddyTheme.actionPink)),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: BuddyTheme.actionPink,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 12),
              ),
              onPressed: () => widget.onClose(_reward),
              child: Text('Cobrar',
                  style: BuddyTheme.pixel(
                      size: 14,
                      weight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FallingItem {
  final String emoji;
  double x;
  double y;
  final bool isTrap;
  final bool golden;
  _FallingItem({
    required this.emoji,
    required this.x,
    required this.y,
    required this.isTrap,
    required this.golden,
  });
}
