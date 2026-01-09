import 'package:flutter/cupertino.dart';
import 'dart:math' as math;

class NavIcons {
  static const double strokeWidth = 1.5; // Fine stroke

  static Widget home({required bool isSelected, required Color color}) {
    return CustomPaint(
      size: const Size(26, 26),
      painter: _HomePainter(color: color, isFilled: isSelected),
    );
  }

  static Widget settings({required bool isSelected, required Color color}) {
    return CustomPaint(
      size: const Size(26, 26),
      painter: _SettingsPainter(color: color, isFilled: isSelected),
    );
  }

  static Widget profile({required bool isSelected, required Color color}) {
    return CustomPaint(
      size: const Size(26, 26),
      painter: _ProfilePainter(color: color, isFilled: isSelected),
    );
  }
}

class _HomePainter extends CustomPainter {
  final Color color;
  final bool isFilled;

  _HomePainter({required this.color, required this.isFilled});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = isFilled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = NavIcons.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // "Square but with triangle on top"
    final path = Path();

    // Roof tip
    path.moveTo(w * 0.5, h * 0.1);
    // Roof left
    path.lineTo(w * 0.15, h * 0.4);
    // Box left top
    path.lineTo(w * 0.15, h * 0.4);
    // Box left bottom
    path.lineTo(w * 0.15, h * 0.9);
    // Box right bottom
    path.lineTo(w * 0.85, h * 0.9);
    // Box right top
    path.lineTo(w * 0.85, h * 0.4);
    // Roof right
    path.lineTo(w * 0.85, h * 0.4);
    // Back to tip
    path.close();

    // To make it look like the photo (seamless house), the above path is good.
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _SettingsPainter extends CustomPainter {
  final Color color;
  final bool isFilled;

  _SettingsPainter({required this.color, required this.isFilled});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = isFilled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = NavIcons.strokeWidth
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.45;

    // Minimalist Settings: A Hexagon or Octagon usually serves as a "Solid Gear"
    // Photo style usually implies solid geometric shapes.

    if (isFilled) {
      // Solid Gear
      final path = Path();
      final int teeth = 8;
      final double outerR = radius;
      final double innerR = radius * 0.75;

      for (int i = 0; i < teeth * 2; i++) {
        double angle = (math.pi * 2 * i) / (teeth * 2);
        double r = (i % 2 == 0) ? outerR : innerR;
        double x = center.dx + r * math.cos(angle);
        double y = center.dy + r * math.sin(angle);
        if (i == 0)
          path.moveTo(x, y);
        else
          path.lineTo(x, y);
      }
      path.close();

      // Center hole
      path.addOval(Rect.fromCircle(center: center, radius: radius * 0.3));
      path.fillType = PathFillType.evenOdd;

      canvas.drawPath(path, paint);
    } else {
      // Stroke Gear
      canvas.drawCircle(center, radius * 0.7, paint);
      // Add some spokes
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ProfilePainter extends CustomPainter {
  final Color color;
  final bool isFilled;

  _ProfilePainter({required this.color, required this.isFilled});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = isFilled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = NavIcons.strokeWidth;

    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    // Head
    final headRadius = w * 0.18;
    final headCenter = Offset(w * 0.5, h * 0.38);

    // Body (Shoulders)
    final bodyRect = Rect.fromLTWH(w * 0.2, h * 0.6, w * 0.6, h * 0.4);

    // Person Path
    final personPath = Path();
    personPath.addOval(Rect.fromCircle(center: headCenter, radius: headRadius));
    personPath.addArc(bodyRect, 3.14159, 3.14159);
    personPath.close();

    if (isFilled) {
      // Circle container
      final circlePath = Path()..addOval(Rect.fromLTWH(0, 0, w, h));

      // Subtract person from circle
      final finalPath = Path.combine(
        PathOperation.difference,
        circlePath,
        personPath,
      );
      canvas.drawPath(finalPath, paint);
    } else {
      // Just the person outline
      paint.style = PaintingStyle.stroke;
      canvas.drawPath(personPath, paint);
      // And the circle outline? The photo shows circle with person.
      // Minimalist often drops the circle for outline.
      // But user said "like photo" which is Circle.
      canvas.drawCircle(center, w / 2 - 1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
