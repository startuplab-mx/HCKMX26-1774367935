import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'features/overlay/buddy_overlay_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
  runApp(const BuddyApp());
}

@pragma('vm:entry-point')
void overlayPopUp() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BuddyOverlayApp());
}
