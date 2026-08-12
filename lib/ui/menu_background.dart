import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/shape_kind.dart';

/// The menu's own scene: sky, sun, clouds, rolling hills, and the game's three
/// shapes drifting in the air.
///
/// Painted here rather than shown through to the live world. The world behind
/// is a running game, and a runner jogging on the spot behind the title reads
/// as something left switched on by mistake. This is a picture of the same
/// place with nobody in it.
class MenuBackground extends StatefulWidget {
  const MenuBackground({super.key});

  @override
  State<MenuBackground> createState() => _MenuBackgroundState();
}

class _MenuBackgroundState extends State<MenuBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: kMenuMoteSeconds),
  )..repeat();

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _drift,
      builder: (_, _) => CustomPaint(
        painter: _ScenePainter(_drift.value),
        size: Size.infinite,
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  const _ScenePainter(this.phase);

  /// 0 to 1, one full bob of the drifting shapes.
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    _sky(canvas, size);
    _sun(canvas, size);
    _sparkles(canvas, size);
    _clouds(canvas, size);
    _hills(canvas, size);
    _motes(canvas, size);
    // Last, over everything: it is the light in the room, not part of the
    // scenery.
    _vignette(canvas, size);
  }

  /// Deep blue overhead down to warm cream at the horizon.
  ///
  /// The warm band is what makes the light in the picture come from somewhere.
  /// A sky that stays blue all the way down to the hills is an overcast one,
  /// however bright the blue is, and the sun drawn on top of it then looks
  /// stuck on rather than lighting anything.
  void _sky(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width / 2, 0),
          Offset(size.width / 2, size.height),
          const <Color>[kMenuSkyTop, kMenuSkyMid, kMenuSkyLow, kMenuSkyWarm],
          const <double>[0, 0.42, 0.72, 1],
        ),
    );
  }

  /// Corners taken down, so the middle of the picture is the brightest part of
  /// it and the cards read against a settled background rather than a wash.
  void _vignette(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width / 2, size.height * 0.45),
          size.width * 0.62,
          const <Color>[Color(0x00000000), kMenuVignette],
          const <double>[kMenuVignetteStart, 1],
        ),
    );
  }

  /// Up in the open middle of the picture, with soft rays.
  ///
  /// It used to sit in the top left corner, which is where the world is lit
  /// from - but that corner is also where the name and the tagline go, and a
  /// translucent white lozenge laid over a sun's rays reads as a mistake. Out
  /// here it has clear sky around it and it fills the gap between the runner
  /// and the buttons, which was the emptiest part of the screen.
  ///
  /// Kept well clear of the hills: a sun half swallowed by a ridge looks like
  /// one that was positioned by accident.
  void _sun(Canvas canvas, Size size) {
    final at = Offset(size.width * 0.48, size.height * 0.17);
    final r = size.height * 0.10;

    canvas.drawCircle(
      at,
      r * 1.9,
      Paint()
        ..color = kMenuSun.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
    );

    final ray = Paint()
      ..color = kMenuSun.withValues(alpha: 0.55)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.12;
    for (var i = 0; i < 10; i++) {
      final a = i * pi / 5;
      canvas.drawLine(
        at + Offset(cos(a), sin(a)) * (r * 1.25),
        at + Offset(cos(a), sin(a)) * (r * 1.62),
        ray,
      );
    }
    canvas
      ..drawCircle(at, r, Paint()..color = kMenuSun)
      ..drawCircle(at, r * 0.72, Paint()..color = kMenuSunCore);
  }

  void _sparkles(Canvas canvas, Size size) {
    final rng = Random(11);
    for (var i = 0; i < kMenuSparkleCount; i++) {
      final at = Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height * 0.7,
      );
      final r = 1.6 + rng.nextDouble() * 2.4;
      final paint = Paint()..color = kMenuSparkle;
      // A four pointed twinkle rather than a dot: it reads as light.
      canvas
        ..drawOval(
          Rect.fromCenter(center: at, width: r * 0.7, height: r * 4),
          paint,
        )
        ..drawOval(
          Rect.fromCenter(center: at, width: r * 4, height: r * 0.7),
          paint,
        );
    }
  }

  void _clouds(Canvas canvas, Size size) {
    final rng = Random(5);
    for (var i = 0; i < kMenuCloudCount; i++) {
      // High, and starting past the name rather than under it. A cloud half
      // covered by the tagline, or rising out from behind a level button, is
      // the one thing on the screen that looks unfinished - so they are kept
      // in the strip of sky above everything the layout puts on top of them.
      final at = Offset(
        size.width * (0.24 + i * 0.19) + rng.nextDouble() * 30,
        size.height * (0.05 + rng.nextDouble() * 0.15),
      );
      final w = size.width * (0.07 + rng.nextDouble() * 0.05);
      final paint = Paint()..color = kMenuCloud;
      for (final puff in <(double, double)>[(-0.5, 0.55), (0.5, 0.6), (0, 1)]) {
        canvas.drawCircle(
          at.translate(w * puff.$1, w * 0.12 * (1 - puff.$2)),
          w * 0.42 * puff.$2,
          paint,
        );
      }
      canvas.drawRRect(
        RRect.fromRectXY(
          Rect.fromCenter(
            center: at.translate(0, w * 0.22),
            width: w * 1.5,
            height: w * 0.36,
          ),
          w * 0.18,
          w * 0.18,
        ),
        paint,
      );
    }
  }

  /// Three overlapping rises across the bottom, palest at the back.
  void _hills(Canvas canvas, Size size) {
    _ridge(canvas, size, 0.72, 0.10, 1.4, kMenuHillFar);
    _ridge(canvas, size, 0.82, 0.07, 2.2, kMenuHillMid);

    final near = _ridgePath(canvas, size, 0.93, 0.05, 1.7);
    canvas
      ..drawPath(near, Paint()..color = kMenuHillNear)
      // A lit crest along the top of the nearest rise.
      ..save()
      ..clipPath(near)
      ..drawPath(
        near.shift(Offset(0, size.height * 0.022)),
        Paint()
          ..color = kMenuHillRim
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.height * 0.03,
      )
      ..restore();

    _flowers(canvas, size, near);
  }

  /// Specks of colour scattered over the near rise.
  ///
  /// Clipped to the hill, so the ones that land above its crest simply are not
  /// there rather than floating in the sky. Three colours and no stems: at this
  /// size a flower is a dot, and drawing more of one only makes it muddy.
  void _flowers(Canvas canvas, Size size, Path near) {
    final rng = Random(kMenuFlowerSeed);
    canvas
      ..save()
      ..clipPath(near);
    for (var i = 0; i < kMenuFlowerCount; i++) {
      final at = Offset(
        rng.nextDouble() * size.width,
        size.height * (0.9 + rng.nextDouble() * 0.1),
      );
      final r = kMenuFlowerSize * (0.6 + rng.nextDouble() * 0.7);
      canvas.drawCircle(
        at,
        r,
        Paint()
          ..color =
              kMenuFlowerColors[rng.nextInt(kMenuFlowerColors.length)],
      );
    }
    canvas.restore();
  }

  void _ridge(
    Canvas canvas,
    Size size,
    double baseline,
    double amp,
    double cycles,
    Color color,
  ) {
    canvas.drawPath(
      _ridgePath(canvas, size, baseline, amp, cycles),
      Paint()..color = color,
    );
  }

  Path _ridgePath(
    Canvas canvas,
    Size size,
    double baseline,
    double amp,
    double cycles,
  ) {
    final path = Path()..moveTo(0, size.height);
    for (var x = 0.0; x <= size.width; x += 6) {
      final t = x / size.width * 2 * pi * cycles;
      path.lineTo(x, size.height * (baseline - amp * sin(t + cycles)));
    }
    return path
      ..lineTo(size.width, size.height)
      ..close();
  }

  /// The three shapes, drifting. In place of the coins a collecting game would
  /// float here: these are what the game is actually about.
  void _motes(Canvas canvas, Size size) {
    final rng = Random(21);
    for (var i = 0; i < kMenuMoteCount; i++) {
      // Two bands either side of the sun, up in the top half: the name holds
      // the left, the runner holds the bottom, the buttons hold the right, and
      // this is the air left over.
      final side = i.isEven ? 0.25 : 0.58;
      final at = Offset(
        size.width * (side + rng.nextDouble() * 0.09),
        size.height * (0.12 + rng.nextDouble() * 0.32),
      );
      final bob = sin((phase + i / kMenuMoteCount) * 2 * pi) * kMenuMoteBob;
      final kind = ShapeKind.values[i % ShapeKind.values.length];
      final colour = kTitleLetterColors[i % kTitleLetterColors.length];
      final r = kMenuMoteSize * (0.5 + rng.nextDouble() * 0.5);
      canvas.drawPath(
        shapePath(kind, at.translate(0, bob), r),
        Paint()..color = colour.withValues(alpha: kMenuMoteOpacity),
      );
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.phase != phase;
}
