import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OverlayPopUp {
  OverlayPopUp._();

  // Separate stream controllers for each direction
  static final StreamController _mainToOverlayController =
      StreamController.broadcast();
  static final StreamController _overlayToMainController =
      StreamController.broadcast();

  static const _methodChannel = MethodChannel('overlay_pop_up');
  static const _messageChannel = BasicMessageChannel(
    'overlay_pop_up_mssg',
    JSONMessageCodec(),
  );
  static const _overlayToMainChannel = BasicMessageChannel(
    'overlay_to_main_mssg',
    JSONMessageCodec(),
  );

  // Separate flags for each handler
  static bool _mainToOverlayHandlerInitialized = false;
  static bool _overlayToMainHandlerInitialized = false;

  ///
  /// Initialize ONLY the handler for receiving messages FROM overlay (Overlay → Main App)
  /// Call this ONLY from main app, NOT from overlay widget
  ///
  static void initializeMainAppHandler() {
    if (!_overlayToMainHandlerInitialized) {
      // Handler for Overlay → Main App messages
      _overlayToMainChannel.setMessageHandler((mssg) async {
        if (_overlayToMainController.isClosed) {
          debugPrint(
            '[OverlayPopUp] WARNING: StreamController is closed, cannot receive message',
          );
          return '';
        }

        // Add message to stream
        try {
          _overlayToMainController.add(mssg);
        } catch (e) {
          debugPrint('[OverlayPopUp] ERROR adding message to stream: $e');
        }
        return mssg;
      });

      _overlayToMainHandlerInitialized = true;
    }
  }

  ///
  /// Initialize ONLY the handler for receiving messages FROM main app (Main App → Overlay)
  /// Call this ONLY from overlay widget, NOT from main app
  ///
  static void initializeOverlayHandler() {
    if (!_mainToOverlayHandlerInitialized) {
      // Handler for Main App → Overlay messages
      _messageChannel.setMessageHandler((mssg) async {
        if (_mainToOverlayController.isClosed) return '';
        _mainToOverlayController.add(mssg);
        return mssg;
      });

      _mainToOverlayHandlerInitialized = true;
    }
  }

  ///
  /// DEPRECATED: Use initializeMainAppHandler() or initializeOverlayHandler() instead
  /// This is kept for backwards compatibility
  ///
  @Deprecated(
    'Use initializeMainAppHandler() in main app or initializeOverlayHandler() in overlay widget',
  )
  static void initializeMessageHandler() {
    // For backwards compatibility, initialize both
    initializeMainAppHandler();
    initializeOverlayHandler();
  }

  ///
  /// returns true when overlay permission is alreary granted
  /// if permission is not granted then open app settings
  ///
  static Future<bool> requestPermission() async {
    final result = await _methodChannel.invokeMethod<bool?>(
      'requestPermission',
    );
    return result ?? false;
  }

  ///
  /// returns true or false according to permission status
  ///
  static Future<bool> checkPermission() async {
    final result = await _methodChannel.invokeMethod<bool?>('checkPermission');
    return result ?? false;
  }

  ///
  /// display your overlay and return true if is showed
  /// [height] is not required by default is MATCH_PARENT
  /// [width] is not required by default is MATCH_PARENT
  /// [alignment] is not required by default is CENTER for more info see: https://developer.android.com/reference/android/view/WindowManager.LayoutParams
  /// [backgroundBehavior] by default is focusable flag that is you can take focus inside a overlay for example inside a textfield and [tapThrough] you can tap through the overlay background even if has MATCH_PARENT sizes.
  /// [screenOrientation] by default is portrait its param define the overlay orientation.
  /// [swipeToDismiss] by default is false, when enabled users can swipe down to dismiss the overlay (like YouTube PiP or Messenger).
  /// [notificationIcon] REQUIRED: The drawable resource name for the notification icon (e.g., "ic_notification", "ic_launcher"). Must be a valid drawable/mipmap resource in your app.
  /// [notificationTitle] Customize the notification title (Android 8+). Default: "Overlay Active"
  /// [notificationText] Customize the notification text (Android 8+). Default: empty string
  ///
  static Future<bool> showOverlay({
    int? height,
    int? width,
    int? offsetX,
    int? offsetY,
    Gravity? verticalAlignment,
    Gravity? horizontalAlignment,
    OverlayFlag? backgroundBehavior,
    ScreenOrientation? screenOrientation,
    bool? closeWhenTapBackButton = false,
    bool? isDraggable = false,
    bool? swipeToDismiss = false,
    String? entryPointMethodName,
    required String notificationIcon,
    String? notificationTitle,
    String? notificationText,
  }) async {
    final result = await _methodChannel.invokeMethod<bool?>('showOverlay', {
      /// is not required by default is MATCH_PARENT
      'height': height,

      /// is not required by default is MATCH_PARENT
      'width': width,

      /// pixel offset from the gravity anchor (native pixels)
      'offsetX': offsetX,
      'offsetY': offsetY,

      /// is not required by default is CENTER for more info see: https://developer.android.com/reference/android/view/Gravity
      'verticalAlignment': verticalAlignment?.value,

      /// is not required by default is CENTER for more info see: https://developer.android.com/reference/android/view/Gravity
      'horizontalAlignment': horizontalAlignment?.value,

      /// by default is focusable flag that is you can take focus inside a overlay for example inside a textfield and [tapThrough] you can tap through the overlay background even if has MATCH_PARENT sizes.
      'backgroundBehavior': backgroundBehavior?.value,

      /// by default is portrait its param define the overlay orientation.
      'screenOrientation': screenOrientation?.value,

      /// by default is false its param define if overlay will close when user tap back button.
      'closeWhenTapBackButton': closeWhenTapBackButton,

      /// by default is false therefore the overlay can´t be dragged.
      'isDraggable': isDraggable,

      /// by default is false, when enabled allows users to swipe down to dismiss the overlay with an animation.
      'swipeToDismiss': swipeToDismiss,

      /// by default `overlayPopUp`.
      'entryPointMethodName': entryPointMethodName,

      /// Notification icon drawable resource name (REQUIRED). Example: "ic_notification" or "ic_launcher"
      'notificationIcon': notificationIcon,

      /// Notification title shown while overlay is active (Android 8+). By default "Overlay Active".
      'notificationTitle': notificationTitle,

      /// Notification text shown while overlay is active (Android 8+). By default empty.
      'notificationText': notificationText,
    });
    return result ?? false;
  }

  ///
  /// returns true if overlay closed correctly or already is closed
  ///
  static Future<bool?> closeOverlay() async {
    final result = await _methodChannel.invokeMethod<bool?>('closeOverlay');
    return result;
  }

  ///
  /// returns the overlay status true = open, false = closed
  ///
  static Future<bool> isActive() async {
    final result = await _methodChannel.invokeMethod<bool?>('isActive');
    return result ?? false;
  }

  ///
  /// brings the host app's MainActivity to the foreground (Android only).
  /// useful when the user taps the overlay and wants to return to the app.
  ///
  static Future<bool> bringMainAppToFront() async {
    final result =
        await _methodChannel.invokeMethod<bool?>('bringMainAppToFront');
    return result ?? false;
  }

  ///
  /// returns the current overlay position if enable drag is enabled
  ///
  static Future<Map?> getOverlayPosition() async {
    final result = await _methodChannel.invokeMethod<Map?>(
      'getOverlayPosition',
    );
    return result;
  }

  ///
  /// update overlay layout size
  ///
  static Future<bool> updateOverlaySize({int? height, int? width}) async {
    final result = await _methodChannel.invokeMethod<bool?>(
      'updateOverlaySize',
      {
        /// the new value for layout height
        'height': height,

        /// the new value for layout width
        'width': width,
      },
    );
    return result ?? false;
  }

  ///
  /// share dynamic data to overlay (Main App → Overlay)
  ///
  static Future<void> sendToOverlay(dynamic data) async {
    await _messageChannel.send(data);
  }

  ///
  /// send data from overlay to main app (Overlay → Main App)
  /// This should be called from the overlay widget
  ///
  static Future<void> sendToMainApp(dynamic data) async {
    debugPrint('[OverlayPopUp] sendToMainApp called with: $data');
    await _overlayToMainChannel.send(data);
  }

  ///
  /// receive the data from overlay to main app
  /// IMPORTANT: Call initializeMainAppHandler() in your main app's main() before accessing this
  ///
  static Stream<dynamic>? get dataListener {
    if (_overlayToMainController.isClosed) return null;
    return _overlayToMainController.stream;
  }

  ///
  /// receive the data from main app to overlay (for use in overlay widget)
  /// IMPORTANT: Call initializeOverlayHandler() in your overlay widget's initState() before accessing this
  ///
  static Stream<dynamic>? get overlayDataListener {
    if (_mainToOverlayController.isClosed) return null;
    return _mainToOverlayController.stream;
  }

  ///
  /// drain and close data stream controllers
  ///
  static void stopDataLIstener() {
    try {
      _overlayToMainController.stream.drain();
      _overlayToMainController.close();
      _mainToOverlayController.stream.drain();
      _mainToOverlayController.close();
    } catch (e) {
      debugPrint(
        '[OverlayPopUp] Something went wrong when close overlay pop up: $e',
      );
    }
  }
}

enum Gravity {
  axisClip(8),
  axisPullAfter(4),
  axisPullBefore(2),
  axisSpecified(1),
  axisxShift(0),
  axisyShift(4),
  bottom(80),
  center(17),
  centerHorizontal(1),
  centerVertical(16),
  clipHorizontal(8),
  clipVertical(128),
  displayClipHorizontal(16777216),
  displayClipVertical(268435456),
  end(8388613),
  fill(119),
  fillHorizontal(7),
  fillVertical(112),
  horizontalGravityMask(7),
  left(3),
  noGravity(0),
  relativeHorizontalGravityMask(8388615),
  relativeLayoutDirection(8388608),
  right(5),
  start(8388611),
  top(48),
  verticalGravityMask(112);

  final int value;
  const Gravity(this.value);
}

enum OverlayFlag {
  focusable(1),
  tapThrough(0);

  final int value;
  const OverlayFlag(this.value);
}

enum ScreenOrientation {
  landscape(0),
  portrait(1);

  final int value;
  const ScreenOrientation(this.value);
}
