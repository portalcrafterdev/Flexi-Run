import 'package:flame/sprite.dart';

import 'art_character.dart';
import 'art_flora.dart';
import 'art_wall.dart';
import 'constants.dart';
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
    required this.clouds,
    required this.hills,
    required this.trees,
    required this.bushes,
    required this.tuft,
    required this.shieldRing,
    required this.shard,
    required this.leg,
    required this.arm,
    required this.coin,
    required this.contactShadow,
    required this.slimeSprites,
    required this.wallSprites,
  });

  final Sprite sky;

  /// One tile of the drifting cloud band.
  final Sprite clouds;

  final Sprite hills;

  /// Several silhouettes of each, not one. A verge lined with the same tree
  /// over and over reads as wallpaper however well that tree is drawn.
  final List<Sprite> trees;
  final List<Sprite> bushes;

  final Sprite tuft;
  final Sprite shieldRing;
  final Sprite shard;
  final Sprite leg;
  final Sprite arm;
  final Sprite coin;

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
    clouds: Sprite(await paintClouds()),
    hills: Sprite(await paintHills()),
    trees: <Sprite>[
      for (var i = 0; i < kTreeShapes.length; i++)
        Sprite(await paintTree(i)),
    ],
    bushes: <Sprite>[
      for (var i = 0; i < kBushShapes.length; i++)
        Sprite(await paintBush(i)),
    ],
    tuft: Sprite(await paintTuft()),
    shieldRing: Sprite(await paintShieldRing()),
    shard: Sprite(await paintShard()),
    leg: Sprite(await paintLeg()),
    arm: Sprite(await paintArm()),
    coin: Sprite(await paintCoin()),
    contactShadow: Sprite(await paintContactShadow()),
    slimeSprites: slimes,
    wallSprites: walls,
  );
}
