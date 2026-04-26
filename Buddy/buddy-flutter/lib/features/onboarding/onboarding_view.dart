import 'package:flutter/material.dart';

import '../../design/theme.dart';
import '../../models/pet_character.dart';
import '../../widgets/stone_button.dart';

class OnboardingView extends StatefulWidget {
  final void Function(String name, PetCharacter character) onFinish;
  const OnboardingView({super.key, required this.onFinish});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  String _name = '';
  PetCharacter _character = PetCharacter.pikachu;
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _finish() {
    widget.onFinish(_name.trim(), _character);
  }

  @override
  Widget build(BuildContext context) {
    final canAdvance = _nameCtrl.text.trim().isNotEmpty;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Image.asset(
            'assets/sources/fondo_pantalla_inicio.jpg',
            fit: BoxFit.cover,
          ),
          
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Title & Input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Text(
                        '¿Como se llamará tu amig@?',
                        style: BuddyTheme.pixel(
                          size: 24,
                          color: const Color(0xFF3E2723),
                          weight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _nameCtrl,
                        textAlign: TextAlign.center,
                        style: BuddyTheme.pixel(size: 20),
                        onChanged: (v) => setState(() => _name = v),
                        decoration: InputDecoration(
                          hintText: 'Nombre...',
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ],
                  ),
                ),

                // Carousel
                SizedBox(
                  height: 160,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: PetCharacter.values.length,
                    itemBuilder: (context, index) {
                      final c = PetCharacter.values[index];
                      final isSelected = c == _character;
                      return GestureDetector(
                        onTap: () => setState(() => _character = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 16),
                          width: 120,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFF8F0D8) : Colors.white.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF616161) : Colors.transparent,
                              width: 4,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(c.portraitAsset, height: 110, fit: BoxFit.contain),
                              const SizedBox(height: 4),
                              Text(
                                c.displayName,
                                style: BuddyTheme.pixel(size: 14, weight: isSelected ? FontWeight.bold : FontWeight.normal),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Button
                Opacity(
                  opacity: canAdvance ? 1.0 : 0.5,
                  child: StoneButton(
                    text: 'Crear Buddy',
                    onTap: canAdvance ? _finish : () {},
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
