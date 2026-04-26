import 'package:flutter/material.dart';

enum RoomKind { livingRoom, kitchen, bedroom, garden }

class Room {
  final RoomKind kind;
  final String label;
  final String background;
  final IconData hotSpotIcon;
  final String hotSpotLabel;
  final Alignment hotSpotAlignment;

  const Room({
    required this.kind,
    required this.label,
    required this.background,
    required this.hotSpotIcon,
    required this.hotSpotLabel,
    required this.hotSpotAlignment,
  });

  static const all = <Room>[
    Room(
      kind: RoomKind.livingRoom,
      label: 'Sala',
      background: 'assets/backgrounds/background_living_room.png',
      hotSpotIcon: Icons.sports_baseball,
      hotSpotLabel: 'Jugar',
      hotSpotAlignment: Alignment(0.55, 0.55),
    ),
    Room(
      kind: RoomKind.kitchen,
      label: 'Cocina',
      background: 'assets/backgrounds/background_kitchen.png',
      hotSpotIcon: Icons.restaurant,
      hotSpotLabel: 'Comer',
      hotSpotAlignment: Alignment(-0.45, 0.55),
    ),
    Room(
      kind: RoomKind.bedroom,
      label: 'Dormitorio',
      background: 'assets/backgrounds/background_bedroom.png',
      hotSpotIcon: Icons.bed,
      hotSpotLabel: 'Dormir',
      hotSpotAlignment: Alignment(0.55, 0.4),
    ),
    Room(
      kind: RoomKind.garden,
      label: 'Jardín',
      background: 'assets/backgrounds/background_garden.png',
      hotSpotIcon: Icons.shower,
      hotSpotLabel: 'Bañar',
      hotSpotAlignment: Alignment(-0.5, 0.5),
    ),
  ];
}
