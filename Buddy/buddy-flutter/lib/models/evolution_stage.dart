enum EvolutionStage {
  baby,
  kid,
  teen,
  adult,
  elder;

  String get label => switch (this) {
        EvolutionStage.baby  => 'Bebé',
        EvolutionStage.kid   => 'Cachorro',
        EvolutionStage.teen  => 'Joven',
        EvolutionStage.adult => 'Adulto',
        EvolutionStage.elder => 'Anciano',
      };

  double get spriteScale => switch (this) {
        EvolutionStage.baby  => 0.6,
        EvolutionStage.kid   => 0.75,
        EvolutionStage.teen  => 0.9,
        EvolutionStage.adult => 1.0,
        EvolutionStage.elder => 1.0,
      };

  String get emoji => switch (this) {
        EvolutionStage.baby  => '🍼',
        EvolutionStage.kid   => '🐾',
        EvolutionStage.teen  => '🌟',
        EvolutionStage.adult => '👑',
        EvolutionStage.elder => '🎩',
      };

  static EvolutionStage forAgeDays(int days) {
    if (days < 2)  return EvolutionStage.baby;
    if (days < 5)  return EvolutionStage.kid;
    if (days < 10) return EvolutionStage.teen;
    if (days < 25) return EvolutionStage.adult;
    return EvolutionStage.elder;
  }
}
