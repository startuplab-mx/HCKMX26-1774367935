import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:overlay_pop_up/overlay_pop_up.dart';

class BuddyOverlayApp extends StatelessWidget {
  const BuddyOverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: BuddyOverlayWidget(),
      ),
    );
  }
}

class BuddyOverlayWidget extends StatefulWidget {
  const BuddyOverlayWidget({super.key});

  @override
  State<BuddyOverlayWidget> createState() => _BuddyOverlayWidgetState();
}

class _BuddyOverlayWidgetState extends State<BuddyOverlayWidget>
    with TickerProviderStateMixin {
  // Sprite y área (todas en dp lógicos).
  static const double _spriteSize = 30;
  static const double _spriteHalf = _spriteSize / 2;
  // El paseo está limitado a los primeros 50 dp (status bar). El overlay
  // total puede ser más alto para dar espacio a los globos.
  static const double _walkAreaHeight = 50;
  // Centro vertical del notch dentro del status bar.
  static const double _notchY = 25;
  // Radio que la mascota mantiene fuera del punch-hole.
  static const double _notchAvoidanceRadius = 22;
  // Velocidad nominal (dp/s); cada target tiene una velocidad aleatoria
  // alrededor de este valor.
  static const double _baseSpeed = 30;

  // Fallback usado mientras se carga `assets/phrases.json` (generado con
  // tools/generate_phrases.py vía Gemini).
  static const List<String> _fallbackPhrases = [
    '¡Hola!',
    'Tengo hambre 🍖',
    'Juguemos!',
    '¿Me acaricias?',
    'Sed 💧',
    '*bosteza*',
    'Te extrañé',
    '¡Mira!',
  ];
  List<String> _phrases = _fallbackPhrases;

  // Spritesheet
  static const String _spriteAsset = 'assets/sprites/pet_sheet_pikachu.png';
  static const int _columns = 4;
  // Detectado por aspect ratio al cargar (4 para sheets cuadrados,
  // 8 para Garfield extendido 1024×2048).
  int _rows = 4;
  static const int _walkFrames = 4;
  static const int _walkRow = 1;

  // Estado del paseo
  double _x = 60;
  double _y = _notchY;
  double _facingSign = 1;
  Offset _target = const Offset(60, _notchY);
  double _currentSpeed = _baseSpeed;
  double _wobblePhase = 0;
  bool _initialized = false;
  Duration _lastTick = Duration.zero;

  // Tamaño real del overlay (lo conocemos en el primer build).
  double _areaWidth = 411;
  double _areaHeight = 50;

  Timer? _targetTimer;
  Timer? _bubbleTimer;
  final _rng = math.Random();

  // Estado del globo de texto.
  String? _bubbleText;
  bool _bubbleOnRight = true;

  ui.Image? _sheet;
  String? _spriteOverride;
  late final AnimationController _walkCtrl;
  late final AnimationController _bounceCtrl;
  late final AnimationController _bubbleCtrl;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    OverlayPopUp.initializeOverlayHandler();
    _walkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _bubbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _ticker = createTicker(_onTick)..start();
    _loadSheet();
    _loadPhrases();
    _listenForUpdates();
    // Saludo inmediato al desplegarse el overlay, después de un pequeño
    // delay para que el sprite y las frases ya estén cargados.
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _showWelcomeBubble();
    });
    _scheduleNextBubble();
  }

  Future<void> _showWelcomeBubble() async {
    const greetings = ['¡Hola!', '¡Holiii!', 'Hey, ¿qué tal?', '¡Hola hola!'];
    if (!mounted) return;
    setState(() {
      _bubbleText = greetings[_rng.nextInt(greetings.length)];
      _bubbleOnRight = _x < _areaWidth / 2;
    });
    await _bubbleCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    await _bubbleCtrl.reverse();
    if (!mounted) return;
    setState(() => _bubbleText = null);
  }

  Future<void> _loadPhrases() async {
    try {
      final raw = await rootBundle.loadString('assets/phrases.json');
      final list = (jsonDecode(raw) as List).cast<String>();
      if (list.isNotEmpty && mounted) {
        setState(() => _phrases = list);
      }
    } catch (_) {
      // Si falla, mantenemos el fallback.
    }
  }

  @override
  void dispose() {
    _targetTimer?.cancel();
    _bubbleTimer?.cancel();
    _ticker.dispose();
    _walkCtrl.dispose();
    _bounceCtrl.dispose();
    _bubbleCtrl.dispose();
    super.dispose();
  }

  void _scheduleNextBubble() {
    _bubbleTimer?.cancel();
    final delayMs = 5000 + _rng.nextInt(10000);
    _bubbleTimer = Timer(Duration(milliseconds: delayMs), () async {
      if (!mounted) return;
      await _showRandomBubble();
      _scheduleNextBubble();
    });
  }

  Future<void> _showRandomBubble() async {
    final phrase = _phrases[_rng.nextInt(_phrases.length)];
    if (!mounted) return;
    setState(() {
      _bubbleText = phrase;
      _bubbleOnRight = _x < _areaWidth / 2;
    });
    await _bubbleCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    await _bubbleCtrl.reverse();
    if (!mounted) return;
    setState(() => _bubbleText = null);
  }

  Future<void> _loadSheet({String? override}) async {
    final assetPath = override ?? _spriteAsset;
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    if (!mounted) return;
    final img = frame.image;
    // Sheets cuadrados (1024×1024) son 4×4. Sheets 1024×2048 son 4×8 (Garfield extendido).
    final detectedRows = (img.height / img.width).round() * _columns;
    setState(() {
      _sheet = img;
      _rows = detectedRows.clamp(4, 16);
    });
  }

  void _listenForUpdates() {
    OverlayPopUp.overlayDataListener?.listen((event) {
      if (event is Map && event['sprite'] is String) {
        final next = event['sprite'] as String;
        if (next != _spriteOverride) {
          _spriteOverride = next;
          _loadSheet(override: next);
        }
      }
    });
  }

  void _onTap() {
    _bounceCtrl.forward(from: 0).then((_) => _bounceCtrl.reverse());
    _showTapBubble();
  }

  Future<void> _showTapBubble() async {
    if (_phrases.isEmpty) return;
    final phrase = _phrases[_rng.nextInt(_phrases.length)];
    if (!mounted) return;
    // Si ya hay un bubble visible, lo reemplazamos en caliente sin animar
    // un cierre intermedio: cancelamos el timer automático y forzamos texto.
    _bubbleTimer?.cancel();
    setState(() {
      _bubbleText = phrase;
      _bubbleOnRight = _x < _areaWidth / 2;
    });
    if (_bubbleCtrl.value < 1.0) {
      await _bubbleCtrl.forward(from: _bubbleCtrl.value);
    }
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    // Si en medio el usuario tocó otra vez, _bubbleText fue reemplazado y
    // este delay viejo cierra prematuro: lo evitamos comparando.
    if (_bubbleText != phrase) return;
    await _bubbleCtrl.reverse();
    if (!mounted) return;
    setState(() => _bubbleText = null);
    _scheduleNextBubble();
  }

  void _scheduleNewTarget() {
    _targetTimer?.cancel();
    // Cuando llega cerca del target, decide siguiente paso muy rápido (200 ms);
    // si todavía está caminando, espera entre 1.2 y 4 s.
    final delayMs = 1200 + _rng.nextInt(2800);
    _targetTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      _target = _pickRandomTarget();
      _currentSpeed = _baseSpeed * (0.6 + _rng.nextDouble() * 0.9);
      _scheduleNewTarget();
    });
  }

  Offset _pickRandomTarget() {
    final cx = _areaWidth / 2;
    final minX = _spriteHalf + 4;
    final maxX = _areaWidth - _spriteHalf - 4;
    final minY = _spriteHalf + 2;
    // El paseo se confina al área del status bar (no al overlay completo,
    // que ahora tiene espacio extra para los globos).
    final maxY = _walkAreaHeight - _spriteHalf - 2;
    if (maxX <= minX || maxY <= minY) return Offset(_x, _y);
    for (int i = 0; i < 40; i++) {
      final x = minX + _rng.nextDouble() * (maxX - minX);
      final y = minY + _rng.nextDouble() * (maxY - minY);
      final dxN = x - cx;
      final dyN = y - _notchY;
      final dist = math.sqrt(dxN * dxN + dyN * dyN);
      if (dist > _notchAvoidanceRadius + 4) return Offset(x, y);
    }
    // Fallback: alguno de los dos lados del notch.
    final side = _rng.nextBool() ? -1 : 1;
    return Offset(cx + side * (_notchAvoidanceRadius + 12), _notchY);
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (!_initialized || dt <= 0 || dt > 0.1) return;

    _wobblePhase += dt * 6.5;

    // Vector hacia el target.
    final dx = _target.dx - _x;
    final dy = _target.dy - _y;
    final dist = math.sqrt(dx * dx + dy * dy);

    if (dist > 1.5) {
      // Ángulo base + pequeño wobble (no perfectamente recto).
      final baseAngle = math.atan2(dy, dx);
      final wobble = math.sin(_wobblePhase) * 0.18 +
          (_rng.nextDouble() - 0.5) * 0.08;
      final angle = baseAngle + wobble;
      final step = math.min(dist, _currentSpeed * dt);
      _x += math.cos(angle) * step;
      _y += math.sin(angle) * step;
      if (math.cos(angle) > 0.05) _facingSign = 1;
      if (math.cos(angle) < -0.05) _facingSign = -1;
    } else {
      // Llegó cerca del target → escoge uno nuevo inmediatamente.
      _targetTimer?.cancel();
      _target = _pickRandomTarget();
      _currentSpeed = _baseSpeed * (0.6 + _rng.nextDouble() * 0.9);
      _scheduleNewTarget();
    }

    // Esquivar el notch (círculo invisible).
    final cx = _areaWidth / 2;
    final dxN = _x - cx;
    final dyN = _y - _notchY;
    final distN = math.sqrt(dxN * dxN + dyN * dyN);
    if (distN < _notchAvoidanceRadius && distN > 0.001) {
      final nx = dxN / distN;
      final ny = dyN / distN;
      _x = cx + nx * _notchAvoidanceRadius;
      _y = _notchY + ny * _notchAvoidanceRadius;
    }

    // Confinar al área del overlay.
    _x = _x.clamp(_spriteHalf, _areaWidth - _spriteHalf);
    _y = _y.clamp(_spriteHalf, _areaHeight - _spriteHalf);

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _areaWidth = constraints.maxWidth;
          _areaHeight = constraints.maxHeight;
          if (!_initialized && _areaWidth > 80) {
            _x = _areaWidth * 0.25;
            _y = _notchY;
            _target = Offset(_areaWidth * 0.75, _notchY);
            _initialized = true;
            _scheduleNewTarget();
          }
          return AnimatedBuilder(
            animation:
                Listenable.merge([_walkCtrl, _bounceCtrl, _bubbleCtrl]),
            builder: (_, __) {
              final frame =
                  (_walkCtrl.value * _walkFrames).floor() % _walkFrames;
              final bounce = Curves.easeOut.transform(_bounceCtrl.value);
              return Stack(
                children: [
                  if (_bubbleText != null) _buildBubble(),
                  Positioned(
                    left: _x - _spriteHalf,
                    top: _y - _spriteHalf - 4 * bounce,
                    width: _spriteSize,
                    height: _spriteSize,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..scale(_facingSign, 1.0, 1.0),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _onTap,
                        child: CustomPaint(
                          painter: _PetSpritePainter(
                            image: _sheet,
                            frame: frame,
                            row: _walkRow,
                            columns: _columns,
                            rows: _rows,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBubble() {
    // El bubble sale AL LADO del sprite, a su misma altura, con cola
    // horizontal apuntando al personaje. Si la mascota está a la izquierda,
    // el bubble va a su derecha; si está a la derecha, va a su izquierda.
    const double bubbleMaxWidth = 170;
    const double bubbleMinHeight = 26;
    const double tailWidth = 7;
    const double horizontalPad = 10;
    const double verticalPad = 6;
    const double gap = 4;

    final v = Curves.easeOutBack.transform(_bubbleCtrl.value.clamp(0.0, 1.0));
    final text = _bubbleText ?? '';

    // Mide el texto en hasta 2 líneas para que no se corte si es largo.
    final tp = TextPainter(
      text: TextSpan(text: text, style: _bubbleTextStyle),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: bubbleMaxWidth - horizontalPad * 2);
    final bodyW = (tp.width + horizontalPad * 2).clamp(40.0, bubbleMaxWidth);
    final bubbleH =
        (tp.height + verticalPad * 2).clamp(bubbleMinHeight, 80.0);
    final totalW = bodyW + tailWidth;

    // Decide a qué lado del sprite va: lado con más espacio.
    final spaceRight = _areaWidth - (_x + _spriteHalf);
    final tailOnLeft = spaceRight > totalW + gap + 4;

    final double left;
    if (tailOnLeft) {
      // Bubble a la DERECHA del sprite, cola a la IZQUIERDA del bubble.
      left = _x + _spriteHalf + gap;
    } else {
      // Bubble a la IZQUIERDA del sprite, cola a la DERECHA del bubble.
      left = _x - _spriteHalf - gap - totalW;
    }
    final clampedLeft = left.clamp(2.0, _areaWidth - totalW - 2);
    final top = (_y - bubbleH / 2).clamp(2.0, _areaHeight - bubbleH - 2);

    return Positioned(
      left: clampedLeft,
      top: top,
      width: totalW,
      height: bubbleH,
      child: IgnorePointer(
        child: Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.scale(
            alignment: tailOnLeft ? Alignment.centerLeft : Alignment.centerRight,
            scale: 0.55 + 0.45 * v.clamp(0.0, 1.0),
            child: CustomPaint(
              painter: _SpeechBubblePainter(
                tailOnLeft: tailOnLeft,
                tailWidth: tailWidth,
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  tailOnLeft ? tailWidth + horizontalPad : horizontalPad,
                  verticalPad,
                  tailOnLeft ? horizontalPad : tailWidth + horizontalPad,
                  verticalPad,
                ),
                child: Center(
                  child: Text(
                    text,
                    maxLines: 2,
                    softWrap: true,
                    textAlign: TextAlign.center,
                    style: _bubbleTextStyle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const TextStyle _bubbleTextStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: Color(0xFF1A1A1A),
    height: 1.1,
  );
}

class _SpeechBubblePainter extends CustomPainter {
  _SpeechBubblePainter({required this.tailOnLeft, required this.tailWidth});

  final bool tailOnLeft;
  final double tailWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyLeft = tailOnLeft ? tailWidth : 0.0;
    final bodyRight = tailOnLeft ? size.width : size.width - tailWidth;
    final bodyRect =
        Rect.fromLTRB(bodyLeft, 0, bodyRight, size.height);
    const radius = Radius.circular(12);
    final body = RRect.fromRectAndRadius(bodyRect, radius);

    final tailCenterY = size.height / 2;
    final tail = Path();
    if (tailOnLeft) {
      tail
        ..moveTo(bodyLeft, tailCenterY - 5)
        ..lineTo(0, tailCenterY)
        ..lineTo(bodyLeft, tailCenterY + 5)
        ..close();
    } else {
      tail
        ..moveTo(bodyRight, tailCenterY - 5)
        ..lineTo(size.width, tailCenterY)
        ..lineTo(bodyRight, tailCenterY + 5)
        ..close();
    }

    final shadow = Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.save();
    canvas.translate(0, 2);
    canvas.drawRRect(body, shadow);
    canvas.drawPath(tail, shadow);
    canvas.restore();

    final combined = Path.combine(
      PathOperation.union,
      Path()..addRRect(body),
      tail,
    );

    final fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawPath(combined, fill);

    final stroke = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(combined, stroke);
  }

  @override
  bool shouldRepaint(covariant _SpeechBubblePainter old) =>
      old.tailOnLeft != tailOnLeft || old.tailWidth != tailWidth;
}

class _PetSpritePainter extends CustomPainter {
  _PetSpritePainter({
    required this.image,
    required this.frame,
    required this.row,
    required this.columns,
    required this.rows,
  });

  final ui.Image? image;
  final int frame;
  final int row;
  final int columns;
  final int rows;

  @override
  void paint(Canvas canvas, Size size) {
    final img = image;
    if (img == null) return;
    final frameW = img.width / columns;
    final frameH = img.height / rows;
    final src = Rect.fromLTWH(frameW * frame, frameH * row, frameW, frameH);
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(
      img,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(covariant _PetSpritePainter old) =>
      old.frame != frame || old.image != image || old.row != row;
}
