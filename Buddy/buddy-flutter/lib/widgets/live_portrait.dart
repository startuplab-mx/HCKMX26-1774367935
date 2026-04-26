import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Le da "vida" a un retrato estático cuando no hay sheet animado disponible.
/// Aplica una respiración (squash & stretch lento) y un parpadeo ocasional
/// procedural sobre la imagen, simulando un sprite con micro-animación.
///
/// Lo usamos para dos casos: (1) personajes con solo retrato (no sheet),
/// y (2) emociones puntuales como `garfield_sad.png` en el flujo de TikTok,
/// donde no queremos la pose neutra del sheet.
///
/// `seed` se usa para que distintos personajes en pantalla no respiren ni
/// parpadeen sincronizados (carrusel de selector).
class LivePortrait extends StatefulWidget {
  final String asset;
  final double size;
  final bool playing;
  final int seed;

  const LivePortrait({
    super.key,
    required this.asset,
    required this.size,
    this.playing = true,
    this.seed = 0,
  });

  @override
  State<LivePortrait> createState() => _LivePortraitState();
}

class _LivePortraitState extends State<LivePortrait>
    with TickerProviderStateMixin {
  late final AnimationController _breath;
  late final AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1400 + (widget.seed * 53) % 400),
    );
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    if (widget.playing) {
      _breath.repeat(reverse: true);
      _scheduleBlink();
    }
  }

  void _scheduleBlink() async {
    // Loop "vivo": espera entre 1.8 y 4 segundos antes del próximo parpadeo.
    // Usamos Random sembrado por widget para que retratos distintos no
    // parpadeen al unísono.
    while (mounted && widget.playing) {
      await Future.delayed(Duration(
          milliseconds: 1800 + math.Random(widget.seed).nextInt(2200)));
      if (!mounted) return;
      await _blink.forward(from: 0);
      if (!mounted) return;
      await _blink.reverse();
    }
  }

  @override
  void didUpdateWidget(covariant LivePortrait old) {
    super.didUpdateWidget(old);
    if (old.playing != widget.playing) {
      if (widget.playing) {
        _breath.repeat(reverse: true);
        _scheduleBlink();
      } else {
        _breath.stop();
        _blink.stop();
      }
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_breath, _blink]),
        builder: (_, __) {
          final t = _breath.value;
          // Squash & stretch leve: estira vertical mientras se contrae lateral.
          // Los valores son intencionalmente pequeños — más que esto se vuelve
          // caricaturesco y choca con el estilo pixel art.
          final scaleY = 1.0 + (t * 0.06);
          final scaleX = 1.0 - (t * 0.03);
          final dy = -t * 4;                              // flota un poquito al respirar
          final tilt = math.sin(t * math.pi) * 0.02;      // ladea la cabeza
          final blinkY = (1 - _blink.value * 0.85);       // 0 = ojos abiertos, 0.85 = casi cerrados

          return Transform.translate(
            offset: Offset(0, dy),
            child: Transform.rotate(
              angle: tilt,
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.identity()
                  ..scale(scaleX, scaleY * blinkY, 1.0),
                child: Image.asset(
                  widget.asset,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
