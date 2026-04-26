import 'package:flutter/material.dart';

import '../../design/theme.dart';

/// Stub. Reemplazar por implementaciones equivalentes a las de iOS.
/// Ver `MIGRATION_STATUS.md` para el listado de sheets pendientes.
class PlaceholderSheet extends StatelessWidget {
  final String title;
  final String emoji;
  final String description;
  const PlaceholderSheet({
    super.key,
    required this.title,
    required this.emoji,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      minChildSize: 0.3,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: BuddyTheme.consoleBG,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: BuddyTheme.darkInk.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(child: Text(emoji, style: const TextStyle(fontSize: 64))),
              const SizedBox(height: 16),
              Center(
                child: Text(title,
                    style: BuddyTheme.pixel(size: 22, weight: FontWeight.bold),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(height: 12),
              Text(description,
                  style: BuddyTheme.pixel(size: 13, color: BuddyTheme.darkInk.withValues(alpha: 0.7)),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BuddyTheme.buttonStroke, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TODO · port pendiente',
                        style: BuddyTheme.pixel(size: 11, weight: FontWeight.bold, color: BuddyTheme.actionPink)),
                    const SizedBox(height: 8),
                    Text(
                      'Esta sheet existe en `buddy-ios/`. Falta portarla a Dart con la lógica de '
                      'persistencia (shared_preferences). Ver `MIGRATION_STATUS.md`.',
                      style: BuddyTheme.pixel(size: 11, color: BuddyTheme.darkInk.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
