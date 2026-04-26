enum PetAction {
  idle,
  eat,
  sleep,
  play,
  sad;

  String get raw => name;

  String get label => switch (this) {
        PetAction.idle  => 'tranquilo',
        PetAction.eat   => 'comiendo',
        PetAction.sleep => 'durmiendo',
        PetAction.play  => 'jugando',
        PetAction.sad   => 'triste',
      };

  String get emoji => switch (this) {
        PetAction.idle  => '✨',
        PetAction.eat   => '🍖',
        PetAction.sleep => '💤',
        PetAction.play  => '🎾',
        PetAction.sad   => '😢',
      };

  /// 4×4 sheet layout: row 0 idle | row 1 walk | row 2 eat | row 3 sleep
  ({int row, List<int> frames}) get spriteFrames => switch (this) {
        PetAction.idle  => (row: 0, frames: const [0, 1, 2, 3]),
        PetAction.eat   => (row: 2, frames: const [0, 1, 2, 3]),
        PetAction.sleep => (row: 3, frames: const [0, 1, 2, 3]),
        PetAction.play  => (row: 1, frames: const [0, 1, 2, 3]),
        PetAction.sad   => (row: 0, frames: const [0, 1]),
      };

  static PetAction fromRaw(String? r) =>
      PetAction.values.firstWhere((e) => e.name == r, orElse: () => PetAction.idle);
}
