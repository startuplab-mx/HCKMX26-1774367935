enum PetCategory { famoso }

enum PetCharacter {
  garfield,
  pikachu,
  mario,
  kuromi;

  PetCategory get category => PetCategory.famoso;

  String get displayName => switch (this) {
        PetCharacter.garfield => 'Garfield',
        PetCharacter.pikachu  => 'Pikachu',
        PetCharacter.mario    => 'Mario',
        PetCharacter.kuromi   => 'Kuromi',
      };

  /// Imagen estática (retrato). Para famosos usamos el sheet entero como retrato.
  String get portraitAsset => sheetAsset;

  /// Path completo al spritesheet 4x4 animado.
  String get sheetAsset => switch (this) {
        PetCharacter.garfield => 'assets/sprites/pet_sheet_garfield.png',
        PetCharacter.pikachu  => 'assets/sprites/pet_sheet_pikachu.png',
        PetCharacter.mario    => 'assets/sprites/pet_sheet_mario.png',
        PetCharacter.kuromi   => 'assets/sprites/pet_sheet_kuromi.png',
      };

  bool get hasAnimatedSheet => true;

  /// Número de filas del spritesheet 4xN. Garfield tiene 8 (incluye bath,
  /// caress, play, happy). Los demás famosos aún 4 (idle, walk, eat, sleep).
  int get sheetRows => switch (this) {
        PetCharacter.garfield => 8,
        _ => 4,
      };

  /// Nombre del sheet (sin extensión) — usado por overlay/BuddyScene.
  String get spriteSheetAsset => switch (this) {
        PetCharacter.garfield => 'pet_sheet_garfield',
        PetCharacter.pikachu  => 'pet_sheet_pikachu',
        PetCharacter.mario    => 'pet_sheet_mario',
        PetCharacter.kuromi   => 'pet_sheet_kuromi',
      };

  int get unlockPrice => 0;

  String get emoji => switch (this) {
        PetCharacter.garfield => '🐱',
        PetCharacter.pikachu  => '⚡',
        PetCharacter.mario    => '🍄',
        PetCharacter.kuromi   => '👹',
      };

  static PetCharacter fromRaw(String? r) =>
      PetCharacter.values.firstWhere((e) => e.name == r, orElse: () => PetCharacter.pikachu);
}
