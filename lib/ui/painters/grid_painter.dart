import 'package:flutter/material.dart';

class GridPainter extends CustomPainter {
  final Color gridColor;
  final double gridSize;

  const GridPainter({
    required this.gridColor,
    this.gridSize = 30.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // Linhas verticais
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Linhas horizontais
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return oldDelegate.gridColor != gridColor || oldDelegate.gridSize != gridSize;
  }
}
