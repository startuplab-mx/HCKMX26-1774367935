import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/sound_service.dart';
import '../../design/theme.dart';
import '../../models/pet.dart';

enum _Difficulty {
  easy(8, 'Fácil (8 cartas)', 1),
  medium(12, 'Medio (12 cartas)', 2),
  hard(16, 'Difícil (16 cartas)', 3);

  final int cards;
  final String label;
  final int rewardMultiplier;
  const _Difficulty(this.cards, this.label, this.rewardMultiplier);

  int get pairs => cards ~/ 2;
}

class MemoryMatchGame extends StatefulWidget {
  final Pet pet;
  final ValueChanged<int> onClose;

  const MemoryMatchGame({super.key, required this.pet, required this.onClose});

  @override
  State<MemoryMatchGame> createState() => _MemoryMatchGameState();
}

class _MemoryMatchGameState extends State<MemoryMatchGame> {
  static const _emojis = [
    '🍖', '🦴', '🎾', '⭐', '💖', '🐾', '🎈', '🍪'
  ];

  _Difficulty? _difficulty;
  List<_Card> _cards = [];
  final List<int> _flipped = [];
  final Set<int> _matched = {};
  int _moves = 0;
  DateTime _startTime = DateTime.now();
  Duration _elapsed = Duration.zero;
  bool _won = false;
  Timer? _timer;
  Timer? _flipTimer;

  @override
  void dispose() {
    _timer?.cancel();
    _flipTimer?.cancel();
    super.dispose();
  }

  void _startGame(_Difficulty d) {
    final chosen = List<String>.from(_emojis)..shuffle();
    final picks = chosen.take(d.pairs).toList();
    final all = [...picks, ...picks]..shuffle(Random());
    setState(() {
      _difficulty = d;
      _cards = [for (final e in all) _Card(label: e)];
      _flipped.clear();
      _matched.clear();
      _moves = 0;
      _won = false;
      _startTime = DateTime.now();
      _elapsed = Duration.zero;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_won && mounted) {
        setState(() => _elapsed = DateTime.now().difference(_startTime));
      }
    });
  }

  void _tap(int i) {
    if (_flipped.contains(i) || _matched.contains(i)) return;
    if (_flipped.length >= 2) return;
    SoundService.instance.playClick();
    setState(() => _flipped.add(i));
    if (_flipped.length == 2) {
      _moves++;
      final a = _cards[_flipped[0]];
      final b = _cards[_flipped[1]];
      if (a.label == b.label) {
        HapticFeedback.mediumImpact();
        setState(() {
          _matched.add(_flipped[0]);
          _matched.add(_flipped[1]);
          _flipped.clear();
        });
        if (_matched.length == _cards.length) {
          setState(() => _won = true);
          _timer?.cancel();
          SoundService.instance.playReward();
        }
      } else {
        _flipTimer = Timer(const Duration(milliseconds: 700), () {
          if (mounted) setState(() => _flipped.clear());
        });
      }
    }
  }

  int get _reward {
    final base = max(10, 100 - _moves * 2 - _elapsed.inSeconds);
    return base * (_difficulty?.rewardMultiplier ?? 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BuddyTheme.consoleBG,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            if (_difficulty == null)
              Expanded(child: _difficultyPicker())
            else
              Expanded(child: _gameBody()),
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
                Text('Caras de ${widget.pet.name}',
                    style: BuddyTheme.pixel(size: 14, weight: FontWeight.bold)),
                if (_difficulty != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _stat('👆', '$_moves'),
                      const SizedBox(width: 16),
                      _stat('⏱', '${_elapsed.inSeconds}s'),
                      const SizedBox(width: 16),
                      _stat('✓',
                          '${_matched.length ~/ 2}/${_difficulty!.pairs}'),
                    ],
                  ),
                ],
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

  Widget _difficultyPicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Elige dificultad',
              style: BuddyTheme.pixel(size: 18, weight: FontWeight.bold)),
          const SizedBox(height: 24),
          for (final d in _Difficulty.values) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: BuddyTheme.actionPink,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => _startGame(d),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(d.label,
                        style: BuddyTheme.pixel(
                            size: 14,
                            weight: FontWeight.bold,
                            color: Colors.white)),
                    Text('×${d.rewardMultiplier} 🪙',
                        style: BuddyTheme.pixel(
                            size: 14,
                            weight: FontWeight.bold,
                            color: Colors.white)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _gameBody() {
    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _cards.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemBuilder: (_, i) => _cardView(i),
          ),
        ),
        if (_won) _winView(),
      ],
    );
  }

  Widget _cardView(int i) {
    final show = _flipped.contains(i) || _matched.contains(i);
    return GestureDetector(
      onTap: () => _tap(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: show ? BuddyTheme.lcdInner : BuddyTheme.actionPink,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: BuddyTheme.lcdStroke, width: 2),
        ),
        alignment: Alignment.center,
        child: Opacity(
          opacity: _matched.contains(i) ? 0.4 : 1.0,
          child: show
              ? Text(_cards[i].label, style: const TextStyle(fontSize: 32))
              : Text('?',
                  style: BuddyTheme.pixel(
                      size: 22,
                      weight: FontWeight.bold,
                      color: Colors.white)),
        ),
      ),
    );
  }

  Widget _winView() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('¡Perfecto!',
              style: BuddyTheme.pixel(size: 18, weight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('$_reward🪙',
              style: BuddyTheme.pixel(
                  size: 22,
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
                    size: 14, weight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _Card {
  final String label;
  _Card({required this.label});
}
