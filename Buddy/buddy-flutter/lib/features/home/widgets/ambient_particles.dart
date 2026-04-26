import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'room.dart';

class AmbientParticles extends StatefulWidget {
  final RoomKind room;
  const AmbientParticles({super.key, required this.room});

  @override
  State<AmbientParticles> createState() => _AmbientParticlesState();
}

class _AmbientParticlesState extends State<AmbientParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final _rng = math.Random();
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _particles = _build(widget.room);
  }

  @override
  void didUpdateWidget(covariant AmbientParticles old) {
    super.didUpdateWidget(old);
    if (old.room != widget.room) {
      _particles = _build(widget.room);
    }
  }

  List<_Particle> _build(RoomKind k) {
    final count = switch (k) {
      RoomKind.garden => 14,
      RoomKind.livingRoom => 8,
      RoomKind.kitchen => 6,
      RoomKind.bedroom => 5,
    };
    return List.generate(count, (_) {
      return _Particle(
        startX: _rng.nextDouble(),
        startY: _rng.nextDouble(),
        speedY: 0.05 + _rng.nextDouble() * 0.12,
        amp: 0.02 + _rng.nextDouble() * 0.08,
        size: 3 + _rng.nextDouble() * 5,
        phase: _rng.nextDouble() * math.pi * 2,
        opacity: 0.45 + _rng.nextDouble() * 0.45,
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          size: Size.infinite,
          painter: _ParticlesPainter(
            particles: _particles,
            t: _c.value,
            room: widget.room,
          ),
        ),
      ),
    );
  }
}

class _Particle {
  final double startX, startY, speedY, amp, size, phase, opacity;
  _Particle({
    required this.startX,
    required this.startY,
    required this.speedY,
    required this.amp,
    required this.size,
    required this.phase,
    required this.opacity,
  });
}

class _ParticlesPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  final RoomKind room;
  _ParticlesPainter({required this.particles, required this.t, required this.room});

  @override
  void paint(Canvas canvas, Size size) {
    final color = switch (room) {
      RoomKind.garden => const Color(0xFFFFE082),
      RoomKind.kitchen => const Color(0xFFFFCCBC),
      RoomKind.livingRoom => const Color(0xFFFFFFFF),
      RoomKind.bedroom => const Color(0xFFB3E5FC),
    };
    for (final p in particles) {
      final yProg = (p.startY - t * p.speedY) % 1.0;
      final yPos = (yProg < 0 ? yProg + 1.0 : yProg) * size.height;
      final xPos = (p.startX + math.sin(t * math.pi * 2 + p.phase) * p.amp) * size.width;
      canvas.drawCircle(
        Offset(xPos, yPos),
        p.size,
        Paint()..color = color.withValues(alpha: p.opacity * 0.65),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter old) => true;
}
