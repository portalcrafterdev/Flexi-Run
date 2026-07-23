import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui';

import 'art_canvas.dart';
import 'constants.dart';
import 'lane.dart';
import 'shape_kind.dart';

// The barrier. Bricks are laid one at a time rather than stamped as a grid of
// lines: each gets its own colour, its own lit top edge and its own shaded
// underside, which is what stops a large wall reading as wallpaper.

/// A barrier with a genuinely transparent [kind]-shaped hole in it, punched
/// over [lane].
///
/// The hole lands on [kHoleLocalY] so that, with the wall base on the ground,
/// its centre lines up with the runner's body, and on the lane's own offset so
/// it lines up with the runner only when it is standing in that lane.
Future<ui.Image> paintWall(ShapeKind kind, Lane lane) {
  return rasterize(kWallW, kWallH, kArtScaleWall, (canvas, size) {
    final hole = shapePath(
      kind,
      Offset(kHoleLocalX + lane.offset, kHoleLocalY),
      kHoleHalf,
    );
    final face = Path()
      ..addRect(Offset.zero & size)
      ..addPath(hole, Offset.zero)
      ..fillType = PathFillType.evenOdd;

    canvas
      ..save()
      // Clipping to the punched path is what keeps the opening transparent:
      // nothing below can paint inside the hole.
      ..clipPath(face);

    _mortar(canvas, size);
    _courses(canvas, size);
    _weather(canvas, size);

    canvas.restore();

    _bevel(canvas, hole);
  });
}

/// The mortar bed the bricks sit in, shaded so the joints read as recessed
/// rather than drawn on.
void _mortar(Canvas canvas, Size size) {
  final area = Offset.zero & size;
  canvas
    ..drawRect(area, fillWith(kMortarColor))
    ..drawRect(area, faceShade(area, kMortarColor, kMortarShadeColor));
}

/// Every brick, individually. Seeded, so the wall is the same wall each run.
void _courses(Canvas canvas, Size size) {
  final rng = Random(7);
  var row = 0;
  for (var y = 0.0; y < size.height; y += kBrickRowH) {
    final offset = row.isEven ? 0.0 : -kBrickColW / 2;
    for (var x = offset; x < size.width; x += kBrickColW) {
      _brick(
        canvas,
        Rect.fromLTWH(
          x + kMortarW,
          y + kMortarW,
          kBrickColW - kMortarW,
          kBrickRowH - kMortarW,
        ),
        rng,
      );
    }
    row++;
  }
}

void _brick(Canvas canvas, Rect at, Random rng) {
  final jitter = (rng.nextDouble() - 0.5) * 2 * kBrickJitter;
  final rrect = RRect.fromRectXY(at, kMortarW * 0.3, kMortarW * 0.3);
  canvas
    // The joint shadow: bricks sit proud of the mortar, so they drop a little
    // shade onto the course below.
    ..drawRRect(
      rrect.shift(const Offset(0, kMortarW * 0.35)),
      fillWith(kWallBaseShadow),
    )
    ..drawRRect(
      rrect,
      faceShade(
        at,
        shift(kBrickLightColor, jitter),
        shift(kBrickDeepColor, jitter),
      ),
    )
    // A lit lip along the top edge, the tell that a face is tilted up.
    ..drawLine(
      at.topLeft.translate(kMortarW * 0.4, kMortarW * 0.3),
      at.topRight.translate(-kMortarW * 0.4, kMortarW * 0.3),
      strokeWith(shift(kBrickLightColor, 0.22), kMortarW * 0.4),
    );

  speckle(canvas, at, rng, kBrickSpeckles, kWallGrimeColor, kMortarW * 0.7);
}

/// Grime gathering along the bottom of the wall and in the corners, plus an
/// overall top-down shade. Clean geometry is the thing that most reads as
/// computer generated; this takes the edge off it.
void _weather(Canvas canvas, Size size) {
  final area = Offset.zero & size;
  canvas.drawRect(
    area,
    Paint()
      ..shader = ui.Gradient.linear(
        area.bottomCenter,
        area.centerLeft,
        <Color>[kWallBaseShadow, const Color(0x00000000)],
      ),
  );
}

/// The inside face of the opening.
///
/// A wall is thick, so its hole is a short tunnel: the near rim catches light
/// and the far side of the bore is in shadow. Drawn outside the clip so it
/// sits on the edge of the opening rather than in it.
void _bevel(Canvas canvas, Path hole) {
  canvas
    ..save()
    // Inside the opening only, and kept narrow: the hole is the one thing the
    // player has to read at a glance, so the bore must never crowd it. A star
    // is the test case - its points close up fast.
    ..clipPath(hole)
    ..drawPath(hole, strokeWith(kHoleBevelColor, kHoleBevelWidth))
    ..restore()
    ..drawPath(hole, strokeWith(kHoleRimColor, kHoleRimWidth));
}

/// A single brick, thrown when a wall shatters.
Future<ui.Image> paintShard() {
  const box = kShardSize;
  return rasterize(box, box, kArtScaleSprite, (canvas, size) {
    final area = Offset.zero & size;
    canvas
      ..drawRRect(
        RRect.fromRectXY(area, kShardRadius, kShardRadius),
        faceShade(area, kBrickLightColor, kBrickDeepColor),
      )
      // The broken face, lighter than the weathered outside.
      ..drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height * 0.24),
        fillWith(kMortarColor.withValues(alpha: 0.55)),
      );
  });
}
