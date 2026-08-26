// The twelve achievement icons, drawn in the game's own palette.
//
// Rasterised by tool/generate_achievement_icons.dart. Kept out of lib/ because
// nothing in the running app draws these - they exist only to be uploaded to
// Play Console and App Store Connect.
//
// Two constraints shape every icon here:
//
// 1. No text. These are rendered by `flutter test`, which has no real font
//    loaded, so any digit would come out as a blank box. They are also shown
//    to a six year old and to every locale, neither of which wants to read.
// 2. The corners are expendable. Play overlays a circle on the icon in unlock
//    toasts, so the badge fills the square edge to edge and every glyph stays
//    well inside the inscribed circle.

import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flexirun/core/art_canvas.dart';
import 'package:flexirun/core/art_icon.dart';
import 'package:flexirun/core/constants.dart';
import 'package:flexirun/core/shape_kind.dart';

typedef AwardPainter = void Function(Canvas canvas, Size size);

/// Badge grounds. The tier is carried by colour alone, so the twelve read as
/// one set at thumbnail size where the glyphs blur together.
const _green = <Color>[Color(0xFF6FD98F), Color(0xFF2F9E5B)];
const _teal = <Color>[Color(0xFF6BD5D0), Color(0xFF2C8E93)];
const _blue = <Color>[Color(0xFF74B7F0), Color(0xFF2F6FB8)];
const _violet = <Color>[Color(0xFFB9A0EE), Color(0xFF6A4CB5)];
const _rose = <Color>[Color(0xFFFF9DBE), Color(0xFFD1436F)];
const _gold = <Color>[Color(0xFFFFD978), Color(0xFFD69413)];

/// Every icon, in the order they are listed in Play Console.
///
/// The key is the achievement Name exactly as it appears in
/// tool/play_games/AchievementsMetadata.csv. The mappings CSV is generated
/// from these keys, so a name changed in one place cannot silently stop
/// matching the other.
const awards = <String, AwardPainter>{
  'First Run': _firstRun,
  'Shape Shifter': _shapeShifter,
  'Down the Path': _downThePath,
  'Past the Trees': _pastTheTrees,
  'Over the Hills': _overTheHills,
  'The Long Run': _theLongRun,
  'Ten in a Row': _tenInARow,
  'Not a Scratch': _notAScratch,
  'Shield Stack': _shieldStack,
  'Stepping Up': _steppingUp,
  'Top of the Hill': _topOfTheHill,
  'Coin Hunter': _coinHunter,
};

// ---------------------------------------------------------------- the ground

/// The disc every glyph sits on: a lit sphere rather than a flat fill, so the
/// set looks pressed rather than printed.
void _badge(Canvas canvas, Size size, List<Color> tier) {
  final r = size.width / 2;
  final centre = Offset(r, r);

  canvas
    ..drawRect(Offset.zero & size, fillWith(tier.last))
    ..drawCircle(
      centre,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(r * 0.72, r * 0.66),
          r * 1.15,
          tier,
        ),
    )
    // A bright arc along the top left, where every other piece of art in this
    // game is lit from.
    ..drawArc(
      Rect.fromCircle(center: centre, radius: r * 0.9),
      pi * 1.05,
      pi * 0.72,
      false,
      strokeWith(Colors.white.withValues(alpha: 0.34), r * 0.075),
    );
}

/// A helper for the many glyphs that are one shape in white.
Paint get _ink => fillWith(const Color(0xFFFFFFFF));

Paint _inkStroke(double w) => strokeWith(const Color(0xFFFFFFFF), w);

/// Soft drop under a glyph, so white on a mid tone still has an edge.
void _under(Canvas canvas, Path path, double dy) {
  canvas.drawPath(
    path.shift(Offset(0, dy)),
    Paint()..color = const Color(0x33000000),
  );
}

// ------------------------------------------------------------------- glyphs

/// The runner, from the same code that draws the app icon and the menu.
void _firstRun(Canvas canvas, Size size) {
  _badge(canvas, size, _green);
  paintIconRunner(canvas, size, bodyWidth: 0.34, centreY: 0.52, shadow: true);
}

/// All three shapes, arranged as a triangle so no one of them reads as first.
void _shapeShifter(Canvas canvas, Size size) {
  _badge(canvas, size, _violet);
  final s = size.width;
  const kinds = <ShapeKind>[ShapeKind.circle, ShapeKind.square, ShapeKind.star];
  final at = <Offset>[
    Offset(s * 0.5, s * 0.295),
    Offset(s * 0.295, s * 0.665),
    Offset(s * 0.705, s * 0.665),
  ];
  for (var i = 0; i < kinds.length; i++) {
    // A star's points reach [r] but its mass sits well inside that, so at a
    // shared radius it reads as the runt of the three. Given its own.
    final r = s * (kinds[i] == ShapeKind.star ? 0.165 : 0.135);
    final path = shapePath(kinds[i], at[i], r);
    _under(canvas, path, s * 0.018);
    canvas.drawPath(path, _ink);
  }
}

/// One chevron: the first milestone on the path.
void _downThePath(Canvas canvas, Size size) => _chevrons(canvas, size, _teal, 1);

/// A tree on the verge, of the kind the runner passes.
void _pastTheTrees(Canvas canvas, Size size) {
  _badge(canvas, size, _blue);
  final s = size.width;
  final trunk = Path()
    ..addRRect(
      RRect.fromRectXY(
        Rect.fromCenter(
          center: Offset(s * 0.5, s * 0.66),
          width: s * 0.075,
          height: s * 0.26,
        ),
        s * 0.035,
        s * 0.035,
      ),
    );
  _under(canvas, trunk, s * 0.016);
  canvas.drawPath(trunk, fillWith(kTreeTrunkColor));

  // Three clusters, largest at the base, exactly how the roadside trees build.
  for (final (dx, dy, r) in <(double, double, double)>[
    (-0.115, 0.475, 0.115),
    (0.115, 0.475, 0.115),
    (0, 0.355, 0.145),
  ]) {
    canvas.drawCircle(
      Offset(s * (0.5 + dx), s * dy),
      s * r,
      fillWith(kTreeLeafColor),
    );
  }
  canvas.drawCircle(
    Offset(s * 0.45, s * 0.34),
    s * 0.075,
    fillWith(kTreeLeafLightColor),
  );
}

/// Two rises and a sun over them, the horizon from the home screen.
void _overTheHills(Canvas canvas, Size size) {
  _badge(canvas, size, _blue);
  final s = size.width;
  canvas
    ..drawCircle(Offset(s * 0.70, s * 0.30), s * 0.10, fillWith(kMenuSun))
    // Clipped to the badge, and centred below the bottom edge, so only the
    // crests show and they read as a horizon rather than two loose circles.
    ..save()
    ..clipPath(
      Path()..addOval(Rect.fromCircle(center: Offset(s / 2, s / 2), radius: s / 2)),
    );
  // Silhouettes carried down to the bottom edge, not circles. Big circles
  // clipped to the badge came out as crescents and the icon read as two
  // leaves rather than a skyline.
  for (final (base, crest, color) in <(double, double, Color)>[
    (0.72, 0.545, kMenuHillFar),
    (0.86, 0.685, kMenuHillNear),
  ]) {
    canvas.drawPath(
      Path()
        ..moveTo(0, s)
        ..lineTo(0, s * (base + 0.04))
        ..quadraticBezierTo(s * 0.27, s * crest, s * 0.54, s * base)
        ..quadraticBezierTo(s * 0.78, s * (base + 0.06), s, s * (base - 0.02))
        ..lineTo(s, s)
        ..close(),
      fillWith(color),
    );
  }
  canvas.restore();
}

/// Three chevrons: the long climb.
void _theLongRun(Canvas canvas, Size size) => _chevrons(canvas, size, _gold, 3);

/// A ring of ten dots - countable, and the only icon that says a number
/// without writing one.
void _tenInARow(Canvas canvas, Size size) {
  _badge(canvas, size, _teal);
  final s = size.width;
  final centre = Offset(s / 2, s / 2);
  for (var i = 0; i < 10; i++) {
    // Starting at the top and going clockwise, so a child counting them starts
    // where they would expect to.
    final a = -pi / 2 + i * (2 * pi / 10);
    canvas.drawCircle(
      centre + Offset(cos(a), sin(a)) * s * 0.28,
      s * 0.055,
      _ink,
    );
  }
  canvas.drawPath(shapePath(ShapeKind.star, centre, s * 0.13), _ink);
}

/// A whole heart, for a run that never lost one.
void _notAScratch(Canvas canvas, Size size) {
  _badge(canvas, size, _rose);
  final s = size.width;
  final path = _heart(Offset(s / 2, s * 0.5), s * 0.33);
  _under(canvas, path, s * 0.02);
  canvas.drawPath(path, _ink);
}

/// The shield ring from the game, with a star held inside it.
void _shieldStack(Canvas canvas, Size size) {
  _badge(canvas, size, _green);
  final s = size.width;
  final centre = Offset(s / 2, s * 0.5);
  canvas
    ..drawCircle(centre, s * 0.30, _inkStroke(s * 0.055))
    ..drawCircle(centre, s * 0.30, fillWith(kShieldColor.withValues(alpha: .35)))
    ..drawPath(shapePath(ShapeKind.star, centre, s * 0.165), _ink);
}

/// Three steps up, for moving off the level a player started on.
void _steppingUp(Canvas canvas, Size size) {
  _badge(canvas, size, _violet);
  final s = size.width;
  final steps = Path();
  for (var i = 0; i < 3; i++) {
    final h = s * (0.14 + i * 0.115);
    steps.addRRect(
      RRect.fromRectXY(
        Rect.fromLTWH(s * (0.235 + i * 0.185), s * 0.72 - h, s * 0.155, h),
        s * 0.028,
        s * 0.028,
      ),
    );
  }
  _under(canvas, steps, s * 0.018);
  canvas.drawPath(steps, _ink);
}

/// A peak with a flag on it: the top of the hardest level.
void _topOfTheHill(Canvas canvas, Size size) {
  _badge(canvas, size, _gold);
  final s = size.width;
  final peak = Path()
    ..moveTo(s * 0.5, s * 0.235)
    ..lineTo(s * 0.815, s * 0.735)
    ..lineTo(s * 0.185, s * 0.735)
    ..close();
  _under(canvas, peak, s * 0.018);
  canvas
    ..drawPath(peak, fillWith(kMenuPeakColor))
    // Snow cap, clipped to the peak so it cannot spill down the flanks.
    ..save()
    ..clipPath(peak)
    ..drawPath(
      Path()
        ..moveTo(s * 0.5, s * 0.235)
        ..lineTo(s * 0.645, s * 0.465)
        ..lineTo(s * 0.56, s * 0.425)
        ..lineTo(s * 0.47, s * 0.485)
        ..lineTo(s * 0.385, s * 0.435)
        ..close(),
      fillWith(kMenuSnowColor),
    )
    ..restore()
    ..drawRect(
      Rect.fromLTWH(s * 0.487, s * 0.135, s * 0.026, s * 0.18),
      fillWith(kMenuCard),
    )
    ..drawPath(
      Path()
        ..moveTo(s * 0.513, s * 0.145)
        ..lineTo(s * 0.665, s * 0.19)
        ..lineTo(s * 0.513, s * 0.235)
        ..close(),
      fillWith(kHeartFill),
    );
}

/// A coin, from the game's own coin palette.
void _coinHunter(Canvas canvas, Size size) {
  _badge(canvas, size, _gold);
  final s = size.width;
  final centre = Offset(s / 2, s * 0.5);
  canvas
    ..drawCircle(centre, s * 0.305, fillWith(kCoinDeep))
    ..drawCircle(centre, s * 0.285, fillWith(kCoinRim))
    ..drawCircle(centre, s * 0.245, fillWith(kCoinFace))
    ..drawCircle(
      Offset(s * 0.44, s * 0.42),
      s * 0.115,
      fillWith(kCoinLight),
    )
    ..drawPath(shapePath(ShapeKind.star, centre, s * 0.135), fillWith(kCoinDeep))
    ..drawPath(
      shapePath(ShapeKind.star, Offset(s * 0.775, s * 0.245), s * 0.075),
      fillWith(kCoinShine),
    );
}

// ------------------------------------------------------------------- shapes

/// [count] stacked chevrons pointing up the path. One glyph serving three
/// score milestones, told apart by how many and what colour.
void _chevrons(Canvas canvas, Size size, List<Color> tier, int count) {
  _badge(canvas, size, tier);
  final s = size.width;
  final w = s * 0.058;
  // Centred as a group, so one chevron sits in the middle of the badge and
  // three straddle it rather than the stack growing downwards off centre.
  final top = 0.5 - (count - 1) * 0.075 - 0.075;
  for (var i = 0; i < count; i++) {
    final y = s * (top + i * 0.15) + w;
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.305, y + s * 0.105)
        ..lineTo(s * 0.5, y)
        ..lineTo(s * 0.695, y + s * 0.105),
      _inkStroke(w)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }
}

/// A heart of half-height [r]: two lobes, written out rather than mirrored in
/// a loop. The loop version ended both curves at the notch, so the shape never
/// came back down to its point and rendered as a blob.
Path _heart(Offset c, double r) {
  final notch = c.dy - r * 0.45;
  final tip = c.dy + r;
  return Path()
    ..moveTo(c.dx, tip)
    // Up the left side and over the left lobe, finishing at the notch.
    ..cubicTo(
      c.dx - r * 1.5,
      c.dy - r * 0.2,
      c.dx - r * 0.75,
      c.dy - r * 1.35,
      c.dx,
      notch,
    )
    // Over the right lobe and back down to the tip we started from.
    ..cubicTo(
      c.dx + r * 0.75,
      c.dy - r * 1.35,
      c.dx + r * 1.5,
      c.dy - r * 0.2,
      c.dx,
      tip,
    )
    ..close();
}

/// Only the two used above, so the file does not pull in Material.
abstract final class Colors {
  static const white = Color(0xFFFFFFFF);
}
