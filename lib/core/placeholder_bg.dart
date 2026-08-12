import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui';

import 'art_canvas.dart';
import 'constants.dart';

// Sky, weather and the hills on the horizon, drawn in code until the real PNGs
// land. Everything here is lit from the same direction as the runner and the
// walls, and everything far away is washed toward the haze colour, because
// that is what distance does to colour.

/// Sky, sun, light shafts and the haze that gathers on the horizon.
///
/// No clouds: those live in their own drifting band, because a cloud painted
/// into the sky can never move, and a sky that never moves has no weather in
/// it.
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

    final sun = Offset(size.width * kSunCentre.dx, size.height * kSunCentre.dy);
    _shafts(canvas, sun);
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
      )
      // Air thickens toward the horizon, which is most of why a landscape
      // reads as deep rather than as a backdrop.
      ..drawRect(
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

/// Shafts leaning down and away from the sun.
void _shafts(Canvas canvas, Offset sun) {
  final paint = Paint()
    ..color = kSunShaftColor
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, kSunShaftBlur);
  for (var i = 0; i < kSunShafts; i++) {
    final lean = (i - (kSunShafts - 1) / 2) * kSunShaftSpread;
    final foot = sun.translate(lean * kSunShaftLength, kSunShaftLength);
    canvas.drawPath(
      Path()
        ..moveTo(sun.dx - kSunShaftWidth * 0.2, sun.dy)
        ..lineTo(sun.dx + kSunShaftWidth * 0.2, sun.dy)
        ..lineTo(foot.dx + kSunShaftWidth, foot.dy)
        ..lineTo(foot.dx - kSunShaftWidth, foot.dy)
        ..close(),
      paint,
    );
  }
}

/// One tile of the drifting cloud band.
///
/// Every cloud is kept clear of the left and right edges by [kCloudEdgeGuard],
/// so two copies of this image laid end to end never cut one in half and the
/// band can wrap without a seam.
Future<ui.Image> paintClouds() {
  final rng = Random(kCloudSeed);
  return rasterize(kWorldW, kCloudBandH, kArtScaleLayer, (canvas, size) {
    final guard = size.width * kCloudEdgeGuard;
    final span = size.width - guard * 2;

    for (var i = 0; i < kCirrusCount; i++) {
      final at = Offset(
        guard + rng.nextDouble() * span,
        size.height * (0.06 + rng.nextDouble() * 0.22),
      );
      softOval(
        canvas,
        Rect.fromCenter(
          center: at,
          width: kCirrusW * (0.5 + rng.nextDouble() * 0.8),
          height: kCirrusH * (0.6 + rng.nextDouble() * 0.8),
        ),
        kCirrusColor,
        kCirrusBlur,
      );
    }

    for (var i = 0; i < kCloudCount; i++) {
      _cumulus(
        canvas,
        Offset(
          guard + span * (i + 0.5) / kCloudCount + rng.nextDouble() * 30,
          size.height *
              (kCloudHighest +
                  rng.nextDouble() * (kCloudLowest - kCloudHighest)),
        ),
        kCloudMinW + rng.nextDouble() * (kCloudMaxW - kCloudMinW),
        rng,
      );
    }
  });
}

/// A fair weather cumulus: billowing crown, flat base.
///
/// The flat base is not decoration - it is the condensation level, the height
/// at which rising air cools enough to become visible, and it is the same
/// height for every cloud in the sky. Round-bottomed clouds read as cotton
/// wool for exactly this reason.
void _cumulus(Canvas canvas, Offset at, double w, Random rng) {
  final h = w * kCloudAspect;
  final base = at.dy + h * 0.5;
  final puffs = <(Offset, double)>[];
  for (var i = 0; i < kCloudPuffs; i++) {
    final t = i / (kCloudPuffs - 1) - 0.5;
    // Tallest in the middle, tapering to the shoulders.
    final rise = (1 - (t * 2).abs()) * (0.5 + rng.nextDouble() * 0.5);
    puffs.add((
      at.translate(
        t * w * (1 - kCloudPuffSpread * 0.5),
        -rise * h * kCloudPuffSpread,
      ),
      h * (0.34 + rise * 0.4) * (0.85 + rng.nextDouble() * 0.3),
    ));
  }

  canvas
    ..save()
    ..clipRect(Rect.fromLTRB(at.dx - w, at.dy - h * 1.6, at.dx + w, base));

  // The belly first, as one soft mass the lit puffs then sit on top of.
  for (final (centre, r) in puffs) {
    canvas.drawCircle(centre.translate(0, h * 0.2), r, fillWith(kCloudShadeColor));
  }
  for (final (centre, r) in puffs) {
    canvas.drawCircle(
      centre,
      r * 0.94,
      volumeShade(centre, r, kCloudLitColor, kCloudMidColor, kCloudShadeColor),
    );
  }
  // A shadow gathering along the flat base, where the cloud shades itself.
  canvas
    ..drawRect(
      Rect.fromLTRB(at.dx - w, base - h * 0.34, at.dx + w, base),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, base - h * 0.34),
          Offset(0, base),
          const <Color>[Color(0x00A9C6DC), kCloudBaseShadow],
        ),
    )
    ..restore();
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
      );
    _woodland(canvas, size);
    canvas.restore();
  });
}

/// Suggestions of tree cover on the near ridge. Individual trees are far too
/// small to read at this distance; a broken dark edge along the crest is what
/// the eye actually uses to tell a wooded hill from a bare one.
void _woodland(Canvas canvas, Size size) {
  final rng = Random(kTreeSeed);
  final paint = fillWith(shift(kHillsMidColor, -0.16).withValues(alpha: 0.5));
  for (var i = 0; i < 26; i++) {
    final at = Offset(
      rng.nextDouble() * size.width,
      size.height * (0.7 + rng.nextDouble() * 0.3),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: at,
        width: 26 + rng.nextDouble() * 34,
        height: 14 + rng.nextDouble() * 12,
      ),
      paint,
    );
  }
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
