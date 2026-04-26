# overlay_pop_up

A new Flutter plugin to display pop ups or screens over other apps in Android even when app is closed or killed.

<a href="https://www.buymeacoffee.com/requiemz" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" width="195" height="55"></a>

# Demo

[![Preview](https://github.com/diegohzea/diegohzea/raw/main/overlay_pop_up_demo.gif)](https://github.com/diegohzea/diegohzea/raw/main/overlay_pop_up_demo.gif)

## Android Setup

### Required Permissions

Add these permissions to your `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

### Service Declaration

**Note:** Starting from version 1.0.6+4, the plugin automatically handles the service declaration. You no longer need to manually add the service to your `AndroidManifest.xml` as it's now included in the plugin's manifest and will be merged automatically.

If you were using an older version and had manually declared the service, you can safely remove it from your app's manifest.

### Android 14+ (API 34+)

The plugin automatically uses `foregroundServiceType="specialUse"` which is appropriate for overlay services. No additional configuration is needed for Android 14+.

### Important: Notification Permission (Android 13+)

Starting from Android 13 (API 33), you must request the `POST_NOTIFICATIONS` permission at runtime for the foreground service notification to be visible.

**Add permission_handler to your pubspec.yaml:**

```yaml
dependencies:
  permission_handler: ^11.3.1
```

**Request the permission in your app:**

```dart
import 'package:permission_handler/permission_handler.dart';

// Request notification permission (Android 13+)
Future<void> requestNotificationPermission() async {
  final status = await Permission.notification.request();
  if (status.isGranted) {
    print('Notification permission granted');
  }
}

// Call this when your app starts or before showing the overlay
@override
void initState() {
  super.initState();
  requestNotificationPermission();
}
```

**Note:** Without granting this permission on Android 13+, the foreground service notification will not be visible (though the overlay will still work). The notification uses low priority and won't make sound or vibrate.

### Android 12+ Background Service Support

Starting from version **1.0.6+6**, this plugin **automatically handles** Android 12+ background service restrictions!

**You can now call `showOverlay()` anytime** - even when your app is in the background. The plugin will:
- Detect if the app is in background on Android 12+
- Automatically launch a transparent Activity to bring the app briefly to foreground
- Start the overlay service
- Close the transparent Activity immediately
- The overlay remains visible

This all happens in milliseconds - users won't notice any interruption!

**Example - Call from any app state:**
```dart
// This works even when app is in background on Android 12+!
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.paused) {
    // Show floating button when app goes to background
    OverlayPopUp.showOverlay(
      notificationIcon: 'ic_launcher',
      notificationTitle: 'Overlay Active',
      width: 200,
      height: 200,
      isDraggable: true,
    );
  }
}
```

## Flutter implementation

configure your main.dart entry point a widget to display (make sure to add @pragma('vm:entry-point'))

**NOTE:**
Now you can pass as parameter the dart entry point method name when showOverlay is called

```dart
@pragma("vm:entry-point")
void overlayPopUp() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Text('Hello Pub.dev!'),
  ));
}
```

## Overlay Methods

  returns true when overlay permission is alreary granted if permission is not granted then open app settings

  ```dart
  await OverlayPopUp.requestPermission();
  ```

  returns true or false according to permission status

  ```dart
  await OverlayPopUp.checkPermission();
  ```

  display your overlay and return true if is showed

*PARAMS*

- `height` is not required by default is MATCH_PARENT
- `width` is not required by default is MATCH_PARENT
- `verticalAlignment` is not required by default is CENTER for more info see: <https://developer.android.com/reference/android/view/Gravity>
- `horizontalAlignment` is not required by default is CENTER for more info see: <https://developer.android.com/reference/android/view/Gravity>
- `backgroundBehavior` by default is focusable flag that is you can take focus inside a overlay for example inside a textfield and [tapThrough] you can tap through the overlay background even if has MATCH_PARENT sizes.
- `screenOrientation` by default orientation is portrait.
- `closeWhenTapBackButton` by default when user presses back button the overlay no has any action if you pass true then back button will close overlay.
- `isDraggable`  by default is false therefore the overlay can´t be dragged.
- `swipeToDismiss` by default is false. When enabled, users can drag the overlay to a drop zone (trash icon) at the bottom of the screen to dismiss it. Features include:
  - Drop zone with trash icon appears when dragging starts
  - Overlay shrinks when entering drop zone area
  - Pulse animation on drop zone when overlay is nearby
  - Smooth dismiss animation when released in drop zone
  - Works together with `isDraggable` for free movement in all directions
- `entryPointMethodName` by default is 'overlayPopUp' if you want you can change it
- `notificationIcon` **REQUIRED** - The drawable resource name for the notification icon (e.g., "ic_launcher", "ic_notification"). This must be a valid drawable or mipmap resource in your app.
- `notificationTitle` customize the foreground service notification title (Android 8+). By default "Overlay Active"
- `notificationText` customize the foreground service notification text (Android 8+). By default empty (no description will be shown)

**Important:** You must provide a notification icon. The plugin will search for the icon name in both `drawable` and `mipmap` folders. Common options:
- `"ic_launcher"` - Your app's launcher icon
- `"ic_notification"` - A custom notification icon (recommended for Android)

  ```dart
  await OverlayPopUp.showOverlay(
    width: 300,
    height: 350,
    isDraggable: true,
    swipeToDismiss: true, // Enable swipe to dismiss
    notificationIcon: "ic_launcher", // REQUIRED: Your notification icon
    notificationTitle: "My App Overlay", // Optional: customize notification title
    notificationText: "Tap to return to app", // Optional: customize notification description
  );
  ```

  returns true if overlay closed correctly or already is closed

  ```dart
  await OverlayPopUp.closeOverlay();
  ```

  returns the overlay status true = open, false = closed

  ```dart
  await OverlayPopUp.isActive();
  ```

  returns the last overlay position if drag is enabled

  ```dart
  await OverlayPopUp.getOverlayPosition();
  ```

## Bidirectional Messaging

### Send Data from Main App to Overlay

  ```dart
  // From main app - send to overlay
  await OverlayPopUp.sendToOverlay({'data': 'hello from main app!'});
  await OverlayPopUp.sendToOverlay('hello');
  ```

### Send Data from Overlay to Main App

  ```dart
  // From overlay widget - send to main app
  await OverlayPopUp.sendToMainApp({'from': 'overlay', 'message': 'Hello!'});
  ```

### Receive Data in Main App (from Overlay)

  ```dart
  // In your main app - listen for messages FROM overlay
  StreamSubscription? listener;

  @override
  void initState() {
    super.initState();
    // Initialize message handler early
    OverlayPopUp.initializeMessageHandler();

    // Listen for messages from overlay
    listener = OverlayPopUp.dataListener?.listen((data) {
      print('Received from overlay: $data');
    });
  }

  @override
  void dispose() {
    listener?.cancel();
    super.dispose();
  }
  ```

### Receive Data in Overlay Widget (from Main App)

  ```dart
  // In your overlay widget - listen for messages FROM main app
  StreamBuilder(
    stream: OverlayPopUp.overlayDataListener,  // Use overlayDataListener here!
    builder: (context, snapshot) {
      return Text(snapshot.data?['message'] ?? 'No data');
    },
  )
  ```

### Summary

| Location | Send Method | Receive Stream |
|----------|-------------|----------------|
| **Main App** | `sendToOverlay()` | `dataListener` (receives from overlay) |
| **Overlay Widget** | `sendToMainApp()` | `overlayDataListener` (receives from main app) |
