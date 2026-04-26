# Buddy — Tamagotchi moderno (iOS) con personajes famosos en pixel art

Juego iOS donde cuidas a un personaje famoso (Pokémon, Garfield, Mario, etc.) renderizado en pixel art. Tono tierno + nostálgico. Mecánicas hiperrealistas de cuidado (alimentar, agua, paseo, jugar, acariciar, dormir, higiene). Multi-cuidador (mascota compartida con amigos), evoluciones, mortalidad con reencarnación, monetización solo in-game.

> **Registro maestro de funcionalidades**: ver `~/.claude/projects/-Users-main-Documents-develop-flux/memory/project_buddy.md`. Es la fuente de verdad — consultar antes de proponer features.

## Estructura del repo

```
buddy/
├── buddy-ios/                            # App iOS (SwiftUI + SpriteKit híbrido)
│   ├── project.yml                       # xcodegen — regenera buddy.xcodeproj
│   ├── buddy.xcodeproj                   # generado, no editar a mano
│   └── Sources/buddy/
│       ├── App/                          # BuddyApp entry
│       ├── Models/                       # Pet, stats, personaje
│       ├── Game/                         # SKScene, sprites, animaciones
│       ├── Design/                       # Theme (colores, tipografía pixel)
│       ├── Features/Home/                # Pantalla principal (HUD + escena)
│       └── Resources/                    # Info.plist, fonts, assets
└── (futuro: backend para multi-cuidador / sync)
```

## Stack

- Swift 5, SwiftUI + **SpriteKit** (escena de la mascota vía `SpriteView`)
- iOS 17+ (Dynamic Island, Live Activities modernas)
- xcodegen para el `.xcodeproj` (no editar a mano)
- **Todos los sprites/escenarios/UI pixel art se hacen a mano** — no asset packs

## Comandos

```bash
cd buddy-ios && xcodegen generate    # regenerar proyecto tras editar project.yml o agregar archivos
open buddy-ios/buddy.xcodeproj       # abrir en Xcode → ⌘R
```

## Convenciones

- Git user: Emilio Cruz V. (`cruzemilio50@yahoo.com`). Commits en español.
- VStack siempre `.leading` salvo indicación contraria.
- `async/await` y `Combine` sobre callbacks.
- AR (si se usa más adelante): RealityKit, no Quick Look.
- Implementar **una funcionalidad a la vez**, no batchear features.

## Secretos

- Nunca commitear: `.env`, `xcuserstate`, archivos de firma, claves.
