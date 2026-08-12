import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/constants.dart';

// Everything above the horizon.
//
// The old sky was a three stop gradient with a sun drawn on it, which is a
// backdrop rather than weather: nothing in it had a size, so nothing below it
// had a distance. This one is lit - broad wedges of light thrown across the
// whole frame from the sun - and it has things in it you can judge a scale by.

/// Deep overhead, bright through the middle, warm where it meets the ground.
void paintSky(Canvas canvas, Size size) {
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height * kMenuHorizon),
        const <Color>[kMenuSkyTop, kMenuSkyMid, kMenuSkyLow, kMenuSkyWarm],
        const <double>[0, 0.45, 0.78, 1],
      ),
  );
}

/// Where the light is coming from. Everything else in the sky is drawn around
/// it, so it is worth having in one place.
Offset sunAt(Size size) =>
    Offset(size.width * kMenuSunX, size.height * kMenuSunY);

double sunRadius(Size size) => size.height * kMenuSunR;

/// Long wedges of light fanning out from the sun across the whole sky.
///
/// Very low alpha, and drawn as one path rather than eighteen: they are meant
/// to be felt as a direction rather than counted. This is what fills the
/// corners a vertical gradient always leaves flat.
void paintSunburst(Canvas canvas, Size size) {
  final at = sunAt(size);
  // Long enough to leave the frame from wherever the sun happens to sit.
  final reach = size.width + size.height;
  final wedge = pi / kMenuBurstCount;
  final fan = Path();
  for (var i = 0; i < kMenuBurstCount; i += 2) {
    final a = i * wedge + kMenuBurstTurn;
    fan
      ..moveTo(at.dx, at.dy)
      ..lineTo(at.dx + cos(a) * reach, at.dy + sin(a) * reach)
      ..lineTo(at.dx + cos(a + wedge) * reach, at.dy + sin(a + wedge) * reach)
      ..close();
  }
  canvas
    ..save()
    ..clipRect(Offset.zero & size)
    ..drawPath(fan, Paint()..color = kMenuBurstColor)
    ..restore();
}

/// The sun itself: a bloom, a ring of short rays, and the disc.
void paintSun(Canvas canvas, Size size) {
  final at = sunAt(size);
  final r = sunRadius(size);

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

/// Specks of light, thickest up where the sky is deepest.
void paintSparkles(Canvas canvas, Size size) {
  final rng = Random(11);
  for (var i = 0; i < kMenuSparkleCount; i++) {
    final at = Offset(
      rng.nextDouble() * size.width,
      rng.nextDouble() * size.height * 0.55,
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

/// Clouds, kept in the strip of sky above everything the layout puts on top of
/// them, and out of the sun's column. A cloud half covered by the tagline, or
/// rising out from behind a level button, is the one thing on the screen that
/// looks unfinished - and one parked over the sun takes the light out of the
/// whole picture.
void paintClouds(Canvas canvas, Size size) {
  final rng = Random(5);
  for (final across in kMenuCloudXs) {
    final at = Offset(
      size.width * across,
      size.height * (kMenuCloudTop + rng.nextDouble() * kMenuCloudBand),
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

/// A hot air balloon: a striped envelope, two lines, and a basket.
///
/// [lift] bobs it. Drawn on the animated layer, because a balloon that never
/// moves is just a shape in the sky.
void paintBalloon(
  Canvas canvas,
  Size size,
  (double, double, double, int) spot,
  double lift,
) {
  final h = size.height * kMenuBalloonH * spot.$3;
  final w = h * 0.62;
  final top = Offset(size.width * spot.$1, size.height * spot.$2 + lift);
  final envelope = Rect.fromLTWH(top.dx - w / 2, top.dy, w, h * 0.72);
  final colour = kTitleLetterColors[spot.$4 % kTitleLetterColors.length];

  // The envelope is an oval that pinches to a point at the bottom, where the
  // ropes meet: an oval on its own reads as a ball on a string.
  final body = Path()
    ..addOval(envelope)
    ..moveTo(envelope.left + w * 0.22, envelope.bottom - h * 0.16)
    ..lineTo(top.dx, envelope.bottom + h * 0.08)
    ..lineTo(envelope.right - w * 0.22, envelope.bottom - h * 0.16)
    ..close();
  canvas.drawPath(body, Paint()..color = colour);

  // Two pale gores over the middle, which is what makes it read as a balloon
  // and not a bauble.
  canvas
    ..save()
    ..clipPath(body);
  for (final side in <double>[-1, 1]) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(envelope.center.dx + side * w * 0.24, envelope.center.dy),
        width: w * 0.2,
        height: h,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
  }
  canvas.restore();

  final basket = Rect.fromCenter(
    center: Offset(top.dx, envelope.bottom + h * 0.24),
    width: w * 0.3,
    height: h * 0.16,
  );
  canvas
    ..drawLine(
      Offset(basket.left, basket.top),
      Offset(envelope.left + w * 0.26, envelope.bottom - h * 0.1),
      Paint()
        ..color = kMenuBalloonBasket
        ..strokeWidth = max(1, h * 0.012),
    )
    ..drawLine(
      Offset(basket.right, basket.top),
      Offset(envelope.right - w * 0.26, envelope.bottom - h * 0.1),
      Paint()
        ..color = kMenuBalloonBasket
        ..strokeWidth = max(1, h * 0.012),
    )
    ..drawRRect(
      RRect.fromRectXY(basket, h * 0.03, h * 0.03),
      Paint()..color = kMenuBalloonBasket,
    );
}
