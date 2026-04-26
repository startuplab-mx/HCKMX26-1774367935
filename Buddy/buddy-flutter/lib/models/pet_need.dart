import 'pet.dart';

enum PetNeed {
  hungry,
  thirsty,
  sleepy,
  dirty,
  bored;

  String get emoji => switch (this) {
        PetNeed.hungry  => '🍖',
        PetNeed.thirsty => '💧',
        PetNeed.sleepy  => '💤',
        PetNeed.dirty   => '🧼',
        PetNeed.bored   => '🎾',
      };

  String get label => switch (this) {
        PetNeed.hungry  => 'Hambre',
        PetNeed.thirsty => 'Sed',
        PetNeed.sleepy  => 'Sueño',
        PetNeed.dirty   => 'Sucio',
        PetNeed.bored   => 'Aburrido',
      };

  String get actionLabel => switch (this) {
        PetNeed.hungry  => 'Alimentar',
        PetNeed.thirsty => 'Dar agua',
        PetNeed.sleepy  => 'Dormir',
        PetNeed.dirty   => 'Bañar',
        PetNeed.bored   => 'Jugar',
      };

  int severity(Pet pet) => switch (this) {
        PetNeed.hungry  => 100 - pet.stats.hunger,
        PetNeed.thirsty => 100 - pet.stats.thirst,
        PetNeed.sleepy  => 100 - pet.stats.energy,
        PetNeed.dirty   => 100 - pet.stats.hygiene,
        PetNeed.bored   => 100 - pet.stats.happiness,
      };
}
