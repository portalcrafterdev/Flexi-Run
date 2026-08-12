import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui';

import 'art_canvas.dart';
import 'constants.dart';

// Trees, bushes and grass, drawn in code until the real PNGs land.
//
// The thing that separates foliage from a green circle is that a canopy is
// thousands of leaves catching light at different angles: bright and yellow
// where the sun lands on top, deep and blue-green underneath where only sky
// light reaches. Every painter here builds that in three passes - mass, then a
// scalloped rim, then a sunward highlight - rather than filling a silhouette.

/// A roadside tree, one of [kTreeShapes]. Drawn at its z = 0 size and scaled
/// down by depth.
Future<ui.Image> paintTree(int variant) {
  final shape = kTreeShapes[variant % kTreeShapes.length];
  final rng = Random(kTreeSeed + variant);
  return rasterize(kSceneryBaseSize, kSceneryBaseSize, kArtScaleLayer, (
    canvas,
    size,
  ) {
    final base = Offset(size.width / 2, size.height);
    final canopyW = size.width * shape.$1;
    final canopyH = size.height * shape.$2;
    final trunkH = size.height * shape.$3;
    final crown = Offset(
      base.dx + size.width * shape.$4,
      base.dy - trunkH - canopyH * 0.42,
    );

    softOval(
      canvas,
      Rect.fromCenter(
        center: base,
        width: canopyW * 0.62,
        height: size.height * 0.055,
      ),
      kContactShadowColor,
      kContactShadowBlur,
    );
    _trunk(canvas, base, crown, size.width);
    _branches(canvas, base, crown, canopyW, size.width);
    _canopy(canvas, rng, crown, canopyW, canopyH);
  });
}

/// A tapering trunk with a root flare. A rectangle reads as a post; a trunk
/// spreads where it meets the ground because that is where the roots are.
void _trunk(Canvas canvas, Offset base, Offset crown, double unit) {
  final foot = unit * 0.085;
  final neck = unit * 0.030;
  final waist = (base.dy + crown.dy) / 2;
  final trunk = Path()
    ..moveTo(base.dx - foot, base.dy)
    ..quadraticBezierTo(base.dx - foot * 0.42, waist, crown.dx - neck, crown.dy)
    ..lineTo(crown.dx + neck, crown.dy)
    ..quadraticBezierTo(base.dx + foot * 0.42, waist, base.dx + foot, base.dy)
    ..close();

  canvas
    ..drawPath(
      trunk,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(base.dx - foot, base.dy),
          Offset(base.dx + foot, base.dy),
          <Color>[shift(kTreeTrunkColor, 0.18), kTreeTrunkColor, kTrunkDarkColor],
          <double>[0, 0.4, 1],
        ),
    )
    // Bark, as a few broken vertical grooves clipped to the trunk itself.
    ..save()
    ..clipPath(trunk);
  final groove = strokeWith(kTrunkDarkColor.withValues(alpha: 0.4), unit * 0.012);
  for (var i = 0; i < 4; i++) {
    final t = 0.2 + i * 0.2;
    final x = base.dx + (crown.dx - base.dx) * t + unit * (i.isEven ? 0.02 : -0.03);
    final y = base.dy + (crown.dy - base.dy) * t;
    canvas.drawLine(Offset(x, y), Offset(x, y - unit * 0.09), groove);
  }
  canvas.restore();
}

/// Limbs reaching into the canopy. Mostly hidden by leaves, which is the
/// point: the glimpses of them are what says there is a structure under there.
void _branches(
  Canvas canvas,
  Offset base,
  Offset crown,
  double canopyW,
  double unit,
) {
  final fork = Offset.lerp(base, crown, 0.55)!;
  final paint = strokeWith(kTrunkDarkColor, unit * 0.028)
    ..strokeCap = StrokeCap.round;
  for (final dir in <double>[-1, 1]) {
    canvas.drawPath(
      Path()
        ..moveTo(fork.dx, fork.dy)
        ..quadraticBezierTo(
          fork.dx + dir * canopyW * 0.16,
          fork.dy - unit * 0.05,
          crown.dx + dir * canopyW * 0.3,
          crown.dy + unit * 0.03,
        ),
      paint,
    );
  }
}

/// A canopy: one silhouette, shaded as one solid, with the clustering only
/// breaking its outline and modelling its surface.
///
/// The tempting version - a heap of individually shaded circles - is what
/// makes hand-drawn trees look like broccoli. A real canopy is one mass that
/// happens to have a lumpy edge, and it takes light as one mass.
void _canopy(Canvas canvas, Random rng, Offset crown, double w, double h) {
  final rx = w / 2;
  final ry = h / 2;
  final unit = min(rx, ry);

  // The silhouette. Circles added to one path never cancel each other, so the
  // lumps merge into a single outline rather than reading as separate balls.
  final mass = Path()
    ..addOval(Rect.fromCenter(center: crown, width: w * 0.86, height: h * 0.84));
  final rims = <(Offset, double)>[];
  for (var i = 0; i < kTreeRimClusters; i++) {
    final a = i / kTreeRimClusters * 2 * pi + rng.nextDouble() * 0.3;
    final reach = 0.72 + rng.nextDouble() * 0.2;
    final at = crown.translate(cos(a) * rx * reach, sin(a) * ry * reach);
    final r = unit * kTreeRimRadius * (0.75 + rng.nextDouble() * 0.55);
    rims.add((at, r));
    mass.addOval(Rect.fromCircle(center: at, radius: r));
  }

  canvas
    ..drawPath(
      mass,
      volumeShade(
        crown,
        unit,
        kTreeLeafLightColor,
        kTreeLeafColor,
        kTreeLeafDeepColor,
      ),
    )
    ..save()
    ..clipPath(mass);

  // Surface modelling, inside the silhouette only: shade pooling in the lower
  // clusters, light catching the tops of the upper ones. Low contrast on
  // purpose - this is texture, not more objects.
  for (var i = 0; i < kTreeCoreClusters; i++) {
    final a = rng.nextDouble() * 2 * pi;
    final reach = rng.nextDouble() * 0.7;
    final at = crown.translate(cos(a) * rx * reach, sin(a) * ry * reach);
    final r = unit * kTreeCoreRadius * (0.8 + rng.nextDouble() * 0.6);
    final low = sin(a) * reach > 0;
    canvas.drawCircle(
      at,
      r,
      Paint()
        ..color = (low ? kTreeLeafDeepColor : kTreeLeafLightColor).withValues(
          alpha: 0.22,
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.45),
    );
  }

  // The lit edge of each lump along the sunward shoulder. A thin crescent is
  // what tells the eye the surface is leaves and not a painted balloon.
  final sun = Offset(kLightOffsetX, kLightOffsetY);
  for (final (at, r) in rims) {
    final toSun = at - crown;
    if (toSun.dx * sun.dx + toSun.dy * sun.dy <= 0) continue;
    canvas.drawCircle(
      at.translate(r * kLightOffsetX * 0.5, r * kLightOffsetY * 0.5),
      r * 0.72,
      Paint()..color = kTreeLeafLightColor.withValues(alpha: 0.5),
    );
  }
  canvas.restore();

  // A few leaves breaking the outline. Nothing in nature has a clean edge.
  final fleck = fillWith(kTreeLeafColor);
  for (var i = 0; i < 10; i++) {
    final a = rng.nextDouble() * 2 * pi;
    final at = crown.translate(cos(a) * rx * 0.98, sin(a) * ry * 0.98);
    canvas.drawCircle(at, unit * 0.05 * (0.6 + rng.nextDouble()), fleck);
  }
}

/// A roadside bush, so the verge is not all trees.
Future<ui.Image> paintBush(int variant) {
  final shape = kBushShapes[variant % kBushShapes.length];
  final rng = Random(kBushSeed + variant);
  return rasterize(kSceneryBaseSize, kSceneryBaseSize, kArtScaleLayer, (
    canvas,
    size,
  ) {
    final w = size.width * shape.$1;
    final h = size.height * shape.$2;
    final centre = Offset(size.width / 2, size.height - h * 0.46);

    softOval(
      canvas,
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height),
        width: w * 0.8,
        height: h * 0.16,
      ),
      kContactShadowColor,
      kContactShadowBlur * 0.7,
    );
    _canopy(canvas, rng, centre, w, h);
    _twigs(canvas, rng, centre, w, h);
  });
}

/// A couple of stems poking out of the top, so the bush has a direction of
/// growth rather than being a heap.
void _twigs(Canvas canvas, Random rng, Offset centre, double w, double h) {
  final paint = strokeWith(kTreeLeafDeepColor, w * 0.012)
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 4; i++) {
    final x = centre.dx + (rng.nextDouble() - 0.5) * w * 0.7;
    final y = centre.dy - h * (0.16 + rng.nextDouble() * 0.2);
    canvas.drawLine(Offset(x, y), Offset(x + w * 0.03, y - h * 0.16), paint);
  }
}

/// One soft blotch of grass, with the blur baked in.
///
/// Pre-rendered rather than blurred as it is drawn. A MaskFilter allocates an
/// offscreen the size of the path's bounds every time it runs, and running two
/// of them per frame across the whole field was costing more than everything
/// else in the game put together - enough to force 300ms garbage collections
/// mid-run. Baked once, the same look costs one texture lookup.
Future<ui.Image> paintGrassPatch(bool lit) {
  const pad = kGroundPatchBlur * kGroundPatchBlurPad;
  return rasterize(
    kGroundPatchW + pad * 2,
    kGroundPatchH + pad * 2,
    kArtScaleLayer,
    (canvas, size) => softOval(
      canvas,
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: kGroundPatchW,
        height: kGroundPatchH,
      ),
      lit ? kGrassPatchLitColor : kGrassPatchDeepColor,
      kGroundPatchBlur,
    ),
  );
}

/// A clump of blades for the verge, drawn once and then stamped.
///
/// Several variants, because one repeated clump reads as a pattern - but a
/// handful of images stamped thousands of times is nothing next to rebuilding
/// every blade as a path on every frame.
Future<ui.Image> paintVergeTuft(int variant) {
  final rng = Random(kVergeSeed + variant);
  return rasterize(kVergeTuftW, kVergeTuftH, kArtScaleSprite, (canvas, size) {
    for (var i = 0; i < kVergeBlades; i++) {
      final root = Offset(
        size.width / 2 + (rng.nextDouble() - 0.5) * size.width * 0.7,
        size.height,
      );
      final path = Path();
      _blade(
        path,
        root,
        kVergeBladeH * (0.6 + rng.nextDouble() * 0.6),
        (rng.nextDouble() - 0.5) * kVergeBladeLean,
        kVergeBladeW,
      );
      canvas.drawPath(
        path,
        fillWith(rng.nextBool() ? kVergeBladeColor : kVergeBladeLitColor),
      );
    }
  });
}

/// One tapered blade, appended to [into]. Wide at the root and pointed at the
/// tip: a constant width blade reads as wire.
void _blade(
  Path into,
  Offset root,
  double height,
  double lean,
  double half,
) {
  into
    ..moveTo(root.dx - half, root.dy)
    ..quadraticBezierTo(
      root.dx - half * 0.3 + lean * 0.4,
      root.dy - height * 0.6,
      root.dx + lean,
      root.dy - height,
    )
    ..quadraticBezierTo(
      root.dx + half + lean * 0.4,
      root.dy - height * 0.55,
      root.dx + half,
      root.dy,
    )
    ..close();
}

/// Grass tufts, scattered on the verge. Blades are filled and tapered rather
/// than stroked: a blade of grass has a width at the root and a point at the
/// tip, and a constant-width stroke reads as wire.
Future<ui.Image> paintTuft() {
  final rng = Random(9);
  return rasterize(kSceneryBaseSize, kSceneryBaseSize, kArtScaleLayer, (
    canvas,
    size,
  ) {
    final base = Offset(size.width / 2, size.height);
    for (var i = 0; i < 14; i++) {
      final dx = (rng.nextDouble() - 0.5) * size.width * 0.62;
      final h = size.height * (0.13 + rng.nextDouble() * 0.2);
      final lean = dx * 0.4 + (rng.nextDouble() - 0.5) * size.width * 0.06;
      final root = base.translate(dx, 0);
      final tip = root.translate(lean, -h);
      final half = size.width * 0.016;
      canvas.drawPath(
        Path()
          ..moveTo(root.dx - half, root.dy)
          ..quadraticBezierTo(
            root.dx - half * 0.3 + lean * 0.4,
            root.dy - h * 0.6,
            tip.dx,
            tip.dy,
          )
          ..quadraticBezierTo(
            root.dx + half * 0.9 + lean * 0.4,
            root.dy - h * 0.55,
            root.dx + half,
            root.dy,
          )
          ..close(),
        fillWith(i.isEven ? kVergeBladeColor : kVergeBladeLitColor),
      );
    }
  });
}
