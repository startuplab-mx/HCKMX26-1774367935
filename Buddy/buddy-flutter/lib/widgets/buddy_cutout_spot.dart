import 'package:flutter/material.dart';

import '../models/pet.dart';
import '../models/pet_need.dart';

/// "Buddy Spot" — sustituto del Dynamic Island en Android. Renderiza un
/// pequeño widget anclado en la zona de la cámara (notch / punch-hole)
/// que muestra el estado del pet.
///
/// Limitaciones vs. Dynamic Island:
///   - Solo es visible **dentro de la app** (Android no permite overlays
///     system-level sin permisos especiales).
///   - Se ajusta al `viewPadding.top` del MediaQuery, que cubre el área
///     reservada por el sistema para la cámara/notch (DisplayCutout).
///
/// Uso:
/// ```dart
/// Stack(children: [
///   gameScene,
///   const Align(alignment: Alignment.topCenter, child: BuddyCutoutSpot(...)),
/// ])
/// ```
class BuddyCutoutSpot extends StatelessWidget {
  final Pet pet;
  final List<PetNeed> needs;

  const BuddyCutoutSpot({super.key, required this.pet, required this.needs});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).viewPadding.top;
    final mainNeed = needs.isNotEmpty ? needs.first : null;

    return Padding(
      padding: EdgeInsets.only(top: topInset > 0 ? topInset - 6 : 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        height: 32,
        constraints: const BoxConstraints(minWidth: 96, maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(pet.character.emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              pet.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),
            _moodPill(pet.moodLevel),
            if (mainNeed != null) ...[
              const SizedBox(width: 8),
              Text(mainNeed.emoji, style: const TextStyle(fontSize: 14)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _moodPill(int level) {
    final color = level >= 3
        ? Colors.greenAccent
        : level >= 2
            ? Colors.amberAccent
            : level >= 1
                ? Colors.orangeAccent
                : Colors.redAccent;
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
