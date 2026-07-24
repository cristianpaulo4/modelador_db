import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/utils/geometry_utils.dart';
import '../../data/models/relationship_model.dart';

class OrthogonalConnectionPainter extends CustomPainter {
  final List<RelationshipModel> relationships;
  final Map<String, Rect> tableRects;
  final String? selectedRelationshipId;
  final Color lineColor;
  final Color selectedLineColor;
  final Color textColor;

  OrthogonalConnectionPainter({
    required this.relationships,
    required this.tableRects,
    this.selectedRelationshipId,
    required this.lineColor,
    required this.selectedLineColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sortedRels = List<RelationshipModel>.from(relationships);
    if (selectedRelationshipId != null) {
      sortedRels.sort((a, b) {
        if (a.id == selectedRelationshipId) return 1;
        if (b.id == selectedRelationshipId) return -1;
        return 0;
      });
    }

    for (final rel in sortedRels) {
      final sourceRect = tableRects[rel.sourceTableId];
      final targetRect = tableRects[rel.targetTableId];

      if (sourceRect == null || targetRect == null) continue;

      final isSelected = rel.id == selectedRelationshipId;
      final currentLineColor = isSelected ? selectedLineColor : lineColor;

      final (sourceAnchor, targetAnchor) = GeometryUtils.getBestAnchorPair(
        sourceRect,
        targetRect,
      );
      final rawPathPoints = GeometryUtils.calculateOrthogonalPath(
        sourceAnchor,
        targetAnchor,
      );

      _drawOrthogonalBezierPath(
        canvas,
        rawPathPoints,
        currentLineColor,
        isSelected,
      );
      _drawCardinalityBadges(
        canvas,
        rawPathPoints,
        rel.cardinality,
        currentLineColor,
        textColor,
      );
    }
  }

  void _drawOrthogonalBezierPath(
    Canvas canvas,
    List<Offset> points,
    Color color,
    bool isSelected,
  ) {
    if (points.length < 2) return;

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    const cornerRadius = 12.0;

    for (int i = 1; i < points.length - 1; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];

      final v1 = p1 - p0;
      final v2 = p2 - p1;

      final len1 = v1.distance;
      final len2 = v2.distance;

      final radius = math.min(cornerRadius, math.min(len1 / 2, len2 / 2));

      if (radius < 1.0) {
        path.lineTo(p1.dx, p1.dy);
      } else {
        final startCorner = p1 - (v1 / len1) * radius;
        final endCorner = p1 + (v2 / len2) * radius;

        path.lineTo(startCorner.dx, startCorner.dy);
        path.quadraticBezierTo(p1.dx, p1.dy, endCorner.dx, endCorner.dy);
      }
    }

    path.lineTo(points.last.dx, points.last.dy);

    if (isSelected) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..strokeWidth = 7.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, glowPaint);
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = isSelected ? 3.5 : 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  void _drawCardinalityBadges(
    Canvas canvas,
    List<Offset> points,
    CardinalityType cardinality,
    Color color,
    Color txtColor,
  ) {
    if (points.length < 2) return;

    final pStart = points.first;
    final pEnd = points.last;

    String sourceText = 'N';
    String targetText = '1';

    if (cardinality == CardinalityType.oneToOne) {
      sourceText = '1';
      targetText = '1';
    } else if (cardinality == CardinalityType.oneToMany) {
      sourceText = '1';
      targetText = 'N';
    } else if (cardinality == CardinalityType.manyToOne) {
      sourceText = 'N';
      targetText = '1';
    } else if (cardinality == CardinalityType.manyToMany) {
      sourceText = 'N';
      targetText = 'M';
    }

    // Distância fixa de 28px da borda da tabela em todos os lados
    const badgeOffset = 28.0;

    // Calcular posição do badge para cada extremidade
    final sourceBadgePos = _getBadgePositionFromAnchor(pStart, badgeOffset);
    final targetBadgePos = _getBadgePositionFromAnchor(pEnd, badgeOffset);

    _drawBadgeText(canvas, sourceBadgePos, sourceText, color, txtColor);
    _drawBadgeText(canvas, targetBadgePos, targetText, color, txtColor);
  }

  /// Calcula a posição do badge baseada na distância perpendicular à borda da tabela
  Offset _getBadgePositionFromAnchor(Offset anchor, double distance) {
    // Encontrar qual tabela contém este ponto de ancoragem
    for (final entry in tableRects.entries) {
      final rect = entry.value;

      // Calcular distância de cada lado
      final distToLeft = (anchor.dx - rect.left).abs();
      final distToRight = (anchor.dx - rect.right).abs();
      final distToTop = (anchor.dy - rect.top).abs();
      final distToBottom = (anchor.dy - rect.bottom).abs();

      // Verificar se o ponto está dentro ou na borda do retângulo (com tolerância)
      final isInsideX =
          anchor.dx >= rect.left - 1 && anchor.dx <= rect.right + 1;
      final isInsideY =
          anchor.dy >= rect.top - 1 && anchor.dy <= rect.bottom + 1;

      if (isInsideX && isInsideY) {
        // Determinar qual lado está mais próximo
        final minDist = [
          distToLeft,
          distToRight,
          distToTop,
          distToBottom,
        ].reduce((a, b) => a < b ? a : b);

        if (minDist == distToLeft) {
          return Offset(rect.left - distance, anchor.dy);
        } else if (minDist == distToRight) {
          return Offset(rect.right + distance, anchor.dy);
        } else if (minDist == distToTop) {
          return Offset(anchor.dx, rect.top - distance);
        } else {
          return Offset(anchor.dx, rect.bottom + distance);
        }
      }
    }

    // Fallback: retornar posição com offset para cima
    return Offset(anchor.dx, anchor.dy - distance);
  }

  void _drawBadgeText(
    Canvas canvas,
    Offset center,
    String text,
    Color bg,
    Color textClr,
  ) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: textClr,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeRect = Rect.fromCenter(
      center: center,
      width: textPainter.width + 10,
      height: textPainter.height + 6,
    );

    final bgPaint = Paint()
      ..color = bg
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(4)),
      bgPaint,
    );

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant OrthogonalConnectionPainter oldDelegate) {
    return oldDelegate.relationships != relationships ||
        oldDelegate.tableRects != tableRects ||
        oldDelegate.selectedRelationshipId != selectedRelationshipId ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.selectedLineColor != selectedLineColor ||
        oldDelegate.textColor != textColor;
  }
}
