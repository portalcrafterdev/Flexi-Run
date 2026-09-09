import 'dart:math';
import 'dart:ui';

import 'constants.dart';
import 'weighted_picker.dart';

/// v1 ships three shapes. A fourth (triangle) is a v2 unlock, so every switch
/// on this enum stays exhaustive and no count of 3 is hardcoded outside the UI.
enum ShapeKind { circle, square, star, triangle }

/// What the slime is wearing at the start of every run.
const kStartShape = ShapeKind.circle;

extension ShapeKindLabel on ShapeKind {
  String get label {
    switch (this) {
      case ShapeKind.circle:
        return 'Circle';
      case ShapeKind.square:
        return 'Square';
      case ShapeKind.star:
        return 'Star';
      case ShapeKind.triangle:
        return 'Triangle';
    }
  }
}

/// The outline of [kind], centred on [c] with half-extent [r].
///
/// Shared by the placeholder art generator, the wall hole and the UI glyphs so
/// a button always matches the hole it stands for.
Path shapePath(ShapeKind kind, Offset c, double r) {
  switch (kind) {
    case ShapeKind.circle:
      return Path()..addOval(Rect.fromCircle(center: c, radius: r));
    case ShapeKind.square:
      final corner = r * kSquareCornerRatio;
      return Path()..addRRect(
        RRect.fromRectXY(
          Rect.fromCenter(center: c, width: r * 2, height: r * 2),
          corner,
          corner,
        ),
      );
    case ShapeKind.star:
      final path = Path();
      const step = pi / kStarPoints;
      for (var i = 0; i < kStarPoints * 2; i++) {
        final radius = i.isEven ? r : r * kStarInnerRatio;
        final angle = -pi / 2 + i * step;
        final p = Offset(
          c.dx + cos(angle) * radius,
          c.dy + sin(angle) * radius,
        );
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      return path..close();
    case ShapeKind.triangle:
      // Filling the 2r box, not inscribed in the circle of radius r.
      //
      // An equilateral triangle inscribed in r covers about 1.3 square units
      // against the circle's 3.14 and the square's 4 - on a button it reads as
      // the runt of the set, and in a wall it punches the smallest hole of the
      // four. Spanning the box instead gives 2, which sits sensibly among the
      // others, and unlike scaling it up it stays inside the half-extent every
      // other shape keeps to.
      return _rounded(<Offset>[
        Offset(c.dx, c.dy - r),
        Offset(c.dx + r, c.dy + r),
        Offset(c.dx - r, c.dy + r),
      ], r * kTriangleCornerRatio);
  }
}

/// A closed polygon through [points] with its corners rounded off by [radius].
///
/// The triangle is the only straight-edged shape in the game that is not a
/// square, and the square is rounded - a sharp-cornered triangle would be the
/// one hard edge in a world where everything else is soft.
Path _rounded(List<Offset> points, double radius) {
  final path = Path();
  for (var i = 0; i < points.length; i++) {
    final current = points[i];
    final previous = points[(i - 1 + points.length) % points.length];
    final next = points[(i + 1) % points.length];

    // Back off along each edge by [radius], then curve through the corner
    // itself. Clamped to half an edge so a large radius cannot overshoot the
    // neighbouring corner and turn the path inside out.
    final toPrevious = _stepToward(current, previous, radius);
    final toNext = _stepToward(current, next, radius);

    if (i == 0) {
      path.moveTo(toPrevious.dx, toPrevious.dy);
    } else {
      path.lineTo(toPrevious.dx, toPrevious.dy);
    }
    path.quadraticBezierTo(current.dx, current.dy, toNext.dx, toNext.dy);
  }
  return path..close();
}

Offset _stepToward(Offset from, Offset to, double distance) {
  final dx = to.dx - from.dx;
  final dy = to.dy - from.dy;
  final length = sqrt(dx * dx + dy * dy);
  if (length == 0) return from;
  final step = min(distance, length / 2) / length;
  return Offset(from.dx + dx * step, from.dy + dy * step);
}

/// Picks wall shapes with a bias away from what just went past, and never
/// repeats the same shape more than twice in a row.
class ShapePicker extends WeightedPicker<ShapeKind> {
  /// [shapes] is the level's own set, not every shape that exists: the
  /// triangle is only in play on Hard, and a picker that did not know that
  /// would send one down the path on Easy with no button to answer it.
  ShapePicker(super.shapes, {super.random});
}
