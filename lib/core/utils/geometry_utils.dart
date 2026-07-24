import 'dart:ui';

enum ConnectionSide { top, right, bottom, left }

class AnchorPoint {
  final Offset point;
  final ConnectionSide side;

  const AnchorPoint(this.point, this.side);
}

class GeometryUtils {
  /// Retorna o ponto de ancoragem no lado indicado de um Rect.
  static Offset getSideCenter(Rect rect, ConnectionSide side) {
    switch (side) {
      case ConnectionSide.top:
        return Offset(rect.left + rect.width / 2, rect.top);
      case ConnectionSide.right:
        return Offset(rect.right, rect.top + rect.height / 2);
      case ConnectionSide.bottom:
        return Offset(rect.left + rect.width / 2, rect.bottom);
      case ConnectionSide.left:
        return Offset(rect.left, rect.top + rect.height / 2);
    }
  }

  /// Calcula o par de pontos de ancoragem mais próximos entre dois retângulos.
  static (AnchorPoint, AnchorPoint) getBestAnchorPair(Rect sourceRect, Rect targetRect) {
    double minDistance = double.infinity;
    AnchorPoint bestSource = AnchorPoint(sourceRect.center, ConnectionSide.right);
    AnchorPoint bestTarget = AnchorPoint(targetRect.center, ConnectionSide.left);

    for (var sSide in ConnectionSide.values) {
      final sPoint = getSideCenter(sourceRect, sSide);
      for (var tSide in ConnectionSide.values) {
        final tPoint = getSideCenter(targetRect, tSide);
        final dist = (sPoint - tPoint).distance;
        if (dist < minDistance) {
          minDistance = dist;
          bestSource = AnchorPoint(sPoint, sSide);
          bestTarget = AnchorPoint(tPoint, tSide);
        }
      }
    }

    return (bestSource, bestTarget);
  }

  /// Calcula os pontos de inflexão para uma linha ortogonal (90 graus) entre dois pontos.
  static List<Offset> calculateOrthogonalPath(
    AnchorPoint source,
    AnchorPoint target, {
    double offsetPadding = 24.0,
  }) {
    final List<Offset> path = [source.point];

    // Ponto inicial afastado da borda da tabela
    final Offset startStub = _getStubPoint(source.point, source.side, offsetPadding);
    final Offset endStub = _getStubPoint(target.point, target.side, offsetPadding);

    path.add(startStub);

    // Calcular cotovelos ortogonais
    if (source.side == ConnectionSide.right || source.side == ConnectionSide.left) {
      if (target.side == ConnectionSide.left || target.side == ConnectionSide.right) {
        final midX = (startStub.dx + endStub.dx) / 2;
        path.add(Offset(midX, startStub.dy));
        path.add(Offset(midX, endStub.dy));
      } else {
        path.add(Offset(endStub.dx, startStub.dy));
      }
    } else {
      if (target.side == ConnectionSide.top || target.side == ConnectionSide.bottom) {
        final midY = (startStub.dy + endStub.dy) / 2;
        path.add(Offset(startStub.dx, midY));
        path.add(Offset(endStub.dx, midY));
      } else {
        path.add(Offset(startStub.dx, endStub.dy));
      }
    }

    path.add(endStub);
    path.add(target.point);

    return path;
  }

  static Offset _getStubPoint(Offset pt, ConnectionSide side, double padding) {
    switch (side) {
      case ConnectionSide.top:
        return Offset(pt.dx, pt.dy - padding);
      case ConnectionSide.right:
        return Offset(pt.dx + padding, pt.dy);
      case ConnectionSide.bottom:
        return Offset(pt.dx, pt.dy + padding);
      case ConnectionSide.left:
        return Offset(pt.dx - padding, pt.dy);
    }
  }
}
