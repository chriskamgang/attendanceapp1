import 'package:flutter/material.dart';

/// Le « G » de Google, dessiné localement pour éviter un asset réseau.
/// Quatre arcs quadrichromes autour d'une barre horizontale.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  static const Color _blue = Color(0xFF4285F4);
  static const Color _green = Color(0xFF34A853);
  static const Color _yellow = Color(0xFFFBBC05);
  static const Color _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.23;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Arcs, en partant de la droite et en tournant dans le sens horaire.
    canvas.drawArc(rect, -0.35, 1.0, false, paint..color = _green);
    canvas.drawArc(rect, 0.65, 1.3, false, paint..color = _yellow);
    canvas.drawArc(rect, 1.95, 1.75, false, paint..color = _red);
    canvas.drawArc(rect, 3.70, 1.75, false, paint..color = _blue);

    // Barre horizontale du « G », jusqu'au centre.
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.5,
        size.height * 0.5 - stroke / 2,
        size.width * 0.5 - stroke / 2,
        stroke,
      ),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
