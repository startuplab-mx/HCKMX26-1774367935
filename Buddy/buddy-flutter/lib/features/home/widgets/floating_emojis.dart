import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Spawns floating emojis (hearts, sparkles, Zs) over the pet.
/// Use [trigger] to add one at a position.
class FloatingEmojiLayer extends StatefulWidget {
  final FloatingEmojiController controller;
  const FloatingEmojiLayer({super.key, required this.controller});

  @override
  State<FloatingEmojiLayer> createState() => _FloatingEmojiLayerState();
}

class FloatingEmojiController extends ChangeNotifier {
  final List<_Emoji> _items = [];
  int _next = 0;
  void spawn(String char, Offset at, {double drift = 0}) {
    _items.add(_Emoji(_next++, char, at, drift));
    notifyListeners();
  }
  void burstHearts(Offset at) {
    for (var i = 0; i < 4; i++) {
      final dx = (i - 1.5) * 22 + (math.Random().nextDouble() - 0.5) * 12;
      _items.add(_Emoji(_next++, '❤', at, dx));
    }
    notifyListeners();
  }
  void _remove(int id) {
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
  }
}

class _Emoji {
  final int id;
  final String char;
  final Offset start;
  final double drift;
  _Emoji(this.id, this.char, this.start, this.drift);
}

class _FloatingEmojiLayerState extends State<FloatingEmojiLayer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onUpdate);
  }

  void _onUpdate() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_onUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: widget.controller._items
            .map((e) => _FloatingItem(
                  key: ValueKey(e.id),
                  data: e,
                  onDone: () => widget.controller._remove(e.id),
                ))
            .toList(),
      ),
    );
  }
}

class _FloatingItem extends StatefulWidget {
  final _Emoji data;
  final VoidCallback onDone;
  const _FloatingItem({super.key, required this.data, required this.onDone});

  @override
  State<_FloatingItem> createState() => _FloatingItemState();
}

class _FloatingItemState extends State<_FloatingItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        final dy = -t * 90;
        final dx = widget.data.drift * t;
        return Positioned(
          left: widget.data.start.dx + dx - 12,
          top: widget.data.start.dy + dy - 12,
          child: Opacity(
            opacity: 1 - t,
            child: Transform.scale(
              scale: 0.6 + t * 0.7,
              child: Text(
                widget.data.char,
                style: const TextStyle(
                  fontSize: 24,
                  color: Colors.redAccent,
                  shadows: [
                    Shadow(color: Colors.black54, offset: Offset(0, 2)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
