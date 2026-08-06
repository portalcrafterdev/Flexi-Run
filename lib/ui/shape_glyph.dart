import 'package:flutter/widgets.dart';

import '../core/constants.dart';
import '../core/shape_kind.dart';

/// Draws a [ShapeKind] using the same path the wall holes are cut with, so a
/// button always looks like the opening it stands for.
///
/// Swap point for the real btn_*.png art: replace the body with an Image.
class ShapeGlyph extends StatelessWidget {
  const ShapeGlyph({
    required this.kind,
    required this.color,
    this.size = kShapeButton,
    super.key,
  });

  final ShapeKind kind;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _GlyphPainter(kind, color)),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.kind, this.color);

  final ShapeKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      shapePath(kind, Offset(size.width / 2, size.height / 2), size.width / 2),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.kind != kind || old.color != color;
}
