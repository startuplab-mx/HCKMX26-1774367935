# Migration status · iOS Swift → Flutter

Snapshot al **2026-04-25**. La fuente de verdad de game design sigue siendo `buddy-ios/`. Esta tabla mide qué tan lejos llegamos del scaffolding inicial.

## Leyenda

- ✅ **Done** · portado y funcional (no es necesariamente UI-perfect; la idea es paridad funcional)
- 🟡 **Stub** · existe la clase/widget pero la lógica está como TODO
- ⏳ **Pending** · no existe en la versión Flutter todavía

## Models (`lib/models/`)

| Original (Swift)     | Dart                        | Estado |
|----------------------|-----------------------------|--------|
| `Pet.swift`          | `pet.dart`                  | ✅     |
| `PetStats.swift`     | `pet_stats.dart`            | ✅     |
| `PetAction.swift`    | `pet_action.dart`           | ✅     |
| `PetNeed.swift`      | `pet_need.dart`             | ✅     |
| `PetCharacter.swift` | `pet_character.dart`        | ✅     |
| `EvolutionStage.swift`| `evolution_stage.dart`     | ✅     |
| `Personality.swift`  | `personality.dart`          | ✅     |
| `Achievement.swift`  | `achievement.dart`          | ✅     |
| `ShopItem.swift`     | `shop_item.dart`            | ✅     |
| `DiaryEntry.swift`   | `diary_entry.dart`          | ✅     |
| `SceneTheme` (en `ScenesSheet.swift`) | `scene_theme.dart` | ✅ |

## Persistencia (`lib/core/persistence/`)

| Original (Swift)              | Dart                          | Estado |
|-------------------------------|-------------------------------|--------|
| `PetStore`                    | `pet_store.dart`              | ✅     |
| `CoinWallet`                  | `coin_wallet.dart`            | ✅     |
| `CharacterStore`              | `character_store.dart`        | ✅     |
| `InventoryStore`              | dentro de `models/shop_item.dart` | ✅ |
| `SceneStore`                  | dentro de `models/scene_theme.dart` | ✅ |

## Services (`lib/core/services/`)

| Original (Swift)              | Dart                          | Estado | Nota |
|-------------------------------|-------------------------------|--------|------|
| `PetService`                  | `pet_service.dart`            | ✅     | Decay loop con `Timer.periodic` cada 5s, mismas reglas que iOS |
| `ProgressionService`          | `progression_service.dart`    | ✅     | XP, level, daily bonus completos |
| `RandomEventService`          | `random_event_service.dart`   | ✅     | 8% por tick, mismos eventos |
| `AchievementUnlocker`         | `achievement_unlocker.dart`   | ✅     | Misma matriz de detección |
| `ToastQueue`                  | `toast_queue.dart`            | ✅     | Singleton + ChangeNotifier |
| `SoundService`                | `sound_service.dart`          | 🟡    | Por ahora reproduce `SystemSound.click` para todo. Falta cargar clips por acción con `audioplayers` |
| `PetVoiceService`             | `pet_voice_service.dart`      | 🟡    | Stub |
| `NotificationService`         | `notification_service.dart`   | 🟡    | Pubspec ya tiene `flutter_local_notifications`. Falta inicialización + `scheduleNeedReminders` |
| `CloudKitService`             | `cloud_sync_service.dart`     | 🟡    | **Decisión pendiente: Firebase vs Supabase**. iOS usa CloudKit nativo; en Flutter no hay equivalente directo |
| `LiveActivityManager`         | `live_activity_service.dart`  | 🟡    | iOS via `MethodChannel` → módulo Swift nativo (TODO). Android no-op |
| `HabitMirrorService`          | `habit_mirror_service.dart`   | 🟡    | Requiere implementaciones específicas: Android `UsageStatsManager` + iOS Screen Time |

## UI · Home + componentes (`lib/features/home/`)

| Componente              | Dart                                       | Estado |
|-------------------------|--------------------------------------------|--------|
| `HomeView`              | `home_view.dart`                           | ✅     |
| `TopBar`                | `components/top_bar.dart`                  | ✅     |
| `LCDCard`               | `components/lcd_card.dart`                 | ✅     |
| `JoystickView`          | `components/joystick.dart`                 | ✅     |
| `ActionButton`          | `components/action_button.dart`            | ✅     |
| `PixelButton`           | `components/pixel_button.dart`             | ✅     |
| `ToastBanner`           | `components/toast_banner.dart`             | ✅     |
| Bottom navigation pills | inline en `home_view.dart`                 | ✅     |
| XP bar                  | inline en `home_view.dart`                 | ✅     |
| Contextual button       | inline en `home_view.dart`                 | ✅     |
| `BuddySpot` row         | inline en `home_view.dart` + `BuddyCutoutSpot` widget | ✅ |

## Game (`lib/game/`)

| Original (SpriteKit)    | Dart (Flame)               | Estado |
|-------------------------|----------------------------|--------|
| `BuddyScene`            | `buddy_scene.dart`         | ✅     |
| `SpriteSheet`           | inline en `buddy_scene.dart` (función `_animationFromSheet`) | ✅ |
| Pet wandering AI        | TODO en `buddy_scene.dart` | ⏳    |
| Drag pet (touch + drag) | TODO (tap + double-tap sí) | ⏳    |
| Cosmetics (accessories) | ✅ via `setAccessory()`    | ✅     |

## Onboarding

| Pantalla                | Dart                              | Estado |
|-------------------------|-----------------------------------|--------|
| `OnboardingView` (3 pasos) | `features/onboarding/onboarding_view.dart` | ✅ |

## Sheets (`lib/features/sheets/`)

Todas usan el `PlaceholderSheet` por defecto. **Pendiente portar**:

| iOS                         | Estado | Prioridad |
|-----------------------------|--------|-----------|
| `StatsSheet`                | ⏳     | Alta — datos del pet, ya tenemos los modelos |
| `PetsSheet`                 | ⏳     | Alta — cambio de personaje |
| `ScenesSheet`               | ⏳     | Alta — cambio de fondo |
| `SettingsSheet`             | ⏳     | Alta — toggles + reset |
| `ShopSheet`                 | ⏳     | Media |
| `AchievementsSheet`         | ⏳     | Media |
| `DiarySheet`                | ⏳     | Baja — historial de eventos |
| `PhotoModeSheet`            | ⏳     | Baja — usa `image` package |
| `ReincarnationSheet`        | ⏳     | Media — se muestra al morir |
| `ShareCaretakerSheet`       | ⏳     | Bloqueada por `CloudSyncService` |
| `MinigamesHubSheet`         | ⏳     | Media |

## Minijuegos (`lib/features/minigames/`)

Ninguno portado. La lógica es Swift puro fácil de portar.

| iOS                  | Estado |
|----------------------|--------|
| `CatchFoodGame`      | ⏳     |
| `MemoryMatchGame`    | ⏳     |
| `TapReactionGame`    | ⏳     |
| `RhythmTapGame`      | ⏳     |

## Widgets cross-cutting (`lib/widgets/`)

| Widget                 | Estado |
|------------------------|--------|
| `BuddyCutoutSpot`      | ✅ Anclado al cutout vía `MediaQuery.viewPadding.top`. Visible solo dentro de la app |

## Plataforma · iOS-only features que necesitan platform channels

Estos no aplican en Android pero si alguien va a publicar en iOS hay que escribir el módulo Swift:

- **Live Activities + Dynamic Island**: re-usar `Sources/buddy/Core/LiveActivity/*.swift` desde `ios/Runner/`. El `MethodChannel` ya está definido (`buddy/live_activity`).
- **Screen Time API** (Habit Mirror): adaptar a `DeviceActivity`/`FamilyControls` y exponerlo por canal.
- **CloudKit**: si la decisión final es seguir con CloudKit en iOS y Firebase en Android, se puede tener doble implementación tras `CloudSyncService`.

## Decisiones pendientes (bloqueantes para sacar v1)

1. **Backend de sync multi-cuidador**: Firebase / Supabase / propio
2. **Live Activities**: ¿solo iOS, o se simula en Android con notificación expandida persistente?
3. **Habit Mirror**: ¿se mantiene como feature, o se quita para v1 multiplataforma?
4. **AI** (referenciada en `commit 72a93e7`): no veo el código en el iOS actual — ¿está en otro lado o es otra decisión pendiente?

## Cómo continuar

Por orden recomendado:

1. `flutter create --platforms=android,ios .` (generar carpetas nativas)
2. `flutter pub get`
3. `flutter run` y verificar:
   - El pet se anima en idle ✅
   - El joystick mueve al player ✅
   - El BuddyCutoutSpot aparece en la zona de la cámara ✅
   - Tocar al pet incrementa happiness ✅
4. Portar `StatsSheet` (la más simple) como "hello world" del patrón de sheets
5. Tomar decisión sobre backend → desbloquea `CloudSyncService` real
6. Portar minijuegos uno por uno
7. Implementar `LiveActivityService` iOS via platform channel
