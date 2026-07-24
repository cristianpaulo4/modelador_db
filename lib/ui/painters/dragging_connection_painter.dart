import 'package:flutter/material.dart';

class DraggingConnectionPainter extends CustomPainter {
  final Offset startPoint;
  final Offset endPoint;
  final Color lineColor;

  const DraggingConnectionPainter({
    required this.startPoint,
    required this.endPoint,
    this.lineColor = Colors.amber,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(startPoint.dx, startPoint.dy);

    final dx = (endPoint.dx - startPoint.dx).abs() * 0.5;
    final controlPoint1 = Offset(startPoint.dx + (endPoint.dx > startPoint.dx ? dx : -dx), startPoint.dy);
    final controlPoint2 = Offset(endPoint.dx + (endPoint.dx > startPoint.dx ? -dx : dx), endPoint.dy);

    path.cubicTo(
      controlPoint1.dx,
      controlPoint1.dy,
      controlPoint2.dx,
      controlPoint2.dy,
      endPoint.dx,
      endPoint.dy,
    );

    canvas.drawPath(path, paint);

    // Desenhar ponto de destino (alvo)
    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(endPoint, 6, dotPaint);

    final outerDotPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(endPoint, 10, outerDotPaint);
  }

  @override
  bool shouldRepaint(covariant DraggingConnectionPainter oldDelegate) {
    return oldDelegate.startPoint != startPoint ||
        oldDelegate.endPoint != endPoint ||
        oldDelegate.lineColor != lineColor;
  }
}
