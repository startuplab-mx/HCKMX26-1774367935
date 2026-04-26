import 'dart:math';

import '../../models/pet.dart';
import '../persistence/coin_wallet.dart';

enum RandomEvent {
  giftBox,
  foundFood,
  visitor,
  stormyMood,
  gustOfWind,
  lazyMode;

  String get emoji => switch (this) {
        RandomEvent.giftBox    => '🎁',
        RandomEvent.foundFood  => '🍱',
        RandomEvent.visitor    => '👋',
        RandomEvent.stormyMood => '⛈',
        RandomEvent.gustOfWind => '🌬',
        RandomEvent.lazyMode   => '😴',
      };

  String get title => switch (this) {
        RandomEvent.giftBox    => 'Caja sorpresa',
        RandomEvent.foundFood  => 'Comida encontrada',
        RandomEvent.visitor    => 'Tu mascota recibió una visita',
        RandomEvent.stormyMood => 'Cambio de humor',
        RandomEvent.gustOfWind => 'Polvo en el ambiente',
        RandomEvent.lazyMode   => 'Día flojo',
      };

  String get detail => switch (this) {
        RandomEvent.giftBox    => '+15 monedas',
        RandomEvent.foundFood  => '+25 hambre',
        RandomEvent.visitor    => '+20 felicidad',
        RandomEvent.stormyMood => '-15 felicidad',
        RandomEvent.gustOfWind => '-15 higiene',
        RandomEvent.lazyMode   => '-20 energía',
      };

  bool get isPositive => switch (this) {
        RandomEvent.giftBox || RandomEvent.foundFood || RandomEvent.visitor => true,
        _ => false,
      };
}

class RandomEventService {
  static final _rng = Random();

  /// 8% de probabilidad por llamada. Si dispara, aplica el efecto y devuelve el evento.
  static Future<RandomEvent?> maybeTrigger(Pet pet) async {
    if (_rng.nextInt(100) >= 8) return null;
    final event = RandomEvent.values[_rng.nextInt(RandomEvent.values.length)];
    await _apply(event, pet);
    return event;
  }

  static Future<void> _apply(RandomEvent event, Pet pet) async {
    final s = pet.stats;
    switch (event) {
      case RandomEvent.giftBox:
        await CoinWallet.add(15);
        break;
      case RandomEvent.foundFood:
        s.hunger = (s.hunger + 25).clamp(0, 100);
        break;
      case RandomEvent.visitor:
        s.happiness = (s.happiness + 20).clamp(0, 100);
        break;
      case RandomEvent.stormyMood:
        s.happiness = (s.happiness - 15).clamp(0, 100);
        break;
      case RandomEvent.gustOfWind:
        s.hygiene = (s.hygiene - 15).clamp(0, 100);
        break;
      case RandomEvent.lazyMode:
        s.energy = (s.energy - 20).clamp(0, 100);
        break;
    }
    s.clamp();
    pet.stats = s;
  }
}
