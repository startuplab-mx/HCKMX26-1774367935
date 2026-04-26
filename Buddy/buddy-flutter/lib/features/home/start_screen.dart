import 'package:flutter/material.dart';
import '../../core/persistence/pet_store.dart';
import '../../design/theme.dart';
import '../../models/pet.dart';
import '../../widgets/stone_button.dart';
import '../onboarding/pick_character_view.dart';
import 'home_view.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> with SingleTickerProviderStateMixin {
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Parallax
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              // Escalamos un poco para garantizar margen de movimiento horizontal
              return Transform.scale(
                scale: 1.15,
                child: Image.asset(
                  'assets/sources/fondo_pantalla_inicio.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment((_bgController.value * 2) - 1, 0),
                ),
              );
            },
          ),
          
          // Content
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top: Buddy Title
                Padding(
                  padding: const EdgeInsets.only(top: 80.0),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Depth/Shadow
                          Text(
                            'Buddy',
                            style: BuddyTheme.pixel(
                              size: 72,
                              color: const Color(0xFF3E2723), // Darker brown for depth
                              weight: FontWeight.bold,
                            ),
                          ),
                          // Main Text
                          Positioned(
                            top: -6,
                            left: -4,
                            child: Text(
                              'Buddy',
                              style: BuddyTheme.pixel(
                                size: 72,
                                color: const Color(0xFF795548), // Main brown
                                weight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Subtitle
                      Text(
                        'Un amigo mas con el que puedes contar.',
                        style: BuddyTheme.pixel(
                          size: 14,
                          color: Colors.white,
                          weight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Bottom: Buttons and Footer
                Column(
                  children: [
                    StoneButton(
                      text: 'Buddy Nuevo',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PickCharacterView(
                              onFinish: (name, character) async {
                                final pet = Pet(name: name.isEmpty ? 'Buddy' : name, character: character);
                                await PetStore.save(pet);
                                if (context.mounted) {
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(builder: (_) => const HomeGate()),
                                    (_) => false,
                                  );
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    StoneButton(
                      text: 'Iniciar sesion',
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const HomeGate()),
                        );
                      },
                    ),
                    const SizedBox(height: 60),
                    // Footer text
                    Text(
                      'Una idea de Fluw: Por ti y para ti.',
                      style: BuddyTheme.pixel(
                        size: 14,
                        color: Colors.white,
                        weight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

