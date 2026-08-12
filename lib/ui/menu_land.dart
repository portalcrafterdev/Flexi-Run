import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/constants.dart';

// Everything below the horizon: mountains, two rolling rises, a castle, trees,
// and the path.
//
// The path is the point of all of it. It is the road the game is run down, and
// having it start here - with the character standing on it, winding away to a
// castle you never quite reach - is what makes PLAY read as setting off rather
// than as opening a screen.

/// A snow capped range along the horizon, hazy with distance.
void paintMountains(Canvas canvas, Size size) {
  final rng = Random(kMenuPeakSeed);
  final base = size.height * kMenuPeakBase;
  final apexes = <(Offset, double)>[];
  final count = kMenuPeakHeights.length;

  final range = Path()..moveTo(0, base);
  for (var i = 0; i < count; i++) {
    final left = size.width * i / count;
    final right = size.width * (i + 1) / count;
    final share = kMenuPeakHeights[i];
    final height = size.height * share;
    // The apex sits off centre, or the range is a row of tents.
    final apex = left + (right - left) * (0.34 + rng.nextDouble() * 0.32);
    final peak = Offset(apex, base - height);
    apexes.add((peak, share));
    range
      ..lineTo(peak.dx, peak.dy)
      ..lineTo(right, base - height * (0.08 + rng.nextDouble() * 0.24));
  }
  range
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();

  canvas
    ..drawPath(range, Paint()..color = kMenuPeakColor)
    // Shaded towards the foot, so the range recedes instead of sitting flat.
    ..save()
    ..clipPath(range)
    ..drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, size.height * (kMenuPeakBase - kMenuPeakHeights.reduce(max))),
          Offset(0, base),
          const <Color>[Color(0x00000000), kMenuPeakShade],
        ),
    )
    ..restore();

  for (final (peak, share) in apexes) {
    if (share < kMenuSnowFrom) continue;
    _snow(canvas, size, peak, share);
  }
}

/// A cap on the tall peaks only. Snow on every one of them reads as a pattern
/// rather than as height.
void _snow(Canvas canvas, Size size, Offset peak, double share) {
  final drop = size.height * share * kMenuSnowDrop;
  // The peaks are drawn with roughly 45 degree flanks, so the cap has to widen
  // at about the same rate or it floats off the rock.
  final half = drop * 0.62;
  canvas.drawPath(
    Path()
      ..moveTo(peak.dx, peak.dy)
      ..lineTo(peak.dx - half, peak.dy + drop)
      // A kink along the bottom, which is where the snow line actually sits.
      ..lineTo(peak.dx - half * 0.38, peak.dy + drop * 0.62)
      ..lineTo(peak.dx, peak.dy + drop * 0.92)
      ..lineTo(peak.dx + half * 0.42, peak.dy + drop * 0.58)
      ..lineTo(peak.dx + half, peak.dy + drop)
      ..close(),
    Paint()..color = kMenuSnowColor,
  );
}

/// The ground: a receding wash from the horizon to the bottom of the frame,
/// with two rolling rises laid over it.
///
/// A wash rather than flat green for the same reason the game's ground uses
/// one - distance takes the colour out of grass, and keeping the far end
/// paler is the whole of why it reads as going away from you.
void paintMeadow(Canvas canvas, Size size) {
  final horizon = size.height * kMenuHorizon;
  canvas.drawRect(
    Rect.fromLTRB(0, horizon, size.width, size.height),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, horizon),
        Offset(0, size.height),
        const <Color>[kMenuHillFar, kMenuHillMid, kMenuHillNear],
        const <double>[0, 0.42, 1],
      ),
  );

  // Air between you and the far ground. Without it the meadow meets the sky
  // along a drawn line, which is the one place a painted scene gives itself
  // away as two rectangles.
  canvas.drawRect(
    Rect.fromLTRB(
      0,
      horizon,
      size.width,
      horizon + size.height * kMenuHazeDepth,
    ),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, horizon),
        Offset(0, horizon + size.height * kMenuHazeDepth),
        <Color>[
          kMenuSkyWarm.withValues(alpha: kMenuHazeAlpha),
          kMenuSkyWarm.withValues(alpha: 0),
        ],
      ),
  );

  canvas.drawPath(
    ridgePath(size, kMenuRidgeFarY, 0.035, 1.5),
    _fill(kMenuHillMid),
  );

  final mid = ridgePath(size, kMenuRidgeMidY, 0.028, 2.3);
  canvas
    ..drawPath(mid, _fill(kMenuHillNear))
    // A lit crest along the top of the near rise.
    ..save()
    ..clipPath(mid)
    ..drawPath(
      mid.shift(Offset(0, size.height * 0.02)),
      Paint()
        ..color = kMenuHillRim
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * 0.028,
    )
    ..restore();
}

/// One rolling rise, filled down to the bottom of the frame.
Path ridgePath(Size size, double baseline, double amp, double cycles) {
  final path = Path()..moveTo(0, size.height);
  for (var x = 0.0; x <= size.width; x += 6) {
    final t = x / size.width * 2 * pi * cycles;
    path.lineTo(x, size.height * (baseline - amp * sin(t + cycles)));
  }
  return path
    ..lineTo(size.width, size.height)
    ..close();
}

/// The castle at the end of the path, up on the far ridge.
void paintCastle(Canvas canvas, Size size) {
  final w = size.width * kMenuCastleW;
  final h = size.height * kMenuCastleH;
  final foot = Offset(size.width * kMenuCastleX, size.height * kMenuRidgeFarY);
  // Paler than the game's own castle: this one is a range further away, and
  // distance takes the colour out of it.
  final stone = _fill(kMenuCastleStone);
  final roof = _fill(kMenuCastleRoof);

  // Curtain wall between the towers, with battlements along the top.
  final wall = Rect.fromLTRB(
    foot.dx - w / 2,
    foot.dy - h * 0.52,
    foot.dx + w / 2,
    foot.dy,
  );
  canvas.drawRect(wall, stone);
  for (var i = 0; i < 3; i++) {
    canvas.drawRect(
      Rect.fromLTWH(
        wall.left + w * (0.18 + i * 0.26),
        wall.top - h * 0.07,
        w * 0.14,
        h * 0.08,
      ),
      stone,
    );
  }

  // Two towers and a taller keep behind them, each under a pointed roof.
  for (final tower in <(double, double)>[(-0.5, 0.74), (0.5, 0.74), (0, 1)]) {
    final centre = foot.dx + w * tower.$1;
    final tall = h * tower.$2;
    final half = w * (tower.$2 == 1 ? 0.17 : 0.15);
    canvas
      ..drawRect(
        Rect.fromLTRB(centre - half, foot.dy - tall, centre + half, foot.dy),
        stone,
      )
      ..drawPath(
        Path()
          ..moveTo(centre, foot.dy - tall - h * 0.3)
          ..lineTo(centre - half * 1.35, foot.dy - tall)
          ..lineTo(centre + half * 1.35, foot.dy - tall)
          ..close(),
        roof,
      );
  }
}

/// Conifers along the ridges. Three stacked triangles and a trunk: at this
/// size anything more detailed turns to mush.
void paintTrees(Canvas canvas, Size size) {
  for (final (across, ridge, scale) in kMenuTrees) {
    final h = size.height * kMenuTreeH * scale;
    final foot = Offset(size.width * across, size.height * ridge + h * 0.06);
    final half = h * 0.3;
    canvas.drawRect(
      Rect.fromLTWH(foot.dx - h * 0.035, foot.dy - h * 0.16, h * 0.07, h * 0.16),
      _fill(kTrunkDarkColor),
    );
    for (var tier = 0; tier < 3; tier++) {
      final top = foot.dy - h * (0.98 - tier * 0.26);
      final spread = half * (0.58 + tier * 0.21);
      canvas.drawPath(
        Path()
          ..moveTo(foot.dx, top)
          ..lineTo(foot.dx - spread, top + h * 0.4)
          ..lineTo(foot.dx + spread, top + h * 0.4)
          ..close(),
        _fill(tier == 0 ? kTreeLeafLightColor : kTreeLeafColor),
      );
    }
  }
}

/// The path, from a point on the horizon down to the bottom of the frame.
///
/// Drawn last, over the rises rather than between them, so it reads as one
/// continuous road laid across the ground instead of three disconnected
/// stripes.
void paintPath(Canvas canvas, Size size) {
  final top = Offset(size.width * kMenuPathTopX, size.height * kMenuHorizon);
  final topHalf = size.width * kMenuPathTopHalf;
  final footX = size.width * kMenuPathFootX;
  final footHalf = size.width * kMenuPathFootHalf;
  final run = size.height - top.dy;

  final road = Path()
    ..moveTo(top.dx - topHalf, top.dy)
    ..cubicTo(
      top.dx - topHalf * 6,
      top.dy + run * 0.38,
      footX - footHalf * 0.5,
      top.dy + run * 0.66,
      footX - footHalf,
      size.height,
    )
    ..lineTo(footX + footHalf, size.height)
    ..cubicTo(
      footX + footHalf * 0.5,
      top.dy + run * 0.66,
      top.dx + topHalf * 6,
      top.dy + run * 0.38,
      top.dx + topHalf,
      top.dy,
    )
    ..close();

  canvas.drawPath(
    road,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, top.dy),
        Offset(0, size.height),
        const <Color>[kPathFarColor, kPathNearColor],
      ),
  );
}

// There were dashes down the middle of it for a while, growing with the
// perspective. They were removed: markings down the centre make it a highway,
// and this is a dirt path through a meadow. What it needed was to be narrower,
// not better signposted.

/// Specks of colour over the meadow, kept off the road.
void paintFlowers(Canvas canvas, Size size) {
  final rng = Random(kMenuFlowerSeed);
  final horizon = size.height * kMenuHorizon;
  for (var i = 0; i < kMenuFlowerCount; i++) {
    final at = Offset(
      rng.nextDouble() * size.width,
      horizon + rng.nextDouble() * (size.height - horizon),
    );
    // How far down the meadow this one is, which is both how big it should be
    // and how wide the road is where it landed.
    final depth = (at.dy - horizon) / (size.height - horizon);
    final roadX = ui.lerpDouble(
      size.width * kMenuPathTopX,
      size.width * kMenuPathFootX,
      depth * depth,
    )!;
    if ((at.dx - roadX).abs() < size.width * kMenuPathFootHalf * depth * 1.1) {
      continue;
    }
    canvas.drawCircle(
      at,
      kMenuFlowerSize * (0.35 + depth),
      Paint()..color = kMenuFlowerColors[rng.nextInt(kMenuFlowerColors.length)],
    );
  }
}

Paint _fill(Color color) => Paint()..color = color;
