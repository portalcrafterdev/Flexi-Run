import 'dart:math';

import 'package:flame/components.dart';

import '../components/wall.dart';
import '../core/constants.dart';
import '../core/lane.dart';
import '../core/placeholder_art.dart';
import '../core/shape_kind.dart';
import 'difficulty.dart';

/// The barriers coming down the path.
///
/// Owns the spawn timer, the shape picker and the culling, so the game itself
/// is left with the rules rather than the bookkeeping.
class WallField {
  WallField(this._art, {Random? random})
    : _picker = ShapePicker(random: random),
      _lanes = LanePicker(random: random);

  final ArtPack _art;
  final ShapePicker _picker;
  final LanePicker _lanes;
  final List<Wall> _walls = <Wall>[];

  double _spawnT = kFirstSpawnDelay;

  /// Walls in play, furthest first. Read only: mutate through this class.
  List<Wall> get walls => _walls;

  void reset() {
    for (final wall in _walls) {
      wall.removeFromParent();
    }
    _walls.clear();
    _picker.reset();
    _lanes.reset();
    _spawnT = kFirstSpawnDelay;
  }

  /// Brings every wall one frame closer, spawning and culling as needed.
  void advance({
    required double speed,
    required double dt,
    required int score,
    required Component into,
  }) {
    for (final wall in _walls) {
      wall
        ..z -= speed * dt
        ..project();
    }

    _spawnT -= dt;
    if (_spawnT <= 0) {
      _spawn(into);
      _spawnT = gapFor(score);
    }

    _cull();
  }

  void _spawn(Component into) {
    final wall = Wall(
      shape: _picker.next(),
      lane: _lanes.next(),
      art: _art,
      z: kWallSpawnZ,
    );
    _walls.add(wall);
    into.add(wall);
  }

  void _cull() {
    _walls.removeWhere((wall) {
      if (wall.isRemoved) return true;
      if (wall.z < kWallCullZ) {
        wall.removeFromParent();
        return true;
      }
      return false;
    });
  }
}
