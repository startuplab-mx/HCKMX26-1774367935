import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/sound_service.dart';
import '../../design/theme.dart';
import '../../models/pet.dart';
import '../../models/pet_action.dart';

class TapReactionGame extends StatefulWidget {
  final Pet pet;
  final ValueChanged<int> onClose;

  const TapReactionGame({super.key, required this.pet, required this.onClose});

  @override
  State<TapReactionGame> createState() => _TapReactionGameState();
}

class _TapReactionGameState extends State<TapReactionGame> {
  final _rand = Random();
  _Target? _target;
  int _score = 0;
  int _combo = 0;
  int _maxCombo = 0;
  int _timeLeft = 30;
  bool _gameOver = false;
  bool _bossMode = false;
  String _feedback = '';
  Timer? _spawnTimer;
  Timer? _countdownTimer;
  Timer? _feedbackTimer;

  int get _multiplier {
    if (_combo < 3) return 1;
    if (_combo < 6) return 2;
    if (_combo < 10) return 3;
    return 5;
  }

  double get _spawnInterval {
    final base = _bossMode ? 0.4 : 1.5;
    return max(0.3, base - _combo * 0.05);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _spawnTimer?.cancel();
    _countdownTimer?.cancel();
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _start() {
    _spawn();
    _scheduleSpawn();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _timeLeft--;
        if (_timeLeft == 5 && !_bossMode) {
          _bossMode = true;
          _showFeedback('⚡ BOSS!');
          _scheduleSpawn();
          HapticFeedback.heavyImpact();
        }
        if (_timeLeft <= 0) _endGame();
      });
    });
  }

  void _scheduleSpawn() {
    _spawnTimer?.cancel();
    _spawnTimer = Timer.periodic(
        Duration(milliseconds: (_spawnInterval * 1000).round()), (_) {
      if (_target != null) _combo = 0;
      _spawn();
    });
  }

  void _spawn() {
    if (_gameOver) return;
    setState(() {
      _target = _Target(
        x: 0.15 + _rand.nextDouble() * 0.7,
        y: 0.2 + _rand.nextDouble() * 0.6,
        scale: _bossMode ? 0.7 : 0.85 + _rand.nextDouble() * 0.35,
      );
    });
  }

  void _hit() {
    final points = 1 * _multiplier;
    setState(() {
      _score += points;
      _combo++;
      _maxCombo = max(_maxCombo, _combo);
    });
    HapticFeedback.mediumImpact();
    SoundService.instance.play(PetAction.play);
    if (_combo % 5 == 0 && _combo > 0) {
      _showFeedback('🔥 $_combo COMBO!');
      _scheduleSpawn();
    } else if (_multiplier > 1) {
      _showFeedback('+$points');
    }
    _spawn();
  }

  void _showFeedback(String text) {
    _feedbackTimer?.cancel();
    setState(() => _feedback = text);
    _feedbackTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted && _feedback == text) setState(() => _feedback = '');
    });
  }

  void _endGame() {
    _spawnTimer?.cancel();
    _countdownTimer?.cancel();
    setState(() => _gameOver = true);
    SoundService.instance.playReward();
  }

  int get _reward => _score + _maxCombo * 5;

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
                builder: (_, c) {
                  return Stack(
                    children: [
                      Container(
                          color: _bossMode
                              ? const Color(0xFFFFD9D9)
                              : BuddyTheme.lcdInner),
                      if (_target != null && !_gameOver)
                        Positioned(
                          left: _target!.x * c.maxWidth - 32,
                          top: _target!.y * c.maxHeight - 32,
                          child: GestureDetector(
                            onTap: _hit,
                            child: Transform.scale(
                              scale: _target!.scale,
                              child: Container(
                                decoration: _combo >= 6
                                    ? const BoxDecoration(
                                        boxShadow: [
                                          BoxShadow(
                                              color: Colors.orange,
                                              blurRadius: 12,
                                              spreadRadius: 4)
                                        ],
                                        shape: BoxShape.circle,
                                      )
                                    : null,
                                child: Image.asset(
                                  widget.pet.character.portraitAsset,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_feedback.isNotEmpty)
                        Positioned(
                          top: 60,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Text(_feedback,
                                style: BuddyTheme.pixel(
                                    size: 32,
                                    weight: FontWeight.bold,
                                    color: BuddyTheme.actionPink)),
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
      child: Row(
        children: [
          _closeButton(),
          Expanded(
            child: Column(
              children: [
                Text(_bossMode ? '⚡ BOSS MODE' : 'Atrapa a ${widget.pet.name}',
                    style: BuddyTheme.pixel(
                        size: 14,
                        weight: FontWeight.bold,
                        color: _bossMode ? Colors.red : BuddyTheme.darkInk)),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _stat('🎯', '$_score'),
                    if (_multiplier > 1) ...[
                      const SizedBox(width: 12),
                      Text('x$_multiplier',
                          style: BuddyTheme.pixel(
                              size: 12,
                              weight: FontWeight.bold,
                              color: Colors.orange)),
                    ],
                    const SizedBox(width: 12),
                    _stat('⏱', '${_timeLeft}s'),
                  ],
                ),
                if (_combo >= 3)
                  Text('🔥 $_combo combo',
                      style: BuddyTheme.pixel(
                          size: 11,
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

  Widget _stat(String icon, String value) => Text('$icon $value',
      style: BuddyTheme.pixel(
          size: 11, color: BuddyTheme.darkInk.withValues(alpha: 0.7)));

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
            Text('¡Tiempo!',
                style: BuddyTheme.pixel(size: 22, weight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('$_score puntos · combo máx $_maxCombo',
                style: BuddyTheme.pixel(
                    size: 12,
                    color: BuddyTheme.darkInk.withValues(alpha: 0.7))),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
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

class _Target {
  final double x;
  final double y;
  final double scale;
  _Target({required this.x, required this.y, required this.scale});
}
