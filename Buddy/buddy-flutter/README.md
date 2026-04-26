# Buddy — versión Flutter

Port multiplataforma (Android + iOS) del juego Buddy. La app original en SwiftUI + SpriteKit vive en `../buddy-ios/` y sigue siendo la fuente de verdad de game design.

## Quick start

```bash
flutter pub get
flutter create .                  # genera carpetas android/, ios/ (no commiteadas)
flutter run                       # con un emulador o dispositivo conectado
```

> Si estás en Windows, sigue [`INSTALL_WINDOWS.md`](INSTALL_WINDOWS.md) primero.

## Estructura

```
buddy-flutter/
├── lib/
│   ├── main.dart                 # entry point
│   ├── app.dart                  # MaterialApp + routing
│   ├── design/                   # tema (colores, tipografía pixel)
│   ├── models/                   # Pet, PetStats, PetNeed, Personality, etc.
│   ├── core/
│   │   ├── persistence/          # PetStore, CoinWallet, etc. (shared_preferences)
│   │   └── services/             # PetService, ProgressionService, etc.
│   ├── features/
│   │   ├── home/                 # HomeView + componentes UI
│   │   ├── onboarding/           # OnboardingView (3 pasos)
│   │   ├── sheets/               # Stats, Pets, Scenes, Settings, Shop, ...
│   │   └── minigames/            # 4 minijuegos
│   ├── game/                     # Flame: BuddyScene, sprites, animaciones
│   └── widgets/                  # cross-cutting (BuddyCutoutSpot, Toast, ...)
└── assets/
    ├── sprites/                  # pet_sheet_*.png, player_sheet.png
    └── backgrounds/              # background_*.png
```

## Estado de la migración

Ver [`MIGRATION_STATUS.md`](MIGRATION_STATUS.md). En esta primera iteración están portados:

- Modelos completos (Pet, PetStats, PetNeed, Personality, Achievement, ShopItem, etc.)
- Lógica core (PetService con decay loop, ProgressionService, RandomEventService)
- Persistencia local (shared_preferences)
- HomeView con escena Flame, joystick, contextual button, LCDCard, TopBar, navegación pills
- Onboarding 3 pasos
- BuddyCutoutSpot (widget que aprovecha el notch/punch-hole en Android — ver `lib/widgets/buddy_cutout_spot.dart`)

Pendientes (stubs documentados): sheets completos, los 4 minijuegos, sync (Firebase/CloudKit), Live Activities/Dynamic Island vía platform channel, Habit Mirror via UsageStatsManager.
