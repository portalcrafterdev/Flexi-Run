import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui';

import 'art_canvas.dart';
import 'constants.dart';

// Scenery, drawn in code until the real PNGs land. Everything here is lit from
// the same direction as the runner and the walls, and everything far away is
// washed toward the haze colour, because that is what distance does to colour.

/// Sky, sun and the haze that gathers on the horizon.
Future<ui.Image> paintSky() {
  return rasterize(kWorldW, kWorldH, kArtScaleLayer, (canvas, size) {
    final area = Offset.zero & size;
    canvas.drawRect(
      area,
      Paint()
        ..shader = ui.Gradient.linear(
          area.topCenter,
          Offset(size.width / 2, kHorizonY),
          const <Color>[kSkyTop, kSkyBottom],
        ),
    );

    final sun = Offset(
      size.width * kSunCentre.dx,
      size.height * kSunCentre.dy,
    );
    canvas
      ..drawCircle(
        sun,
        kSunRadius,
        Paint()
          ..color = kSunColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
      )
      ..drawCircle(
        sun,
        kSunRadius * 0.34,
        Paint()
          ..color = kSunCoreColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
      );

    _clouds(canvas, size);

    // Air thickens toward the horizon, which is most of why a landscape reads
    // as deep rather than as a backdrop.
    canvas.drawRect(
      Rect.fromLTRB(0, kHorizonY - kHillsH, size.width, kHorizonY + 4),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, kHorizonY - kHillsH),
          Offset(0, kHorizonY),
          const <Color>[Color(0x00EAF7FF), kHazeColor],
        ),
    );
  });
}

void _clouds(Canvas canvas, Size size) {
  final rng = Random(4);
  for (var i = 0; i < 5; i++) {
    final at = Offset(
      size.width * (0.06 + i * 0.21) + rng.nextDouble() * 40,
      size.height * (0.08 + rng.nextDouble() * 0.16),
    );
    final w = 90 + rng.nextDouble() * 90;
    final paint = Paint()
      ..color = kCloudColor.withValues(alpha: 0.5 + rng.nextDouble() * 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    for (var puff = 0; puff < 3; puff++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: at.translate(
            (puff - 1) * w * 0.32,
            (rng.nextDouble() - 0.5) * 12,
          ),
          width: w * (0.62 + rng.nextDouble() * 0.4),
          height: w * 0.3,
        ),
        paint,
      );
    }
  }
}

/// Rolling hills with a castle, sitting on the horizon.
Future<ui.Image> paintHills() {
  return rasterize(kWorldW, kHillsH, kArtScaleLayer, (canvas, size) {
    final far = seamlessRidge(
      size,
      baseline: size.height * 0.62,
      cyclesA: 2,
      ampA: 38,
      cyclesB: 5,
      ampB: 14,
    );
    canvas.drawPath(far, fillWith(kHillsFarColor));
    _castle(canvas, Offset(size.width * 0.72, size.height * 0.62));

    final mid = seamlessRidge(
      size,
      baseline: size.height * 0.86,
      cyclesA: 3,
      ampA: 26,
      cyclesB: 1,
      ampB: 18,
      phaseB: 2.1,
    );
    canvas
      ..drawPath(mid, fillWith(kHillsMidColor))
      // Sunlit crests: the near ridge catches light along its top edge.
      ..save()
      ..clipPath(mid)
      ..drawPath(
        mid.shift(const Offset(0, 7)),
        strokeWith(shift(kHillsMidColor, 0.2), 9),
      )
      ..restore();
  });
}

void _castle(Canvas canvas, Offset base) {
  final roof = fillWith(kCastleRoofColor);
  const towerW = 20.0;
  const towerH = 60.0;
  const keepW = 48.0;
  const keepH = 42.0;

  final keep = Rect.fromLTWH(base.dx - keepW / 2, base.dy - keepH, keepW, keepH);
  canvas.drawRect(keep, faceShade(keep, kCastleColor, kCastleRoofColor));
  for (final dx in <double>[-keepW / 2 - towerW / 2, keepW / 2 - towerW / 2]) {
    final left = base.dx + dx;
    final tower = Rect.fromLTWH(left, base.dy - towerH, towerW, towerH);
    canvas
      ..drawRect(tower, faceShade(tower, kCastleColor, kCastleRoofColor))
      ..drawPath(
        Path()
          ..moveTo(left - 4, base.dy - towerH)
          ..lineTo(left + towerW + 4, base.dy - towerH)
          ..lineTo(left + towerW / 2, base.dy - towerH - 20)
          ..close(),
        roof,
      );
  }
}

/// A roadside tree. Drawn at its z = 0 size and scaled down by depth.
Future<ui.Image> paintTree() {
  return rasterize(kSceneryBaseSize, kSceneryBaseSize, kArtScaleLayer, (
    canvas,
    size,
  ) {
    final base = Offset(size.width / 2, size.height);
    final trunkW = size.width * 0.13;
    final trunkH = size.height * 0.34;
    final trunk = Rect.fromLTWH(
      base.dx - trunkW / 2,
      base.dy - trunkH,
      trunkW,
      trunkH,
    );

    softOval(
      canvas,
      Rect.fromCenter(
        center: base,
        width: size.width * 0.44,
        height: size.height * 0.06,
      ),
      kContactShadowColor,
      kContactShadowBlur,
    );
    canvas.drawRRect(
      RRect.fromRectXY(trunk, trunkW * 0.3, trunkW * 0.3),
      Paint()
        ..shader = ui.Gradient.linear(
          trunk.centerLeft,
          trunk.centerRight,
          const <Color>[kTreeTrunkColor, kTrunkDarkColor],
        ),
    );

    // Clusters, biggest and darkest at the bottom of the canopy where the sky
    // cannot reach, lightest on the side facing the light.
    final leafR = size.width * 0.3;
    final crown = base.dy - trunkH - leafR * 0.55;
    for (final puff in <(double, double, double, Color)>[
      (-0.72, 0.42, 0.66, kTreeLeafDeepColor),
      (0.72, 0.42, 0.66, kTreeLeafDeepColor),
      (0, 0, 1, kTreeLeafColor),
      (-0.3, -0.4, 0.55, kTreeLeafLightColor),
    ]) {
      final at = Offset(base.dx + leafR * puff.$1, crown + leafR * puff.$2);
      final r = leafR * puff.$3;
      canvas.drawCircle(
        at,
        r,
        volumeShade(at, r, shift(puff.$4, 0.16), puff.$4, kTreeLeafDeepColor),
      );
    }
  });
}

/// A roadside bush, so the verge is not all trees.
Future<ui.Image> paintBush() {
  return rasterize(kSceneryBaseSize, kSceneryBaseSize, kArtScaleLayer, (
    canvas,
    size,
  ) {
    final base = Offset(size.width / 2, size.height);
    final r = size.width * 0.22;
    softOval(
      canvas,
      Rect.fromCenter(center: base, width: r * 3.4, height: r * 0.5),
      kContactShadowColor,
      kContactShadowBlur * 0.7,
    );
    for (final puff in <(double, double, double, Color)>[
      (-0.8, -0.5, 0.8, kBushColor),
      (0.8, -0.5, 0.8, kBushColor),
      (0, -0.85, 1, kBushLightColor),
      (-0.5, -0.35, 0.62, kBushLightColor),
    ]) {
      final at = base.translate(r * puff.$1, r * puff.$2);
      final radius = r * puff.$3;
      canvas.drawCircle(
        at,
        radius,
        volumeShade(
          at,
          radius,
          shift(puff.$4, 0.2),
          puff.$4,
          kTreeLeafDeepColor,
        ),
      );
    }
  });
}

/// A few grass tufts, scattered on the verge.
Future<ui.Image> paintTuft() {
  final rng = Random(9);
  return rasterize(kSceneryBaseSize, kSceneryBaseSize, kArtScaleLayer, (
    canvas,
    size,
  ) {
    final base = Offset(size.width / 2, size.height);
    for (var i = 0; i < 9; i++) {
      final dx = (rng.nextDouble() - 0.5) * size.width * 0.6;
      final h = size.height * (0.12 + rng.nextDouble() * 0.16);
      final blade = Path()
        ..moveTo(base.dx + dx, base.dy)
        ..quadraticBezierTo(
          base.dx + dx * 1.1,
          base.dy - h * 0.6,
          base.dx + dx * 1.35,
          base.dy - h,
        );
      canvas.drawPath(
        blade,
        strokeWith(
          i.isEven ? kGrassDarkColor : kTreeLeafDeepColor,
          size.width * 0.03,
        )..style = PaintingStyle.stroke,
      );
    }
  });
}
