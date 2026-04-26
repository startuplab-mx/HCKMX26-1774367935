# Instalación en Windows · Buddy (Flutter)

Guía paso a paso para clonar el repo y correr Buddy desde una máquina con Windows 10 / 11. Tiempo estimado: **40–60 min** (la mayoría es descarga del SDK + Android Studio).

## 0 · Requisitos previos

| Componente            | Versión mínima | Para qué                         |
|-----------------------|----------------|----------------------------------|
| Windows               | 10 (build 1903) o 11 | Compatible con Flutter SDK |
| Espacio en disco      | ~25 GB         | SDK + Android Studio + emuladores |
| RAM                   | 8 GB (16 GB recomendado) | Emulador Android es pesado |
| Git                   | 2.27+          | Clonar el repo                   |
| PowerShell            | 5.0+           | Ejecutar comandos                |

## 1 · Instalar Git

1. Descarga desde https://git-scm.com/download/win
2. Ejecuta el instalador. Acepta los defaults.
3. Verifica:
   ```powershell
   git --version
   ```

## 2 · Instalar Flutter SDK

Flutter es **un solo binario**. No hay instalador.

1. Descarga el zip estable: https://docs.flutter.dev/get-started/install/windows
2. Extrae a `C:\src\flutter` (evita rutas con espacios y con permisos elevados como `Program Files`).
3. Añade `C:\src\flutter\bin` al `PATH`:
   - `Win + S` → "variables de entorno" → "Editar variables de entorno del sistema"
   - "Variables de entorno…" → en "Variables de usuario" selecciona `Path` → "Editar" → "Nuevo" → pega `C:\src\flutter\bin`
   - OK en todas las ventanas. Cierra y vuelve a abrir PowerShell.
4. Verifica:
   ```powershell
   flutter --version
   ```
   Debe imprimir versión del SDK + canal estable.

## 3 · Aceptar licencias y diagnosticar

```powershell
flutter doctor
```

Te va a listar los componentes que faltan. Repite los pasos hasta que `flutter doctor` muestre todo en verde (excepto `Connected device`, que requiere un emulador o teléfono):

```
[√] Flutter
[√] Windows Version
[√] Android toolchain - develop for Android devices
[√] Chrome - develop for the web   (opcional)
[√] Visual Studio - develop Windows apps   (opcional)
[√] Android Studio
[√] VS Code
```

## 4 · Instalar Android Studio (necesario para Android)

1. Descarga desde https://developer.android.com/studio
2. Ejecuta el instalador. En el "Setup Wizard" instala:
   - Android SDK
   - Android SDK Platform-Tools
   - Android Virtual Device (AVD)
3. Abre Android Studio una vez para que termine la primera configuración.
4. **Acepta las licencias del SDK**:
   ```powershell
   flutter doctor --android-licenses
   ```
   Acepta todo con `y`.

### Crear un emulador

1. Android Studio → barra superior → "Device Manager" (icono de teléfono)
2. "Create Device" → elige `Pixel 7` o similar (con notch / punch-hole para probar el `BuddyCutoutSpot`)
3. System image → "API 34" (Android 14). Descarga si no la tienes.
4. Finish → arranca el emulador con el play.

### O usar un teléfono físico

1. En el teléfono Android: **Ajustes → Acerca del teléfono → toca "Número de compilación" 7 veces** (activa modo desarrollador).
2. **Ajustes → Opciones de desarrollador → Activar "Depuración USB"**.
3. Conecta por USB → acepta la huella digital del PC.
4. Verifica:
   ```powershell
   flutter devices
   ```
   Debe aparecer tu teléfono.

## 5 · Instalar VS Code (recomendado, opcional)

1. https://code.visualstudio.com/
2. Extensiones a instalar:
   - **Flutter** (Dart-Code.flutter) — se instala automáticamente Dart con ella
3. Reinicia VS Code.

## 6 · Clonar el repo

```powershell
cd C:\
mkdir dev
cd dev
git clone <URL_DEL_REPO_BUDDY> buddy
cd buddy
git checkout feature/flutter-migration
```

## 7 · Generar carpetas nativas (Android / iOS)

El repo **no commitea** las carpetas `android/` ni `ios/` porque las regenera Flutter. Desde la raíz del proyecto Flutter:

```powershell
cd C:\dev\buddy\buddy-flutter
flutter create --org com.emiliocruz --platforms=android,ios .
```

Flutter detecta el `pubspec.yaml` existente y solo añade lo que falta. **No sobrescribe** tu `lib/`.

> En Windows no puedes compilar para iOS (requiere macOS + Xcode). Es esperado — el Mac de Emilio compila iOS, Windows compila Android.

## 8 · Descargar dependencias y correr

```powershell
flutter pub get
flutter run
```

`flutter run` te muestra los devices disponibles. Si tienes el emulador abierto y un teléfono conectado, te pregunta cuál usar.

Hot reload: `r` en la consola. Hot restart: `R`. Quit: `q`.

## 9 · Verificar el "BuddyCutoutSpot"

El widget que aprovecha la zona del notch / punch-hole solo se ve bien en devices que **tienen** notch/cámara central. En el emulador:

1. Configura un Pixel 7+ (tiene punch-hole central).
2. O abre el emulador y activa "Display cutout" desde **Extended Controls → Settings → Show display cutout**.

En tu pantalla, justo debajo de la cámara, debe aparecer una pill negra con `🐱 BuddyName · 🟢 · 🍖`. Esa es la equivalencia Android del Dynamic Island.

## 10 · Build de producción

Para generar APK firmado:

```powershell
flutter build apk --release
```

El APK queda en `build\app\outputs\flutter-apk\app-release.apk`. Para subir a Play Store usa `flutter build appbundle`.

---

## Troubleshooting común

| Síntoma | Solución |
|---|---|
| `flutter doctor` dice "Android licenses status unknown" | `flutter doctor --android-licenses` y aceptar todas |
| `flutter run` falla con "No connected devices" | Verifica con `flutter devices`. Si no aparece, revisa que el emulador esté corriendo o que la depuración USB esté activa |
| Error "CMake not found" o NDK | Android Studio → SDK Manager → SDK Tools → marca "NDK" y "CMake" → Apply |
| Emulador muy lento | En BIOS habilita Intel VT-x / AMD-V. En Windows: "Características de Windows" → activa "Plataforma de máquina virtual" y "Hyper-V" |
| `flutter pub get` falla con timeout | Cambia el mirror: `set PUB_HOSTED_URL=https://pub.flutter-io.cn` (China mirror) o usa una VPN |
| El widget `BuddyCutoutSpot` no se ve | Solo aparece en devices con notch/punch-hole. Activa "Display cutout" en Extended Controls del emulador |

## Próximos pasos

Una vez que la app corre, lee [`MIGRATION_STATUS.md`](MIGRATION_STATUS.md) para saber qué está portado y qué falta.
