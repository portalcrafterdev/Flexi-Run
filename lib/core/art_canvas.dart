import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui';

import 'constants.dart';

typedef ArtPainter = void Function(Canvas canvas, Size size);

/// Rasterises [painter] into an image.
///
/// The painter always works in world units; [scale] only decides how many
/// device pixels back them, exactly like authoring the real art at 2x.
Future<ui.Image> rasterize(
  double width,
  double height,
  double scale,
  ArtPainter painter,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(scale);
  painter(canvas, Size(width, height));
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (width * scale).round(),
    (height * scale).round(),
  );
  picture.dispose();
  return image;
}

Paint fillWith(Color color) => Paint()..color = color;

Paint strokeWith(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeJoin = StrokeJoin.round;

/// Shades a round form as if lit from [kLightOffsetX], [kLightOffsetY].
///
/// A flat fill reads as a cut-out; the same silhouette with a light side, a
/// midtone and a shadow side reads as an object with a volume. This is the
/// single biggest difference between the two.
Paint volumeShade(
  Offset centre,
  double radius,
  Color light,
  Color mid,
  Color deep,
) => Paint()
  ..shader = ui.Gradient.radial(
    centre.translate(radius * kLightOffsetX, radius * kLightOffsetY),
    radius * kLightSpread,
    <Color>[light, mid, deep],
    <double>[0, 0.52, 1],
  );

/// A top-to-bottom shade, for flat faces that catch the light on their upper
/// edge rather than curving away from it.
Paint faceShade(Rect area, Color top, Color bottom) => Paint()
  ..shader = ui.Gradient.linear(
    area.topCenter,
    area.bottomCenter,
    <Color>[top, bottom],
  );

/// A blurred blob, for contact shadows and glows.
void softOval(Canvas canvas, Rect oval, Color color, double blur) {
  canvas.drawOval(
    oval,
    Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
  );
}

/// Scatters faint dots over [area], which stops a large flat fill from
/// looking like a screenshot of a colour swatch.
void speckle(
  Canvas canvas,
  Rect area,
  Random rng,
  int count,
  Color color,
  double maxRadius,
) {
  final paint = fillWith(color);
  for (var i = 0; i < count; i++) {
    canvas.drawCircle(
      Offset(
        area.left + rng.nextDouble() * area.width,
        area.top + rng.nextDouble() * area.height,
      ),
      maxRadius * (0.35 + rng.nextDouble() * 0.65),
      paint,
    );
  }
}

/// The distance wash for something at depth [z], or null if it is near enough
/// to need none.
///
/// Air is not transparent over a mile of it: colour drains toward the sky and
/// contrast flattens. Applied with srcATop so the sprite's own transparency
/// survives - srcOver would fill the whole box.
ColorFilter? hazeAt(double z) {
  if (z <= kSceneryHazeStartZ) return null;
  final t = ((z - kSceneryHazeStartZ) / (kSceneryHazeFullZ - kSceneryHazeStartZ))
      .clamp(0.0, 1.0);
  return _hazeFilters[(t * kSceneryHazeSteps).round()];
}

/// Built once. A new ColorFilter per sprite per frame is an allocation the
/// scene does not need.
final List<ColorFilter> _hazeFilters = List<ColorFilter>.generate(
  kSceneryHazeSteps + 1,
  (i) => ColorFilter.mode(
    kHazeTintColor.withValues(alpha: kSceneryHazeMax * i / kSceneryHazeSteps),
    BlendMode.srcATop,
  ),
);

/// Nudges a colour lighter or darker by [amount], -1 to 1.
///
/// Used for per-item jitter, so a repeated element - bricks especially - is
/// never the same colour twice running.
Color shift(Color color, double amount) {
  final target = amount < 0 ? 0.0 : 1.0;
  final t = amount.abs();
  return Color.from(
    alpha: color.a,
    red: color.r + (target - color.r) * t,
    green: color.g + (target - color.g) * t,
    blue: color.b + (target - color.b) * t,
  );
}

/// A horizontally seamless silhouette filling the bottom of [size].
///
/// Both frequencies are whole numbers of cycles across the tile, so the left
/// and right edges always meet and the layer repeats without a seam.
Path seamlessRidge(
  Size size, {
  required double baseline,
  required int cyclesA,
  required double ampA,
  required int cyclesB,
  required double ampB,
  double phaseB = 1.3,
  double step = 4.0,
}) {
  final path = Path()..moveTo(0, size.height);
  for (var x = 0.0; x <= size.width; x += step) {
    final t = x / size.width * 2 * pi;
    final y =
        baseline - ampA * sin(t * cyclesA) - ampB * sin(t * cyclesB + phaseB);
    path.lineTo(x, y);
  }
  return path
    ..lineTo(size.width, size.height)
    ..close();
}
