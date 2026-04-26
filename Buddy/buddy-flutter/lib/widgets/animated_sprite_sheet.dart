import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

// Las acciones siguen el orden de las filas del spritesheet 4xN.
// Pikachu/Mario/Kuromi tienen 4 filas (idle..sleep). Garfield tiene 8.
// Si un personaje recibe una acción que excede sus filas, el wrapper
// PetVisual hace fallback (ver pet_visual.dart).
enum SpriteAction { idle, walk, eat, sleep, bath, caress, play, happy }

/// Pinta un frame específico de un sprite sheet 4x[rows] con animación
/// cuadro a cuadro. Usa CustomPainter + drawImageRect para escalado
/// pixel-perfect (FilterQuality.none) y cachea la `ui.Image` decodificada
/// por path para no re-leer del bundle cada vez que el widget se reconstruye.
class AnimatedSpriteSheet extends StatefulWidget {
  final String asset;
  final SpriteAction action;
  final double size;
  final int columns;
  final int rows;
  final int framesPerRow;
  final Duration period;
  final bool playing;

  const AnimatedSpriteSheet({
    super.key,
    required this.asset,
    required this.size,
    this.action = SpriteAction.idle,
    this.columns = 4,
    // Default 8 porque el sheet más grande hoy es Garfield. Para personajes
    // de 4 filas, el caller debe pasar `rows: 4` explícito.
    this.rows = 8,
    this.framesPerRow = 4,
    this.period = const Duration(milliseconds: 600),
    this.playing = true,
  });

  @override
  State<AnimatedSpriteSheet> createState() => _AnimatedSpriteSheetState();
}

class _AnimatedSpriteSheetState extends State<AnimatedSpriteSheet>
    with SingleTickerProviderStateMixin {
  // Cache estático compartido entre todas las instancias. Decodificar un PNG
  // 1024x2048 es caro y los mismos sheets se usan en muchos lugares (carrusel,
  // home, learning view).
  static final Map<String, Future<ui.Image>> _cache = {};
  ui.Image? _image;
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period)
      ..repeat();
    _load();
  }

  @override
  void didUpdateWidget(covariant AnimatedSpriteSheet old) {
    super.didUpdateWidget(old);
    // Solo recarga la imagen si cambió el asset (cambio de personaje).
    // Cambiar `action` solo afecta qué fila se pinta, no la decodificación.
    if (old.asset != widget.asset) _load();
    if (old.period != widget.period) {
      _controller.duration = widget.period;
      if (widget.playing) _controller.repeat();
    }
    if (old.playing != widget.playing) {
      widget.playing ? _controller.repeat() : _controller.stop();
    }
  }

  Future<void> _load() async {
    // putIfAbsent evita carreras: si dos widgets piden el mismo sheet en el
    // mismo frame, ambos esperan el mismo Future en lugar de decodificar dos
    // veces.
    final future = _cache.putIfAbsent(widget.asset, () async {
      final data = await rootBundle.load(widget.asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    });
    final img = await future;
    if (mounted) setState(() => _image = img);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null) {
      return SizedBox(width: widget.size, height: widget.size);
    }
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          // controller.value va 0..1 en `period`. Lo escalamos a [0, framesPerRow)
          // y truncamos al entero para tener cambio de cuadro discreto.
          final frame = (_controller.value * widget.framesPerRow).floor() %
              widget.framesPerRow;
          return CustomPaint(
            painter: _SheetPainter(
              image: _image!,
              row: widget.action.index,
              col: frame,
              columns: widget.columns,
              rows: widget.rows,
            ),
          );
        },
      ),
    );
  }
}

class _SheetPainter extends CustomPainter {
  final ui.Image image;
  final int row;
  final int col;
  final int columns;
  final int rows;

  _SheetPainter({
    required this.image,
    required this.row,
    required this.col,
    required this.columns,
    required this.rows,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // El sheet se asume rejilla regular. Si la imagen no es múltiplo exacto,
    // el .toDouble queda con fracción y Skia interpola — para pixel art con
    // FilterQuality.none, los pixeles por borde se ven duros pero limpios.
    final cellW = image.width / columns;
    final cellH = image.height / rows;
    final src = Rect.fromLTWH(col * cellW, row * cellH, cellW, cellH);
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(covariant _SheetPainter old) =>
      old.image != image || old.row != row || old.col != col;
}
