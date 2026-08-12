import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';

import '../core/constants.dart';
import '../core/lane.dart';
import '../core/placeholder_art.dart';
import '../game/projection.dart';

/// One coin, sitting in a lane at a depth and spinning on the spot.
///
/// Projected every frame exactly like a wall, including the draw order, so a
/// coin still up the path passes behind the runner and one that has gone by
/// passes in front of it.
class Coin extends SpriteComponent {
  Coin({required this.lane, required ArtPack art, required this.z})
    : super(sprite: art.coin, anchor: Anchor.center) {
    // Staggered, so a trail does not flash edge on all together.
    _spin = z * kCoinSpinHz / kCoinSpacingZ;
    project();
  }

  final Lane lane;

  /// Distance up the path. Counts down to [kCoinCatchZ] as it arrives.
  double z;

  /// Each coin is settled against the runner exactly once. Settled covers both
  /// outcomes; [taken] is the one that counted.
  bool resolved = false;
  bool taken = false;

  double _spin = 0;

  void spin(double dt) => _spin += dt * kCoinSpinHz;

  /// Recomputes screen size, position and draw order from [z].
  void project() {
    final s = scaleAt(z);
    // Turning on the spot, faked by squeezing the width. Never quite to zero,
    // or the coin blinks out at every half turn.
    final turn = max(kCoinEdgeScale, (cos(_spin * 2 * pi)).abs());
    size.setValues(kCoinSize * s * turn, kCoinSize * s);
    position.setValues(
      sideXAt(lane.offset, z),
      groundYAt(z) - kCoinRiseY * s,
    );
    final wanted = depthPriority(z);
    if (priority != wanted) priority = wanted;

    // Faded in rather than popped in: a coin appearing from nothing at a fixed
    // distance is more distracting than one that was always there.
    if (!taken) {
      opacity = z <= kCoinSolidZ
          ? 1.0
          : ((kCoinAppearZ - z) / (kCoinAppearZ - kCoinSolidZ)).clamp(0.0, 1.0);
    }
  }

  /// Taken: fly up and fade rather than simply vanishing, so the eye follows
  /// it to the counter.
  void collect() {
    resolved = true;
    taken = true;
    add(
      MoveByEffect(
        Vector2(0, -kCoinRiseY * 0.5),
        EffectController(duration: kCoinCollectSeconds),
      ),
    );
    add(
      OpacityEffect.fadeOut(
        EffectController(duration: kCoinCollectSeconds),
        onComplete: removeFromParent,
      ),
    );
  }
}
