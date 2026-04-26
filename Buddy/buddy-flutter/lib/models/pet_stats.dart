class PetStats {
  int hunger;
  int thirst;
  int energy;
  int hygiene;
  int happiness;

  PetStats({
    required this.hunger,
    required this.thirst,
    required this.energy,
    required this.hygiene,
    required this.happiness,
  });

  factory PetStats.newborn() => PetStats(
        hunger: 70,
        thirst: 70,
        energy: 100,
        hygiene: 100,
        happiness: 80,
      );

  void clamp() {
    hunger    = hunger.clamp(0, 100);
    thirst    = thirst.clamp(0, 100);
    energy    = energy.clamp(0, 100);
    hygiene   = hygiene.clamp(0, 100);
    happiness = happiness.clamp(0, 100);
  }

  Map<String, dynamic> toJson() => {
        'hunger': hunger,
        'thirst': thirst,
        'energy': energy,
        'hygiene': hygiene,
        'happiness': happiness,
      };

  factory PetStats.fromJson(Map<String, dynamic> j) => PetStats(
        hunger: j['hunger'] as int,
        thirst: j['thirst'] as int,
        energy: j['energy'] as int,
        hygiene: j['hygiene'] as int,
        happiness: j['happiness'] as int,
      );
}
