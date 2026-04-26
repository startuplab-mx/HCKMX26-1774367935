import 'package:overlay_pop_up/overlay_pop_up.dart';

class BuddyOverlayController {
  BuddyOverlayController._();
  static final BuddyOverlayController instance = BuddyOverlayController._();

  // Overlay limitado al área cercana al notch (~190 dp = 500 px nativos),
  // centrado sobre el punch-hole del Pixel 8 (offsetX=+36 px desde el centro).
  // Altura ampliada a ~76 dp (200 px) para dar espacio a los globos de texto
  // que aparecen debajo del sprite. La mascota sigue paseando solo en los
  // primeros 50 dp (el status bar).
  static const int _overlayWidthPx = 500;
  static const int _overlayHeightPx = 200;
  static const int _offsetXpx = 36;
  static const int _offsetYpx = 0;

  Future<bool> ensurePermission() async {
    if (await OverlayPopUp.checkPermission()) return true;
    return await OverlayPopUp.requestPermission();
  }

  Future<bool> isVisible() => OverlayPopUp.isActive();

  Future<void> show({String? sprite}) async {
    if (!await ensurePermission()) return;
    if (await OverlayPopUp.isActive()) {
      if (sprite != null) {
        await OverlayPopUp.sendToOverlay({'sprite': sprite});
      }
      return;
    }
    await OverlayPopUp.showOverlay(
      notificationIcon: 'ic_launcher',
      notificationTitle: 'Buddy',
      notificationText: 'Tu mascota te acompaña',
      width: _overlayWidthPx,
      height: _overlayHeightPx,
      offsetX: _offsetXpx,
      offsetY: _offsetYpx,
      verticalAlignment: Gravity.top,
      horizontalAlignment: Gravity.centerHorizontal,
      backgroundBehavior: OverlayFlag.focusable,
      isDraggable: false,
      closeWhenTapBackButton: false,
      entryPointMethodName: 'overlayPopUp',
    );
    if (sprite != null) {
      await OverlayPopUp.sendToOverlay({'sprite': sprite});
    }
  }

  Future<void> hide() async {
    await OverlayPopUp.closeOverlay();
  }

  Future<void> toggle({String? sprite}) async {
    if (await OverlayPopUp.isActive()) {
      await hide();
    } else {
      await show(sprite: sprite);
    }
  }
}
