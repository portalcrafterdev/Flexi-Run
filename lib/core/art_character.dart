import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui';

import 'art_canvas.dart';
import 'constants.dart';
import 'shape_kind.dart';

// The runner, drawn as a lit object rather than a flat silhouette: a volume
// shade for the body, a gloss where the light lands, a rim along the shaded
// edge to lift it off the background, and occlusion where it meets the ground.

/// The runner, from behind: a shape-shaped blob of jelly.
///
/// No face, because you are following it up the path. The silhouette is the
/// whole point - it is what the player matches to the hole - so all of the
/// shading stays inside it and never softens the outline.
Future<ui.Image> paintSlime(ShapeKind kind) {
  return rasterize(kPlayerBodySize, kPlayerBodySize, kArtScaleSprite, (
    canvas,
    size,
  ) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = kPlayerHalf * kSlimeInset;
    final body = shapePath(kind, centre, radius);

    canvas
      ..drawPath(
        body,
        // See-through: the ground and the dust read faintly through the body,
        // which is the whole difference between jelly and plastic. The alpha
        // has to be baked into the gradient stops - a shader ignores the
        // paint's own colour, so setting it there would do nothing.
        volumeShade(
          centre,
          radius,
          kSlimeLightColor.withValues(alpha: kSlimeBodyAlpha),
          kSlimeMidColor.withValues(alpha: kSlimeBodyAlpha),
          kSlimeDeepColor.withValues(alpha: kSlimeBodyAlpha),
        ),
      )
      ..save()
      ..clipPath(body);

    _edgeTint(canvas, body, radius);
    _occlusion(canvas, centre, radius);
    _gloss(canvas, centre, radius);
    _rim(canvas, body, centre, radius);

    canvas
      ..restore()
      // Outside the clip, so the outline stays crisp at the silhouette edge.
      ..drawPath(body, strokeWith(kSlimeDeepColor, kSlimeStroke));
  });
}

/// A darker band just inside the outline.
///
/// Light travelling through jelly has furthest to go at the edges, so that is
/// where the colour piles up. Shading it the other way round - bright edge,
/// dark middle - is what makes a translucent thing look solid.
void _edgeTint(Canvas canvas, Path body, double radius) {
  canvas.drawPath(
    body,
    strokeWith(kSlimeEdgeTint, radius * kSlimeEdgeWidth * 2),
  );
}

/// Darkening where the body curves away at the bottom. Light does not reach
/// under a thing, and showing that is what stops it looking like a sticker.
void _occlusion(Canvas canvas, Offset centre, double radius) {
  canvas.drawRect(
    Rect.fromCenter(
      center: centre.translate(0, radius * 0.55),
      width: radius * 3,
      height: radius,
    ),
    Paint()
      ..shader = ui.Gradient.linear(
        centre.translate(0, radius * 0.05),
        centre.translate(0, radius),
        <Color>[const Color(0x00000000), kSlimeCoreShadow],
      ),
  );
}

/// The wet highlight. Two of them: a broad soft one where the light lands and
/// a small hard one inside it, which is what makes a surface read as glossy.
void _gloss(Canvas canvas, Offset centre, double radius) {
  final at = centre.translate(radius * kLightOffsetX, radius * kLightOffsetY);
  canvas
    ..drawOval(
      Rect.fromCenter(
        center: at,
        width: radius * kGlossRatio * 2.6,
        height: radius * kGlossRatio * 1.5,
      ),
      Paint()
        ..color = kSlimeGlossSmall
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    )
    ..drawOval(
      Rect.fromCenter(
        center: at.translate(-radius * 0.04, -radius * 0.04),
        width: radius * kGlossRatio * 1.1,
        height: radius * kGlossRatio * 0.62,
      ),
      fillWith(kSlimeGlossColor),
    );
}

/// A bright edge along the shaded side, as though the sky were behind it.
/// Cheap, and it separates the runner from whatever it is standing in front of.
///
/// Offset *against* the light: shifting the outline up and left leaves its
/// lower right arc inside the silhouette, which is the edge facing away from
/// the key light and so the one a rim would catch.
void _rim(Canvas canvas, Path body, Offset centre, double radius) {
  canvas
    ..save()
    ..translate(radius * kLightOffsetX * 0.2, radius * kLightOffsetY * 0.2)
    ..drawPath(body, strokeWith(kSlimeRimColor, kRimWidth))
    ..restore();
}

/// The shadow the runner casts on the path.
///
/// A separate sprite rather than part of the body, because it belongs to the
/// ground: it stays put while the body bobs above it.
Future<ui.Image> paintContactShadow() {
  const box = kPlayerBodySize;
  return rasterize(box, box * kContactShadowHeight * 2, kArtScaleSprite, (
    canvas,
    size,
  ) {
    softOval(
      canvas,
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * kContactShadowWidth,
        height: size.height * 0.6,
      ),
      kContactShadowColor,
      kContactShadowBlur,
    );
  });
}

/// A leg: a stubby limb with a foot at the bottom, shaded down its length.
Future<ui.Image> paintLeg() {
  return rasterize(kLegW, kLegLength, kArtScaleSprite, (canvas, size) {
    final footH = size.height * 0.34;
    final shin = Rect.fromLTWH(
      size.width * 0.2,
      0,
      size.width * 0.6,
      size.height - footH * 0.5,
    );
    final foot = Rect.fromLTWH(0, size.height - footH, size.width, footH);
    canvas
      ..drawRRect(
        RRect.fromRectXY(shin, size.width * 0.3, size.width * 0.3),
        faceShade(shin, kSlimeMidColor, kSlimeDeepColor),
      )
      ..drawOval(
        foot,
        volumeShade(
          foot.center,
          foot.width / 2,
          kSlimeMidColor,
          kSlimeFootColor,
          kSlimeFootColor,
        ),
      );
  });
}

/// An arm, drawn pointing right with the hand on the outer end. The left arm
/// is the same sprite flipped.
Future<ui.Image> paintArm() {
  return rasterize(kArmW, kArmH, kArtScaleSprite, (canvas, size) {
    final handR = size.height * 0.5;
    final upper = Rect.fromLTWH(
      0,
      size.height * 0.22,
      size.width - handR,
      size.height * 0.56,
    );
    final hand = Offset(size.width - handR, size.height / 2);
    canvas
      ..drawRRect(
        RRect.fromRectXY(upper, size.height * 0.28, size.height * 0.28),
        faceShade(upper, kSlimeMidColor, kSlimeDeepColor),
      )
      ..drawCircle(
        hand,
        handR,
        volumeShade(
          hand,
          handR,
          kSlimeMidColor,
          kSlimeFootColor,
          kSlimeFootColor,
        ),
      );
  });
}

/// The shield: a ring of light around the runner, with orbiting motes.
Future<ui.Image> paintShieldRing() {
  const box = kPlayerBodySize * kShieldRingScale;
  return rasterize(box, box, kArtScaleSprite, (canvas, size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - kShieldRingWidth;
    canvas
      // A soft bloom under the ring, so it glows instead of just outlining.
      ..drawCircle(
        centre,
        radius,
        strokeWith(kShieldColor.withValues(alpha: 0.35), kShieldRingWidth * 2.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      )
      ..drawCircle(centre, radius, strokeWith(kShieldColor, kShieldRingWidth));

    final tick = strokeWith(kShieldColor, kShieldRingWidth * 0.7);
    for (final angle in <double>[0.6, 2.2, 3.8, 5.4]) {
      canvas.drawCircle(
        centre + Offset(cos(angle), sin(angle)) * (radius * 1.12),
        kShieldRingWidth * 0.6,
        tick,
      );
    }
  });
}
