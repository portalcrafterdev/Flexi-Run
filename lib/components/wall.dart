import 'package:flame/components.dart';

import '../core/constants.dart';
import '../core/lane.dart';
import '../core/placeholder_art.dart';
import '../core/shape_kind.dart';
import '../game/projection.dart';
import 'burst.dart';

/// A barrier across the path with a shape-shaped hole punched through it.
///
/// It lives at a depth [z] and is projected every frame: small and high up the
/// path when it spawns, growing until it reaches the runner. Its draw order
/// comes from that same depth, so it passes behind the runner on approach and
/// in front of it on the way through. That flip is what makes the bricks
/// occlude the body and leave only the part inside the hole visible.
class Wall extends SpriteComponent {
  Wall({
    required this.shape,
    required this.lane,
    required ArtPack art,
    required this.z,
  }) : _shard = art.shard,
       super(sprite: art.wall(shape, lane), anchor: Anchor.bottomCenter) {
    project();
  }

  final ShapeKind shape;

  /// Which track the hole is punched over. The runner has to be standing in
  /// this one, wearing [shape], to get through.
  final Lane lane;

  final Sprite _shard;

  /// Distance up the path. Counts down to [kWallHitZ] as the wall arrives.
  double z;

  /// Each wall is resolved against the runner exactly once.
  bool resolved = false;

  /// How long the runner has been inside this wall wearing the wrong shape.
  double graceT = 0;

  /// Recomputes screen size, position, draw order and fade from [z].
  void project() {
    final s = scaleAt(z);
    size.setValues(kWallW * s, kWallH * s);
    position.setValues(laneXAt(z), groundYAt(z));
    final wanted = depthPriority(z);
    if (priority != wanted) priority = wanted;

    // Past the runner a wall would otherwise fill the screen with brick for
    // half a second, which is disorienting. Fade it as it sweeps by.
    opacity = z >= kWallHitZ
        ? 1.0
        : ((z - kWallCullZ) / (kWallHitZ - kWallCullZ)).clamp(0.0, 1.0);
  }

  void shatter() {
    parent?.add(
      brickShards(Vector2(laneXAt(z), groundYAt(z) - size.y / 2), _shard),
    );
    removeFromParent();
  }
}
