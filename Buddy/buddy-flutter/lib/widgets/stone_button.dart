import 'package:flutter/material.dart';
import '../design/theme.dart';

class StoneButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const StoneButton({super.key, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 240,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF9E9E9E), // Stone base
          border: const Border(
            top: BorderSide(color: Color(0xFFE0E0E0), width: 4),
            left: BorderSide(color: Color(0xFFE0E0E0), width: 4),
            right: BorderSide(color: Color(0xFF616161), width: 4),
            bottom: BorderSide(color: Color(0xFF424242), width: 4),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black87,
              offset: Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(painter: StoneTexturePainter()),
            ),
            Text(
              text,
              style: BuddyTheme.pixel(
                size: 20,
                color: Colors.black,
                weight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StoneTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintDark = Paint()..color = const Color(0xFF757575);
    final paintLight = Paint()..color = const Color(0xFFBDBDBD);
    const pixelSize = 4.0;

    for (int i = 0; i < size.width; i += 8) {
      for (int j = 0; j < size.height; j += 8) {
        if ((i * 3 + j * 7) % 17 == 0) {
          canvas.drawRect(Rect.fromLTWH(i.toDouble(), j.toDouble(), pixelSize, pixelSize), paintDark);
        } else if ((i * 5 + j * 11) % 23 == 0) {
          canvas.drawRect(Rect.fromLTWH(i.toDouble(), j.toDouble(), pixelSize, pixelSize), paintLight);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
