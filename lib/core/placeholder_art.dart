import 'package:flame/sprite.dart';

import 'art_character.dart';
import 'art_wall.dart';
import 'lane.dart';
import 'placeholder_bg.dart';
import 'shape_kind.dart';

/// Every sprite the world needs, in one bag.
///
/// Today the images are generated in code, lit from a single direction so the
/// pieces read as one scene. When the commissioned art arrives, only
/// [buildPlaceholderArt] is replaced with a loader that reads the PNGs - no
/// component changes.
class ArtPack {
  const ArtPack({
    required this.sky,
    required this.hills,
    required this.tree,
    required this.bush,
    required this.tuft,
    required this.shieldRing,
    required this.shard,
    required this.leg,
    required this.arm,
    required this.contactShadow,
    required this.slimeSprites,
    required this.wallSprites,
  });

  final Sprite sky;
  final Sprite hills;
  final Sprite tree;
  final Sprite bush;
  final Sprite tuft;
  final Sprite shieldRing;
  final Sprite shard;
  final Sprite leg;
  final Sprite arm;

  /// The blob of shade the runner stands on.
  final Sprite contactShadow;

  final Map<ShapeKind, Sprite> slimeSprites;

  /// One wall per shape per lane: the hole is punched at the lane's offset, so
  /// the barrier still spans the whole path whichever track it opens.
  final Map<(ShapeKind, Lane), Sprite> wallSprites;

  Sprite slime(ShapeKind kind) => slimeSprites[kind]!;

  Sprite wall(ShapeKind kind, Lane lane) => wallSprites[(kind, lane)]!;
}

Future<ArtPack> buildPlaceholderArt() async {
  final slimes = <ShapeKind, Sprite>{};
  final walls = <(ShapeKind, Lane), Sprite>{};
  for (final kind in ShapeKind.values) {
    slimes[kind] = Sprite(await paintSlime(kind));
    for (final lane in Lane.values) {
      walls[(kind, lane)] = Sprite(await paintWall(kind, lane));
    }
  }
  return ArtPack(
    sky: Sprite(await paintSky()),
    hills: Sprite(await paintHills()),
    tree: Sprite(await paintTree()),
    bush: Sprite(await paintBush()),
    tuft: Sprite(await paintTuft()),
    shieldRing: Sprite(await paintShieldRing()),
    shard: Sprite(await paintShard()),
    leg: Sprite(await paintLeg()),
    arm: Sprite(await paintArm()),
    contactShadow: Sprite(await paintContactShadow()),
    slimeSprites: slimes,
    wallSprites: walls,
  );
}
