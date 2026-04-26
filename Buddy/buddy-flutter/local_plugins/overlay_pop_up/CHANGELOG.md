## 1.0.6+6

### 🎉 Major Improvement

+ **Automatic Android 12+ background service handling** - The plugin now automatically handles background service start restrictions on Android 12+!
+ **No more manual state management needed** - You can now call `showOverlay()` anytime, even when the app is in background
+ **Transparent launcher activity** - Uses a transparent Activity to briefly bring the app to foreground when needed, then immediately closes

### How it works

When you call `showOverlay()` on Android 12+ while your app is in background, the plugin will:
1. Detect that the app is in background
2. Launch a transparent Activity (invisible to the user)
3. Start the overlay service from the Activity
4. Close the Activity immediately
5. The overlay remains visible

This happens so fast that users won't notice any interruption - the overlay simply appears!

### Bug Fixes

+ **Fixed Android 12+ background service start crash** - No more `BackgroundServiceStartNotAllowedException`
+ **Better foreground detection** - Enhanced app foreground state detection using ActivityManager
+ **Improved error handling** - Better fallback mechanisms when service start fails

### Changes

+ Added `OverlayLauncherActivity` for background service starts on Android 12+
+ Added automatic foreground state detection
+ Improved error messages and logging for debugging
+ No breaking changes - works transparently for all users!

## 1.0.6+5

### ⚠️ Breaking Changes

**`notificationIcon` parameter is now REQUIRED in `showOverlay()`:**

You must now provide a notification icon resource name when calling `showOverlay()`. This ensures the correct icon is displayed in the foreground service notification.

```dart
await OverlayPopUp.showOverlay(
  notificationIcon: "ic_launcher", // REQUIRED: your app's icon
  notificationTitle: "My App",
  // ... other parameters
);
```

### Bug Fixes

+ **Fixed incorrect notification icon** - The notification now correctly uses the icon specified by your app instead of the plugin's icon
+ **Fixed notification text display** - `notificationText` now defaults to empty (no description shown) when not provided, instead of showing a default message

### Changes

+ `notificationIcon` parameter is now required (breaking change)
+ `notificationText` parameter now defaults to empty string instead of "Overlay is running"
+ Added better error logging when notification icon is not found

## 1.0.6+4

### ⚠️ Action Required

**1. Add these permissions to your AndroidManifest.xml:**

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

Without these permissions, the overlay will crash when starting from background on Android 8+.

**2. Request notification permission at runtime (Android 13+):**

For the foreground service notification to be visible on Android 13+, you must request the `POST_NOTIFICATIONS` permission at runtime using `permission_handler` or similar package:

```dart
import 'package:permission_handler/permission_handler.dart';

await Permission.notification.request();
```

See README for complete setup instructions and code examples.

### Critical Bug Fixes

+ **Fixed `Not allowed to start service: app is in background` error on Android 8.0+**
  - Implemented foreground service to comply with Android background service restrictions
  - Added low-priority notification while overlay is active (required by Android O+)

+ **Fixed critical `InputChannel is not initialized` crash on overlay service initialization**

+ **Enhanced stability with improved race condition handling for view removal operations**

### New Features

+ **Customizable notification** - New parameters `notificationTitle` and `notificationText` allow you to customize the foreground service notification
+ **Automatic app icon** - The notification now uses your app's icon automatically instead of a generic Android icon

### Improvements

+ Service declaration is now handled automatically by the plugin - you no longer need to manually declare the service in your AndroidManifest.xml (old declarations still work)

## 1.0.6+3

### Bug Fixes

+ Fixed `IllegalArgumentException: View not attached to window manager` crash that occurred when:
  - Removing overlay views during dismiss animation
  - Pressing back button to close overlay
  - Service was destroyed while views were being removed
+ Added `isAttachedToWindow` checks before all `removeView()` calls to prevent attempting to remove views that are already detached

## 1.0.6+2

### Bug Fixes

+ Fixed crash when service is stopped before flutterView initialization (lateinit property not initialized error)

## 1.0.6+1

### Drag-to-Dismiss with Drop Zone

+ Added drag-to-dismiss feature with drop zone - users can now drag the overlay to a trash icon zone to close it
+ Drop zone appears at the bottom center of the screen when dragging starts (when `swipeToDismiss` is enabled)

### Bidirectional Messaging

+ **BREAKING CHANGE**: `dataListener` now receives messages FROM overlay TO main app (was previously for main → overlay)
+ Added `overlayDataListener` to receive messages FROM main app TO overlay widget (use this in your overlay widget's StreamBuilder)
+ Added `sendToMainApp()` method to send messages from overlay to main app
+ `sendToOverlay()` continues to send messages from main app to overlay
+ Implemented separate message channels for each direction to prevent conflicts between main app and overlay engines
+ Added `initializeMessageHandler()` for early initialization of message handlers

## 1.0.5+2

+ Fixed null pointer error in the first pop up initialization

## 1.0.5+1

+ was fixed simultaneously request permission

## 1.0.5

+ Added entryPointMethodName param in showOverlayMethod

## 1.0.4

+ Fixed overlay permission request

## 1.0.3

+ Added capability to show overlay when main app is closed (context is null)

## 1.0.2

+ Fix 1.0.1 version error when showing overlay pop up. was added new param to handle the entryPoint method name in showOverlay method.

## 1.0.0

+ added android 14 espcifications and update readme example.

## 0.0.9

+ add screen limits to drag pop up to prevet future bugs

## 0.0.8

+ now remeber the last overlay position, will be re-open in the last drag position

## 0.0.7

+ added method to close overlay data listener

## 0.0.6

+ now you can get the last overlay position

## 0.0.5

+ now the overlay can be dragged

## 0.0.4

+ fix some bugs

## 0.0.3

+ Added update overlay size method when overlay is displayed and added close when user tap in back button as new param `closeWhenTapBackButton` and added support for horizontal and vertical alignment

## 0.0.2

+ Added overlay orientation as new param `screenOrientation`

## 0.0.1

+ Initial release
