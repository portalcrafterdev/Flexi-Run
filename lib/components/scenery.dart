import 'dart:math';

import 'package:flame/components.dart';

import '../core/art_canvas.dart';
import '../core/constants.dart';
import '../core/placeholder_art.dart';
import '../game/projection.dart';

/// One roadside prop at a depth, projected like everything else.
class SceneryItem extends SpriteComponent {
  SceneryItem({required Sprite super.sprite, required this.z, required this.lateral})
    : super(anchor: Anchor.bottomCenter);

  double z;
  double lateral;

  void project() {
    final s = scaleAt(z);
    size.setValues(kSceneryBaseSize * s, kSceneryBaseSize * s);
    position.setValues(sideXAt(lateral, z), groundYAt(z));
    // Far scenery is washed toward the sky. Without it a tree at the horizon
    // is the same tree, only smaller, and the scene has no air in it.
    paint.colorFilter = hazeAt(z);
    final wanted = depthPriority(z);
    if (priority != wanted) priority = wanted;
  }
}

/// Trees and bushes along both verges.
///
/// A fixed pool: each prop that passes the camera is recycled to the far end
/// rather than allocated again, so a long run does not churn.
class Scenery {
  Scenery(ArtPack art, {Random? random})
    : _rng = random ?? Random(),
      _sprites = <Sprite>[...art.trees, ...art.bushes, art.tuft] {
    for (var i = 0; i < kSceneryCount; i++) {
      final item = SceneryItem(
        sprite: _sprites[i % _sprites.length],
        z: kMinDrawZ + i * (kScenerySpawnZ - kMinDrawZ) / kSceneryCount,
        lateral: _lateral(i.isEven),
      );
      item.project();
      items.add(item);
    }
  }

  final Random _rng;
  final List<Sprite> _sprites;
  final List<SceneryItem> items = <SceneryItem>[];

  void advance(double speed, double dt) {
    for (final item in items) {
      item.z -= speed * dt;
      if (item.z < kMinDrawZ) _recycle(item);
      item.project();
    }
  }

  void reset() {
    for (var i = 0; i < items.length; i++) {
      items[i]
        ..z = kMinDrawZ + i * (kScenerySpawnZ - kMinDrawZ) / items.length
        ..lateral = _lateral(i.isEven)
        ..project();
    }
  }

  void _recycle(SceneryItem item) {
    item
      ..z += kScenerySpawnZ - kMinDrawZ
      ..lateral = _lateral(_rng.nextBool())
      ..sprite = _sprites[_rng.nextInt(_sprites.length)];
  }

  /// Off the edge of the path, on one side or the other.
  double _lateral(bool left) {
    final offset = kSceneryLateral + _rng.nextDouble() * kSceneryLateralJitter;
    return left ? -offset : offset;
  }
}
