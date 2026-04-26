import 'package:flutter/material.dart';

import '../../design/theme.dart';
import '../../models/pet_character.dart';
import '../../widgets/pet_visual.dart';
import '../../widgets/stone_button.dart';
import 'name_pet_view.dart';

class PickCharacterView extends StatefulWidget {
  final void Function(String name, PetCharacter character) onFinish;

  const PickCharacterView({super.key, required this.onFinish});

  @override
  State<PickCharacterView> createState() => _PickCharacterViewState();
}

class _PickCharacterViewState extends State<PickCharacterView>
    with SingleTickerProviderStateMixin {
  late final PageController _controller;
  late final AnimationController _bgController;
  int _index = 0;
  double _page = 0;

  static const _initialIndex = 1; // Pikachu por defecto

  @override
  void initState() {
    super.initState();
    _index = _initialIndex;
    _page = _initialIndex.toDouble();
    _controller = PageController(
      viewportFraction: 0.55,
      initialPage: _initialIndex,
    )..addListener(() {
        setState(() => _page = _controller.page ?? _index.toDouble());
      });
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _bgController.dispose();
    super.dispose();
  }

  void _continue() {
    final character = PetCharacter.values[_index];
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, anim, __) => NamePetView(
          character: character,
          onFinish: widget.onFinish,
        ),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = PetCharacter.values[_index];

    return Scaffold(
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

          // Capa de oscurecimiento sutil para legibilidad
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.35),
                ],
                stops: const [0, 0.45, 1],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _Header(onBack: () => Navigator.of(context).maybePop()),
                const SizedBox(height: 8),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: PetCharacter.values.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (_, i) {
                      final delta = (i - _page).abs().clamp(0.0, 1.0);
                      final scale = 1.0 - (delta * 0.35);
                      final opacity = 1.0 - (delta * 0.55);
                      final yOffset = delta * 24;
                      final character = PetCharacter.values[i];
                      return Center(
                        child: Opacity(
                          opacity: opacity,
                          child: Transform.translate(
                            offset: Offset(0, yOffset),
                            child: Transform.scale(
                              scale: scale,
                              child: PetVisual(
                                character: character,
                                size: 240,
                                playing: i == _index,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _InfoCard(character: selected),
                const SizedBox(height: 16),
                _PageIndicator(
                  count: PetCharacter.values.length,
                  index: _index,
                ),
                const SizedBox(height: 24),
                StoneButton(text: 'Continuar', onTap: _continue),
                const SizedBox(height: 28),
              ],
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
          _BackButton(onTap: onBack),
          Expanded(
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    'Elige tu Buddy',
                    style: BuddyTheme.pixel(
                      size: 28,
                      color: const Color(0xFF3E2723),
                      weight: FontWeight.bold,
                    ),
                  ),
                  Positioned(
                    top: -3,
                    left: -2,
                    child: Text(
                      'Elige tu Buddy',
                      style: BuddyTheme.pixel(
                        size: 28,
                        color: Colors.white,
                        weight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _BackButton extends StatefulWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
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
                  BoxShadow(
                    color: Colors.black54,
                    offset: Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          color: Color(0xFF3E2723),
          size: 22,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final PetCharacter character;
  const _InfoCard({required this.character});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(character),
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9E6),
          border: Border.all(color: const Color(0xFF3E2723), width: 4),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              offset: Offset(0, 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              character.displayName,
              style: BuddyTheme.pixel(
                size: 24,
                color: const Color(0xFF3E2723),
                weight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final int count;
  final int index;
  const _PageIndicator({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 14 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFFF9E6) : Colors.white.withValues(alpha: 0.4),
            border: Border.all(
              color: const Color(0xFF3E2723),
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}
