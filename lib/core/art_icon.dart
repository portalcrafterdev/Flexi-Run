import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui';

import 'art_canvas.dart';
import 'art_character.dart';
import 'constants.dart';
import 'shape_kind.dart';

// The app icon: the home screen's sky and hills, with the runner standing in
// front of them.
//
// Drawn from the same palette and the same character-drawing code as the game
// rather than exported from a drawing program, so the icon cannot drift away
// from what the app looks like when you open it. Retune the runner and the
// icon follows.
//
// Generated into the platform folders by tool/generate_app_icon.dart.

/// Sky, sun and hills, filling [size]. The adaptive icon's background layer.
void paintIconScene(Canvas canvas, Size size) {
  final area = Offset.zero & size;
  canvas.drawRect(
    area,
    Paint()
      ..shader = ui.Gradient.linear(
        area.topCenter,
        area.bottomCenter,
        const <Color>[kMenuSkyTop, kMenuSkyMid, kMenuSkyLow],
        const <double>[0, 0.55, 1],
      ),
  );
  _sun(canvas, size);
  _hills(canvas, size);
}

/// Up on the left, the corner the whole game is lit from.
///
/// No rays: at 48 pixels they turn into a smudge, and an icon has to survive
/// its smallest size rather than only look good at its largest.
void _sun(Canvas canvas, Size size) {
  final at = Offset(size.width * 0.15, size.height * 0.15);
  final r = size.width * kIconSunRadius;
  canvas
    ..drawCircle(
      at,
      r * 2.1,
      Paint()
        ..color = kMenuSun.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.1),
    )
    ..drawCircle(at, r, fillWith(kMenuSun))
    ..drawCircle(at, r * 0.72, fillWith(kMenuSunCore));
}

/// Two rises across the bottom, the near one with a lit crest, exactly as the
/// home screen draws them.
void _hills(Canvas canvas, Size size) {
  canvas.drawPath(
    _ridge(size, kIconHillFarY, 0.05, 1.4),
    fillWith(kMenuHillFar),
  );
  final near = _ridge(size, kIconHillNearY, 0.035, 1.9);
  canvas
    ..drawPath(near, fillWith(kMenuHillNear))
    ..save()
    ..clipPath(near)
    ..drawPath(
      near.shift(Offset(0, size.height * 0.03)),
      strokeWith(kMenuHillRim, size.height * 0.04),
    )
    ..restore();
}

Path _ridge(Size size, double baseline, double amp, double cycles) {
  final path = Path()..moveTo(0, size.height);
  for (var x = 0.0; x <= size.width; x += size.width / 64) {
    final t = x / size.width * 2 * pi * cycles;
    path.lineTo(x, size.height * (baseline - amp * sin(t + cycles)));
  }
  return path
    ..lineTo(size.width, size.height)
    ..close();
}

/// The runner, standing on the near hill.
///
/// Round, because the circle is the shape it starts every run as, and because
/// a star or a square at icon size fights the rounded frame it sits in.
void paintIconRunner(
  Canvas canvas,
  Size size, {
  required double bodyWidth,
  double centreY = kIconRunnerY,
  bool shadow = true,
}) {
  final radius = size.width * bodyWidth / 2;
  final centre = Offset(size.width / 2, size.height * centreY);

  // Something to stand on, or it floats the way it used to in the game. Left
  // off the adaptive foreground, where there is no ground under it to fall on
  // and the launcher may shift the two layers apart anyway.
  if (shadow) {
    softOval(
      canvas,
      Rect.fromCenter(
        center: centre.translate(0, radius * 1.42),
        width: radius * 1.9,
        height: radius * 0.34,
      ),
      kContactShadowColor,
      radius * 0.12,
    );
  }

  // Limbs first: they tuck behind the body, same as the runner does going
  // through a hole.
  final legH = radius * kIconLegLength;
  final legW = legH * kLegW / kLegLength;
  for (final side in <double>[-1, 1]) {
    drawLeg(
      canvas,
      Rect.fromLTWH(
        centre.dx + side * radius * kIconLegSpread - legW / 2,
        centre.dy + radius * kIconLegTop,
        legW,
        legH,
      ),
    );
  }

  final armW = radius * kIconArmLength;
  final armH = armW * kArmH / kArmW;
  final arm = Rect.fromLTWH(
    centre.dx + radius * kIconArmReach,
    centre.dy + radius * kIconArmDrop - armH / 2,
    armW,
    armH,
  );
  drawArm(canvas, arm);
  canvas
    ..save()
    // The left arm is the right one mirrored, as it is in the game.
    ..translate(centre.dx * 2, 0)
    ..scale(-1, 1);
  drawArm(canvas, arm);
  canvas.restore();

  drawSlimeBody(canvas, ShapeKind.circle, centre, radius);
}

/// Scene and runner together: the whole icon, for iOS and for Android's
/// pre-adaptive launchers.
///
/// [corner] rounds the frame, for the platforms that do not mask it themselves.
void paintIcon(Canvas canvas, Size size, {double corner = 0}) {
  if (corner > 0) {
    canvas
      ..save()
      ..clipRRect(
        RRect.fromRectXY(Offset.zero & size, corner, corner),
      );
  }
  paintIconScene(canvas, size);
  _motes(canvas, size);
  paintIconRunner(canvas, size, bodyWidth: kIconRunnerWidth);
  if (corner > 0) canvas.restore();
}

/// The three shapes, arced over the runner's head in their title colours.
///
/// Behind the runner and translucent, so at small sizes they read as part of
/// the sky rather than as three more things to look at.
void _motes(Canvas canvas, Size size) {
  final centre = Offset(size.width / 2, size.height * kIconRunnerY);
  for (var i = 0; i < kIconMoteCount; i++) {
    // Arced over the runner's head, starting past the sun in the left corner.
    final a = pi * (1.4 + i * 0.2);
    final at = centre + Offset(cos(a), sin(a)) * (size.width * kIconMoteRadius);
    final kind = ShapeKind.values[i % ShapeKind.values.length];
    canvas.drawPath(
      shapePath(kind, at, size.width * kIconMoteSize),
      // Each shape in the colour the home screen gives it, so the icon and the
      // title card are visibly the same family.
      fillWith(
        kTitleLetterColors[kind.index % kTitleLetterColors.length].withValues(
          alpha: kIconMoteOpacity,
        ),
      ),
    );
  }
}
