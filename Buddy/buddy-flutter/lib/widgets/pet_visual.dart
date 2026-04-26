import 'package:flutter/material.dart';

import '../models/pet_character.dart';
import 'animated_sprite_sheet.dart';
import 'live_portrait.dart';

/// Wrapper que decide cómo dibujar al personaje según lo que tenga disponible.
/// Si el personaje cuenta con un sheet animado lo usa con la fila correcta;
/// si no, cae al `LivePortrait` con animación procedural.
///
/// Además aplica un fallback de acción: si el caller pide bath/caress/play/happy
/// pero el sheet del personaje todavía no tiene esas filas (caso de Pikachu,
/// Mario, Kuromi), mapeamos a la animación más cercana en lugar de crashear o
/// dejar transparente.
class PetVisual extends StatelessWidget {
  final PetCharacter character;
  final double size;
  final SpriteAction action;
  final bool playing;

  const PetVisual({
    super.key,
    required this.character,
    required this.size,
    this.action = SpriteAction.idle,
    this.playing = true,
  });

  @override
  Widget build(BuildContext context) {
    final sheet = character.sheetAsset;
    if (sheet == null) {
      return LivePortrait(
        asset: character.portraitAsset,
        size: size,
        seed: character.index,
        playing: playing,
      );
    }
    final rows = character.sheetRows;
    // Fallback razonable cuando el sheet no tiene la fila pedida:
    //   bath/caress -> idle (no hay equivalente, mejor neutral)
    //   play/happy  -> walk (al menos transmite movimiento)
    // El día que generemos sheets de 8 filas para los demás personajes,
    // este switch deja de aplicar porque action.index < rows pasa siempre.
    final effective = action.index < rows
        ? action
        : switch (action) {
            SpriteAction.bath => SpriteAction.idle,
            SpriteAction.caress => SpriteAction.idle,
            SpriteAction.play => SpriteAction.walk,
            SpriteAction.happy => SpriteAction.walk,
            _ => SpriteAction.idle,
          };
    return AnimatedSpriteSheet(
      asset: sheet,
      size: size,
      action: effective,
      rows: rows,
      playing: playing,
    );
  }
}
