# Setup del overlay flotante (Android)

Este proyecto incluye una mascota flotante system-level que sobrevive cuando la app principal pasa a background — la "burbuja" se monta en el área del notch.

Como `android/` está en `.gitignore` (se regenera con `flutter create .`), después de clonar hay que **aplicar manualmente** los cambios del manifest y gradle. Esta guía los lista.

## 1. Generar plataformas y resolver dependencias

```bash
cd buddy-flutter
flutter pub get
flutter create --platforms=android,ios,macos .
```

`flutter pub get` ya respeta el `dependency_overrides` del `pubspec.yaml` para usar el plugin local en `local_plugins/overlay_pop_up/`.

## 2. AndroidManifest.xml

Edita `android/app/src/main/AndroidManifest.xml`. Justo dentro del `<manifest>` y arriba del `<application>` agrega los permisos:

```xml
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

Y dentro de `<application>` (al final, antes del `</application>`) declara el service:

```xml
<service
    android:name="com.requiemz.overlay_pop_up.OverlayService"
    android:exported="false"
    android:foregroundServiceType="specialUse">
    <property
        android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
        android:value="Mascota Buddy flotando sobre otras apps para el cuidador"/>
</service>
```

## 3. android/app/build.gradle.kts

`flutter_local_notifications` requiere "core library desugaring". Edita el bloque `android { ... }`:

```kotlin
android {
    // ...
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    // ...
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

## 4. Verificación

```bash
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell appops set com.example.buddy SYSTEM_ALERT_WINDOW allow
adb shell pm grant com.example.buddy android.permission.POST_NOTIFICATIONS
adb shell am start -n com.example.buddy/.MainActivity
```

En la app: pasa por StartScreen → HomeView → toca el botón **Notch** (esquina superior derecha) para soltar a la mascota.

## Archivos clave del feature

- [`lib/features/overlay/buddy_overlay_widget.dart`](lib/features/overlay/buddy_overlay_widget.dart) — widget del overlay (sprite animado)
- [`lib/features/overlay/overlay_controller.dart`](lib/features/overlay/overlay_controller.dart) — show/hide/toggle + permisos
- [`lib/main.dart`](lib/main.dart) — `overlayPopUp` entry point con `@pragma('vm:entry-point')`
- [`lib/features/home/home_view.dart`](lib/features/home/home_view.dart) — `_NotchButton.onTap` → `_toggleOverlay()`
- [`local_plugins/overlay_pop_up/`](local_plugins/overlay_pop_up/) — fork con `LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS`, `FLAG_LAYOUT_NO_LIMITS` y soporte para `offsetX`/`offsetY`

## Calibración por dispositivo

El overlay actualmente se centra horizontalmente con gravity. Para colocarlo pixel-perfect sobre el punch-hole de un dispositivo específico, usa `offsetX` y `offsetY` (en pixels nativos) en `OverlayPopUp.showOverlay`:

```dart
// Pixel 8: notch en (576, 65.75) px nativos. Centro pantalla en x=540.
await OverlayPopUp.showOverlay(
  width: 80, height: 80,
  offsetX: 36, // +36 px → centro overlay en x=576
  offsetY: 26, // top en y=26 → centro en y=66
  verticalAlignment: Gravity.top,
  horizontalAlignment: Gravity.centerHorizontal,
  // ...
);
```

Para conocer la posición del cutout en otro dispositivo:

```bash
adb shell dumpsys display | grep -i cutout
```

Busca `boundingRect=...` y `cutoutSpec=m X,Y a R,R ...` para extraer el centro y radio del punch-hole.
