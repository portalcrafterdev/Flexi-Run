import 'dart:math';
import 'dart:ui';

import 'constants.dart';
import 'weighted_picker.dart';

/// v1 ships three shapes. A fourth (triangle) is a v2 unlock, so every switch
/// on this enum stays exhaustive and no count of 3 is hardcoded outside the UI.
enum ShapeKind { circle, square, star }

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
  }
}

/// Picks wall shapes with a bias away from what just went past, and never
/// repeats the same shape more than twice in a row.
class ShapePicker extends WeightedPicker<ShapeKind> {
  ShapePicker({super.random}) : super(ShapeKind.values);
}
