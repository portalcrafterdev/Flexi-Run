import 'dart:math';

import 'package:flame/components.dart';

import '../components/coin.dart';
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
  final List<Coin> _coins = <Coin>[];

  double _spawnT = kFirstSpawnDelay;

  /// Walls in play, furthest first. Read only: mutate through this class.
  List<Wall> get walls => _walls;

  /// Coins in play, furthest first. Read only: mutate through this class.
  List<Coin> get coins => _coins;

  void reset() {
    for (final wall in _walls) {
      wall.removeFromParent();
    }
    for (final coin in _coins) {
      coin.removeFromParent();
    }
    _walls.clear();
    _coins.clear();
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
    for (final coin in _coins) {
      coin
        ..z -= speed * dt
        ..spin(dt)
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
    _layTrail(wall, into);
  }

  /// A trail of coins arriving just ahead of the wall, wide at the far end and
  /// narrowing to the track the hole is over.
  ///
  /// Both halves matter. Spreading the early rows across all three tracks
  /// means there is gold to collect wherever the runner is standing, rather
  /// than one lane being the only place anything happens. Narrowing the last
  /// rows to the hole's own track keeps the trail a hint: follow it to the end
  /// and you are already in the right place when the wall arrives, with only
  /// the shape left to think about.
  ///
  /// Row 0 is nearest the wall and arrives last; the highest row arrives first.
  void _layTrail(Wall wall, Component into) {
    for (var i = 0; i < kCoinsPerTrail; i++) {
      final z = wall.z + kCoinLeadZ - i * kCoinSpacingZ;
      final spread = i >= kCoinsPerTrail - kCoinSpreadRows;
      for (final lane in Lane.values) {
        if (!spread && lane != wall.lane) continue;
        final coin = Coin(lane: lane, art: _art, z: z);
        _coins.add(coin);
        into.add(coin);
      }
    }
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
    _coins.removeWhere((coin) {
      if (coin.isRemoved) return true;
      // A collected coin is left alone: it is playing out its rise and fade,
      // and removes itself when that finishes.
      if (!coin.resolved && coin.z < kWallCullZ) {
        coin.removeFromParent();
        return true;
      }
      return false;
    });
  }
}
