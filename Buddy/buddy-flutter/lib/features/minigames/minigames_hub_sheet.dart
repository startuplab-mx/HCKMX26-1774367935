import 'package:flutter/material.dart';

import '../../design/theme.dart';

enum MinigameID {
  catchFood,
  memoryMatch,
  tapReaction,
  rhythmTap;

  String get title => switch (this) {
        MinigameID.catchFood => 'Atrapa la comida',
        MinigameID.memoryMatch => 'Memorama',
        MinigameID.tapReaction => 'Reacción',
        MinigameID.rhythmTap => 'Rhythm Tap',
      };

  String get emoji => switch (this) {
        MinigameID.catchFood => '🍖',
        MinigameID.memoryMatch => '🃏',
        MinigameID.tapReaction => '🎯',
        MinigameID.rhythmTap => '🎵',
      };

  String get subtitle => switch (this) {
        MinigameID.catchFood => '30s · gana monedas atrapando comida',
        MinigameID.memoryMatch => 'Encuentra parejas en pocos movs.',
        MinigameID.tapReaction => '30s · toca al pet más rápido posible',
        MinigameID.rhythmTap => '25 rondas · tap al ritmo del beat',
      };
}

class MinigamesHubSheet extends StatelessWidget {
  final ValueChanged<MinigameID> onPick;

  const MinigamesHubSheet({super.key, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: BuddyTheme.consoleBG,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: BuddyTheme.darkInk.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Mini-juegos',
                  style: BuddyTheme.pixel(size: 22, weight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Juega para ganar monedas',
                  style: BuddyTheme.pixel(
                      size: 11,
                      color: BuddyTheme.darkInk.withValues(alpha: 0.6))),
              const SizedBox(height: 16),
              for (final g in MinigameID.values) ...[
                _GameCard(game: g, onTap: () => onPick(g)),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _GameCard extends StatelessWidget {
  final MinigameID game;
  final VoidCallback onTap;

  const _GameCard({required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: BuddyTheme.buttonBG,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: BuddyTheme.buttonStroke.withValues(alpha: 0.4),
              width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: BuddyTheme.lcdInner,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BuddyTheme.lcdStroke, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(game.emoji, style: const TextStyle(fontSize: 36)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(game.title,
                      style:
                          BuddyTheme.pixel(size: 16, weight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(game.subtitle,
                      style: BuddyTheme.pixel(
                          size: 11,
                          color:
                              BuddyTheme.darkInk.withValues(alpha: 0.6))),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: BuddyTheme.darkInk.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}
