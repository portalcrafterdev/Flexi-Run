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
  }

  void _sky(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width / 2, 0),
          Offset(size.width / 2, size.height),
          const <Color>[kMenuSkyTop, kMenuSkyMid, kMenuSkyLow],
          const <double>[0, 0.55, 1],
        ),
    );
  }

  /// Up on the left, with soft rays. Same corner the world is lit from, so
  /// the menu and the game agree about where the light comes from. Kept well
  /// clear of the hills: a sun half swallowed by a ridge reads as a mistake.
  void _sun(Canvas canvas, Size size) {
    final at = Offset(size.width * 0.09, size.height * 0.21);
    final r = size.height * 0.11;

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
      final at = Offset(
        size.width * (0.08 + i * 0.27) + rng.nextDouble() * 30,
        size.height * (0.08 + rng.nextDouble() * 0.3),
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
      // Kept out of the middle where the cards are, off the top right where
      // the gear is, and below the sun.
      final side = i.isEven ? 0.04 : 0.82;
      final at = Offset(
        size.width * (side + rng.nextDouble() * 0.13),
        size.height * (0.38 + rng.nextDouble() * 0.36),
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
