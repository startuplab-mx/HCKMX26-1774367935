import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/theme.dart';
import '../../models/pet_character.dart';
import '../../widgets/animated_sprite_sheet.dart';
import '../../widgets/pet_visual.dart';
import '../../widgets/stone_button.dart';

class NamePetView extends StatefulWidget {
  final PetCharacter character;
  final void Function(String name, PetCharacter character) onFinish;

  const NamePetView({
    super.key,
    required this.character,
    required this.onFinish,
  });

  @override
  State<NamePetView> createState() => _NamePetViewState();
}

class _NamePetViewState extends State<NamePetView>
    with TickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  late final AnimationController _bgController;
  late final AnimationController _entryController;
  SpriteAction _action = SpriteAction.idle;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _ctrl.addListener(() => setState(() {}));
    _cycleAction();
  }

  void _cycleAction() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) return;
      setState(() => _action =
          _action == SpriteAction.idle ? SpriteAction.walk : SpriteAction.idle);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _bgController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  bool get _canAdvance => _ctrl.text.trim().isNotEmpty;

  void _finish() {
    if (!_canAdvance) return;
    widget.onFinish(_ctrl.text.trim(), widget.character);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _bgController,
            builder: (_, __) => Transform.scale(
              scale: 1.18,
              child: Image.asset(
                'assets/sources/fondo_pantalla_inicio.jpg',
                fit: BoxFit.cover,
                alignment: Alignment((_bgController.value * 2) - 1, 0),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.4),
                ],
                stops: const [0, 0.45, 1],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset > 0 ? 12 : 0),
              child: Column(
                children: [
                  _Header(onBack: () => Navigator.of(context).maybePop()),
                  const SizedBox(height: 8),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _entryController,
                      builder: (_, child) {
                        final v =
                            Curves.easeOutBack.transform(_entryController.value);
                        return Transform.translate(
                          offset: Offset(0, (1 - v) * 30),
                          child: Opacity(opacity: _entryController.value, child: child),
                        );
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const _SpeechBubble(
                            text: '¡Hola! ¿Cómo me llamarás?',
                          ),
                          const SizedBox(height: 8),
                          PetVisual(
                            character: widget.character,
                            size: 220,
                            action: _action,
                          ),
                          const SizedBox(height: 4),
                          // Sombra suelo
                          Container(
                            width: 130,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _RetroInput(
                    controller: _ctrl,
                    focusNode: _focus,
                    onSubmitted: (_) => _finish(),
                  ),
                  const SizedBox(height: 18),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _canAdvance ? 1.0 : 0.45,
                    child: StoneButton(
                      text: 'Crear Buddy',
                      onTap: _finish,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _PixelIconButton(icon: Icons.arrow_back_rounded, onTap: onBack),
          const Spacer(),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _PixelIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _PixelIconButton({required this.icon, required this.onTap});

  @override
  State<_PixelIconButton> createState() => _PixelIconButtonState();
}

class _PixelIconButtonState extends State<_PixelIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 44,
        height: 44,
        transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9E6),
          border: Border.all(color: const Color(0xFF3E2723), width: 3),
          borderRadius: BorderRadius.circular(12),
          boxShadow: _pressed
              ? []
              : const [
                  BoxShadow(color: Colors.black54, offset: Offset(0, 3), blurRadius: 0),
                ],
        ),
        child: Icon(widget.icon, color: const Color(0xFF3E2723), size: 22),
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  final String text;
  const _SpeechBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: CustomPaint(
        painter: _BubbleTailPainter(),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9E6),
            border: Border.all(color: const Color(0xFF3E2723), width: 4),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black45, offset: Offset(0, 4), blurRadius: 0),
            ],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: BuddyTheme.pixel(
              size: 18,
              color: const Color(0xFF3E2723),
              weight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = const Color(0xFFFFF9E6);
    final stroke = Paint()
      ..color = const Color(0xFF3E2723)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final path = Path()
      ..moveTo(size.width / 2 - 12, size.height - 4)
      ..lineTo(size.width / 2, size.height + 14)
      ..lineTo(size.width / 2 + 12, size.height - 4)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RetroInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;

  const _RetroInput({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9E6),
          border: Border.all(color: const Color(0xFF3E2723), width: 4),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              offset: Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.words,
          maxLength: 14,
          onSubmitted: onSubmitted,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-zÀ-ÿ0-9 ]')),
          ],
          style: BuddyTheme.pixel(
            size: 22,
            color: const Color(0xFF3E2723),
            weight: FontWeight.bold,
          ),
          cursorColor: const Color(0xFFB0457A),
          cursorWidth: 3,
          decoration: InputDecoration(
            counterText: '',
            border: InputBorder.none,
            isCollapsed: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            hintText: 'Nombre...',
            hintStyle: BuddyTheme.pixel(
              size: 20,
              color: const Color(0xFF8D6E63),
              weight: FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
