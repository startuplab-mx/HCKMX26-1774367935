import 'package:flutter/material.dart';

class BuddyTheme {
  static const consoleBG       = Color(0xFFEFE6D6);
  static const buttonBG        = Color(0xFFF8F0D8);
  static const buttonStroke    = Color(0xFFA8946C);
  static const lcdOuter        = Color(0xFFC8D4B0);
  static const lcdInner        = Color(0xFFD8E0C0);
  static const lcdStroke       = Color(0xFF7C8B68);
  static const lcdInk          = Color(0xFF3C4A28);
  static const actionPink      = Color(0xFFB0457A);
  static const actionPinkDark  = Color(0xFF7A2C55);
  static const darkInk         = Color(0xFF3C2C1C);
  static const heartRed        = Color(0xFFE04848);

  static const pixelMono = 'Pix3M';

  static TextStyle pixel({double size = 14, FontWeight weight = FontWeight.normal, Color color = darkInk}) {
    return TextStyle(
      fontFamily: pixelMono,
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }
}
