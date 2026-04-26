import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/services/sound_service.dart';
import '../../design/theme.dart';
import '../../models/pet.dart';
import '../../models/pet_action.dart';

class RhythmTapGame extends StatefulWidget {
  final Pet pet;
  final ValueChanged<int> onClose;

  const RhythmTapGame({super.key, required this.pet, required this.onClose});

  @override
  State<RhythmTapGame> createState() => _RhythmTapGameState();
}

class _RhythmTapGameState extends State<RhythmTapGame>
    with SingleTickerProviderStateMixin {
  static const int _totalRounds = 25;

  DateTime _beatTime = DateTime.now();
  double _nextBeatIn = 0.6;
  double _bpm = 100;
  int _score = 0;
  int _combo = 0;
  int _maxCombo = 0;
  int _perfects = 0;
  int _goods = 0;
  int _misses = 0;
  int _rounds = 0;
  bool _gameOver = false;
  String _lastFeedback = '';
  Color _lastColor = Colors.white;
  Timer? _missTimer;
  Timer? _feedbackTimer;
  late final Ticker _ticker;
  Duration _now = Duration.zero;
  final Stopwatch _watch = Stopwatch();

  int get _accuracy {
    final total = _perfects + _goods + _misses;
    if (total == 0) return 0;
    return (_perfects * 100 + _goods * 50) ~/ total;
  }

  int get _reward => _score + _maxCombo * 2 + (_accuracy >= 80 ? 30 : 0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) {
      setState(() => _now = d);
    });
    _watch.start();
    _ticker.start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startRound());
  }

  @override
  void dispose() {
    _missTimer?.cancel();
    _feedbackTimer?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  void _startRound() {
    if (_rounds >= _totalRounds) {
      _endGame();
      return;
    }
    _beatTime = DateTime.now();
    _bpm = 100 + _rounds * 3;
    _nextBeatIn = 60.0 / _bpm;
    _missTimer?.cancel();
    _missTimer = Timer(
        Duration(milliseconds: (_nextBeatIn * 1500).round()), () {
      if (!mounted || _gameOver) return;
      if (_rounds < _totalRounds) {
        setState(() {
          _combo = 0;
          _misses++;
          _rounds++;
        });
        _showFeedback('MISS', Colors.red);
        _startRound();
      }
    });
  }

  void _tap() {
    if (_gameOver) return;
    final elapsed =
        DateTime.now().difference(_beatTime).inMilliseconds / 1000.0;
    final diff = (elapsed - _nextBeatIn).abs();
    if (diff < 0.1) {
      setState(() {
        _score += 5;
        _combo++;
        _perfects++;
      });
      _showFeedback('⭐ PERFECT', Colors.amber);
      HapticFeedback.heavyImpact();
    } else if (diff < 0.25) {
      setState(() {
        _score += 3;
        _combo++;
        _goods++;
      });
      _showFeedback('👍 GOOD', Colors.blue);
      HapticFeedback.mediumImpact();
    } else {
      setState(() {
        _combo = 0;
        _misses++;
      });
      _showFeedback('OFF', Colors.grey);
    }
    _maxCombo = max(_maxCombo, _combo);
    SoundService.instance.play(_combo > 0 ? PetAction.play : PetAction.idle);
    setState(() => _rounds++);
    _missTimer?.cancel();
    if (_rounds < _totalRounds) {
      _startRound();
    } else {
      _endGame();
    }
  }

  void _showFeedback(String text, Color color) {
    _feedbackTimer?.cancel();
    setState(() {
      _lastFeedback = text;
      _lastColor = color;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted && _lastFeedback == text) {
        setState(() => _lastFeedback = '');
      }
    });
  }

  void _endGame() {
    _missTimer?.cancel();
    setState(() => _gameOver = true);
    SoundService.instance.playReward();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed =
        DateTime.now().difference(_beatTime).inMilliseconds / 1000.0;
    final progress = _gameOver ? 0.0 : (elapsed / _nextBeatIn).clamp(0.0, 1.0);
    final isPerfect = progress > 0.85 && progress < 1.0;
    final ringSize = 220 - progress * 120;
    final bob = sin(elapsed / _nextBeatIn * pi * 2) * 6;
    // Use _now to keep widget rebuilding via ticker
    _now;

    return Scaffold(
      backgroundColor: BuddyTheme.consoleBG,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: GestureDetector(
                onTap: _tap,
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: SizedBox(
                    width: 240,
                    height: 240,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: ringSize,
                          height: ringSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isPerfect
                                  ? Colors.amber
                                  : BuddyTheme.actionPink
                                      .withValues(alpha: 0.6),
                              width: isPerfect ? 6 : 4,
                            ),
                          ),
                        ),
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: BuddyTheme.lcdStroke, width: 3),
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(0, bob),
                          child: Transform.scale(
                            scale: _combo >= 10 ? 1.15 : 1.0,
                            child: Image.asset(
                              widget.pet.character.portraitAsset,
                              width: 80,
                              height: 80,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 30,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_lastFeedback.isNotEmpty)
                      Text(_lastFeedback,
                          style: BuddyTheme.pixel(
                              size: 18,
                              weight: FontWeight.bold,
                              color: _lastColor)),
                    if (_combo >= 3) ...[
                      const SizedBox(width: 16),
                      Text('🔥 $_combo',
                          style: BuddyTheme.pixel(
                              size: 16,
                              weight: FontWeight.bold,
                              color: Colors.orange)),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Accuracy',
                          style: BuddyTheme.pixel(
                              size: 11,
                              color: BuddyTheme.darkInk
                                  .withValues(alpha: 0.6))),
                      Text('$_accuracy%',
                          style: BuddyTheme.pixel(
                              size: 12,
                              weight: FontWeight.bold,
                              color: _accuracy >= 80
                                  ? Colors.green
                                  : (_accuracy >= 50
                                      ? Colors.orange
                                      : Colors.red))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Stack(
                      children: [
                        Container(
                            height: 6,
                            color:
                                BuddyTheme.darkInk.withValues(alpha: 0.1)),
                        FractionallySizedBox(
                          widthFactor: _accuracy / 100,
                          child: Container(
                            height: 6,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [
                                Colors.red,
                                Colors.orange,
                                Colors.green
                              ]),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('Tap al pet cuando el aro toque al pet',
                style: BuddyTheme.pixel(
                    size: 11,
                    color: BuddyTheme.darkInk.withValues(alpha: 0.6))),
            const SizedBox(height: 30),
            if (_gameOver) _gameOverView(),
            if (!_gameOver) const SizedBox(height: 24),
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
                Text('${widget.pet.name} baila',
                    style: BuddyTheme.pixel(size: 14, weight: FontWeight.bold)),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _stat('🎵', '$_score'),
                    const SizedBox(width: 12),
                    _stat('🥁', '${_bpm.toInt()} BPM'),
                    const SizedBox(width: 12),
                    _stat('⊞', '$_rounds/$_totalRounds'),
                  ],
                ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text('¡Final!',
                style: BuddyTheme.pixel(size: 22, weight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('⭐ $_perfects',
                    style: BuddyTheme.pixel(size: 12, color: Colors.amber)),
                const SizedBox(width: 12),
                Text('👍 $_goods',
                    style: BuddyTheme.pixel(size: 12, color: Colors.blue)),
                const SizedBox(width: 12),
                Text('✗ $_misses',
                    style: BuddyTheme.pixel(size: 12, color: Colors.red)),
              ],
            ),
            const SizedBox(height: 6),
            Text('Accuracy: $_accuracy%',
                style: BuddyTheme.pixel(size: 14, weight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('$_reward🪙',
                style: BuddyTheme.pixel(
                    size: 18,
                    weight: FontWeight.bold,
                    color: BuddyTheme.actionPink)),
            const SizedBox(height: 12),
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
