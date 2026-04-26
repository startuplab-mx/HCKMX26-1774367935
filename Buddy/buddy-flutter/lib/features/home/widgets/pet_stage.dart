import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../models/pet.dart';
import '../../../models/pet_action.dart';
import '../../../widgets/animated_sprite_sheet.dart';
import '../../../widgets/pet_visual.dart';
import 'floating_emojis.dart';

/// Controlador externo para forzar una animación durante un tiempo definido.
/// Lo usa HomeView cuando el usuario toca un hotspot: por ejemplo, al tocar
/// "Comer" en la cocina, llamamos `show(SpriteAction.eat, duration: 2.8s)`
/// y el pet hace la animación de comer hasta que expira el timer interno;
/// después PetStage cae a su lógica normal (variedad procedural / pet.currentAction).
class PetStageController extends ChangeNotifier {
  SpriteAction? _override;
  Timer? _timer;
  SpriteAction? get current => _override;

  void show(SpriteAction action,
      {Duration duration = const Duration(milliseconds: 2500)}) {
    _override = action;
    notifyListeners();
    _timer?.cancel();
    _timer = Timer(duration, () {
      _override = null;
      notifyListeners();
    });
  }

  void clear() {
    _timer?.cancel();
    _override = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// El pet "vivo" en pantalla. Capas de prioridad sobre la animación:
/// 1. external override (controller) — bath/eat/sleep/play disparados por hotspot
/// 2. local override — caress al tap/hold del pet
/// 3. variedad procedural — alterna idle ↔ happy/walk para no estancarse
/// 4. mapeo desde pet.currentAction
class PetStage extends StatefulWidget {
  final Pet pet;
  final PetStageController controller;
  final FloatingEmojiController emojis;
  final VoidCallback onTap;
  final VoidCallback onCaressTick;
  final String? speech;

  const PetStage({
    super.key,
    required this.pet,
    required this.controller,
    required this.emojis,
    required this.onTap,
    required this.onCaressTick,
    this.speech,
  });

  @override
  State<PetStage> createState() => _PetStageState();
}

class _PetStageState extends State<PetStage> with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _bounceController;
  Timer? _holdTimer;
  Timer? _localOverrideTimer;
  Timer? _varietyTimer;
  SpriteAction? _localOverride; // caress on tap
  SpriteAction _idleVariant = SpriteAction.idle;
  bool _holding = false;
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    widget.controller.addListener(_onController);
    _scheduleVariety();
  }

  void _onController() {
    if (mounted) setState(() {});
  }

  /// "Variedad procedural": cada 6-13 s, si el pet está sin acción explícita,
  /// alternamos su animación entre idle, happy y walk con pesos 60/20/20.
  /// El objetivo es que se sienta vivo sin necesidad de input del usuario;
  /// si lo dejamos siempre en idle se ve estático y aburrido.
  void _scheduleVariety() {
    _varietyTimer?.cancel();
    _varietyTimer = Timer(
      Duration(seconds: 6 + _rng.nextInt(8)),
      () {
        if (!mounted) return;
        // Solo cambia variante si no hay nada de mayor prioridad activo.
        if (widget.controller.current == null &&
            _localOverride == null &&
            !_holding) {
          final pick = _rng.nextInt(10);
          setState(() {
            _idleVariant = pick < 6
                ? SpriteAction.idle
                : (pick < 8 ? SpriteAction.happy : SpriteAction.walk);
          });
          // Las variantes no-idle son visualmente fuertes; si las dejamos
          // permanentes hasta el siguiente tick (8-13 s) se ven raras.
          // Volvemos a idle a los 3-5 s.
          if (_idleVariant != SpriteAction.idle) {
            Future.delayed(Duration(seconds: 3 + _rng.nextInt(3)), () {
              if (mounted) setState(() => _idleVariant = SpriteAction.idle);
            });
          }
        }
        _scheduleVariety();
      },
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    _bounceController.dispose();
    widget.controller.removeListener(_onController);
    _holdTimer?.cancel();
    _localOverrideTimer?.cancel();
    _varietyTimer?.cancel();
    super.dispose();
  }

  SpriteAction _spriteFor(PetAction a) => switch (a) {
        PetAction.idle  => _idleVariant,
        PetAction.eat   => SpriteAction.eat,
        PetAction.sleep => SpriteAction.sleep,
        PetAction.play  => SpriteAction.play,
        PetAction.sad   => SpriteAction.idle,
      };

  /// Decide qué animación mostrar cada frame, en orden de prioridad:
  ///   1. Override externo (HomeView dispara bath/eat/sleep/play vía controller).
  ///   2. Override local (caress al tap o hold del propio pet).
  ///   3. Mapeo desde pet.currentAction (lo que dictan las mecánicas del juego).
  ///      Si currentAction es idle, usa _idleVariant (variedad procedural).
  SpriteAction _resolveAction() {
    if (widget.controller.current != null) return widget.controller.current!;
    if (_localOverride != null) return _localOverride!;
    return _spriteFor(widget.pet.currentAction);
  }

  void _flashLocal(SpriteAction action,
      {Duration duration = const Duration(milliseconds: 1500)}) {
    setState(() => _localOverride = action);
    _localOverrideTimer?.cancel();
    _localOverrideTimer = Timer(duration, () {
      if (mounted) setState(() => _localOverride = null);
    });
  }

  void _handleTapDown(TapDownDetails d) {
    _bounceController.forward(from: 0);
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(d.globalPosition);
    widget.emojis.burstHearts(local);
    widget.onTap();
    _flashLocal(SpriteAction.caress);
  }

  void _startHold() {
    setState(() {
      _holding = true;
      _localOverride = SpriteAction.caress;
    });
    _localOverrideTimer?.cancel();
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(milliseconds: 350), (_) {
      widget.onCaressTick();
      final box = context.findRenderObject() as RenderBox?;
      if (box != null) {
        final c = Offset(box.size.width / 2, box.size.height * 0.4);
        widget.emojis.spawn('✨', c, drift: (_rng.nextDouble() - 0.5) * 30);
      }
    });
  }

  void _stopHold() {
    setState(() {
      _holding = false;
      _localOverride = null;
    });
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_floatController, _bounceController, widget.pet]),
      builder: (_, __) {
        final floatY = _floatController.value * -10;
        final bounce = _bounceController.value;
        final scaleY = 1.0 + (bounce * 0.08) - (bounce * bounce * 0.16);
        final scaleX = 1.0 - (bounce * 0.04) + (bounce * bounce * 0.10);
        final action = _resolveAction();
        return Stack(
          alignment: Alignment.center,
          children: [
            // Sombra
            Positioned(
              bottom: 200,
              child: Transform.scale(
                scale: 1.0 - (_floatController.value * 0.12),
                child: Container(
                  width: 160,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ),

            // Pet
            Positioned(
              bottom: 210,
              child: GestureDetector(
                onTapDown: _handleTapDown,
                onLongPressStart: (_) => _startHold(),
                onLongPressEnd: (_) => _stopHold(),
                onLongPressCancel: _stopHold,
                child: Transform.translate(
                  offset: Offset(0, floatY),
                  child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.identity()..scale(scaleX, scaleY, 1.0),
                    child: PetVisual(
                      character: widget.pet.character,
                      size: 240,
                      action: action,
                    ),
                  ),
                ),
              ),
            ),

            // Burbuja de pensamiento
            if (widget.speech != null)
              Positioned(
                bottom: 460,
                child: _ThoughtBubble(text: widget.speech!),
              ),

            // Halo de caricia
            if (_holding)
              Positioned(
                bottom: 230,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.pinkAccent.withValues(alpha: 0.30),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ThoughtBubble extends StatelessWidget {
  final String text;
  const _ThoughtBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(text),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      builder: (_, t, child) => Transform.scale(scale: t, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9E6),
          border: Border.all(color: const Color(0xFF3E2723), width: 3),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              offset: Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Pix3M',
            fontSize: 14,
            color: Color(0xFF3E2723),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
