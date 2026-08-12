import 'dart:async';
import 'dart:math' show max;
import 'dart:ui' show Color;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../components/burst.dart';
import '../components/clouds.dart';
import '../components/coin.dart';
import '../components/dust_emitter.dart';
import '../components/player.dart';
import '../components/road.dart';
import '../components/scenery.dart';
import '../components/wall.dart';
import '../core/audio.dart';
import '../core/constants.dart';
import '../core/lane.dart';
import '../core/level.dart';
import '../core/placeholder_art.dart';
import '../core/prefs.dart';
import '../core/shape_kind.dart';
import 'difficulty.dart';
import 'game_state.dart';
import 'screen_shake.dart';
import 'wall_field.dart';

export 'game_state.dart' show GameState, Overlays;

class ShapeShifterGame extends FlameGame {
  /// A plain camera, so the viewport is the whole canvas. The zoom is set in
  /// [onGameResize] instead of pinning a fixed resolution, which would
  /// letterbox the game on any screen that is not 16:9.
  ShapeShifterGame() : super(camera: CameraComponent());

  // Everything the UI layer watches.
  final ValueNotifier<int> score = ValueNotifier<int>(0);
  final ValueNotifier<int> lives = ValueNotifier<int>(kStartLevel.lives);
  final ValueNotifier<bool> shielded = ValueNotifier<bool>(false);

  /// The best on the level currently chosen, not across all of them.
  final ValueNotifier<int> highScore = ValueNotifier<int>(0);

  /// How hard the game is set to play. Chosen on the menu and fixed for the
  /// length of a run: changing it mid-run would make the score meaningless.
  final ValueNotifier<Level> level = ValueNotifier<Level>(kStartLevel);

  /// Coins taken this run. Counted apart from [score] deliberately: the score
  /// drives the difficulty ramp, so paying score for coins would tighten the
  /// wall spacing several times faster than it is tuned for.
  final ValueNotifier<int> coins = ValueNotifier<int>(0);
  final ValueNotifier<ShapeKind> activeShape = ValueNotifier<ShapeKind>(
    kStartShape,
  );
  final ValueNotifier<Lane> activeLane = ValueNotifier<Lane>(kStartLane);

  /// Whether the player has parked the run. Separate from Flame's own
  /// [paused] flag, which is the engine state this drives.
  final ValueNotifier<bool> pauseNotifier = ValueNotifier<bool>(false);

  /// What the game is doing, for widgets that live outside the Flame overlays
  /// and so cannot be switched on and off by the overlay manager.
  final ValueNotifier<GameState> stateNotifier = ValueNotifier<GameState>(
    GameState.menu,
  );

  final ScreenShake _shake = ScreenShake(_cameraHome());

  // Bound to onLoad: the art has to be rasterised before anything can be built.
  late final ArtPack _art;
  late final WallField _field;
  late final Road _road;
  late final Clouds _clouds;
  late final Scenery _scenery;
  late final Player _player;
  late final DustEmitter _dust;

  GameState _state = GameState.menu;
  int _cleanPasses = 0;
  int _streak = 0;
  double _hitT = 0;

  Player get player => _player;

  ArtPack get art => _art;

  /// Walls in play, furthest first.
  List<Wall> get walls => _field.walls;

  /// Coins in play, furthest first. Named apart from [coins], which is the
  /// running count the HUD watches.
  List<Coin> get coinsInPlay => _field.coins;

  /// Roadside props, in the fixed pool they are recycled through.
  List<SceneryItem> get scenery => _scenery.items;

  GameState get state => _state;

  set state(GameState value) {
    if (value == _state) return;
    _state = value;
    stateNotifier.value = value;
    _syncOverlays();
  }

  /// How fast the world comes at the runner, in depth units per second.
  double get speed =>
      _state == GameState.menu ? kMenuSpeed : speedFor(score.value);

  @override
  Color backgroundColor() => kSkyBottom;

  @override
  Future<void> onLoad() async {
    _art = await buildPlaceholderArt();
    _field = WallField(_art);
    _road = Road(_art);
    _clouds = Clouds(_art.clouds);
    _scenery = Scenery(_art);
    _player = Player(_art);
    _dust = DustEmitter();

    await world.addAll(<Component>[
      SpriteComponent(
        sprite: _art.sky,
        size: Vector2(kWorldW, kWorldH),
        priority: kPrioSky,
      ),
      _clouds,
      SpriteComponent(
        sprite: _art.hills,
        size: Vector2(kWorldW, kHillsH),
        position: Vector2(0, kHorizonY + kHillsOverlap - kHillsH),
        priority: kPrioHills,
      ),
      _road,
      ..._scenery.items,
      _dust,
      _player,
    ]);

    camera.viewfinder.position = _cameraHome();
    level.value = Prefs.level;
    highScore.value = Prefs.highScore(level.value);
    // The menu shows the world, not the runner: a character jogging on the
    // spot behind the title cards reads as something left running by mistake.
    _player.isVisible = false;
    _syncOverlays();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Cover the screen rather than fit inside it: scale by whichever axis
    // needs more and let the other overflow off the edges. Fitting would leave
    // bars on every phone that is not 16:9, which is most of them.
    camera.viewfinder
      ..zoom = max(size.x / kWorldW, size.y / kWorldH)
      ..position = _cameraHome();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _shake.apply(dt, camera.viewfinder.position);

    if (_state == GameState.gameOver) return;

    if (_state == GameState.hit) {
      // Freeze frame. The world holds still while the shake plays out.
      _hitT -= dt;
      if (_hitT <= 0) state = GameState.running;
      return;
    }

    final v = speed;
    _road.advance(v, dt);
    _clouds.advance(v, dt);
    _scenery.advance(v, dt);
    // No runner on screen, no footfalls to kick dust up.
    if (_player.isVisible) _dust.emit(v, dt);

    if (_state != GameState.running) return;

    _field.advance(
      speed: v,
      dt: dt,
      score: score.value,
      level: level.value,
      into: world,
    );
    _resolve(dt);
  }

  /// Switches level. Only legal outside a run, so a score can never be set
  /// under one set of rules and recorded under another.
  void chooseLevel(Level value) {
    if (_state == GameState.running || _state == GameState.hit) return;
    if (value == level.value) return;
    level.value = value;
    highScore.value = Prefs.highScore(value);
    unawaited(Prefs.setLevel(value));
  }

  void startRun() {
    _clearPause();
    score.value = 0;
    coins.value = 0;
    lives.value = level.value.lives;
    shielded.value = false;
    activeShape.value = kStartShape;
    activeLane.value = kStartLane;
    _cleanPasses = 0;
    _streak = 0;
    _hitT = 0;
    _shake.reset();
    _field.reset();
    _player.reset();
    _player.isVisible = true;
    state = GameState.running;
    unawaited(Audio.startMusic());
  }

  void goToMenu() {
    _clearPause();
    _field.reset();
    _player.reset();
    _player.isVisible = false;
    _road.reset();
    _clouds.reset();
    _scenery.reset();
    state = GameState.menu;
  }

  /// One tap, one morph. Instant, and legal during the hit freeze so a child
  /// who is mid-recovery is never locked out.
  void morph(ShapeKind kind) {
    if (!_acceptsInput) return;
    _player.morph(kind);
    activeShape.value = kind;
  }

  /// Steps the runner one track sideways, stopping at the edges.
  void stepLane(int direction) {
    if (!_acceptsInput) return;
    moveToLane(direction < 0 ? _player.lane.stepLeft : _player.lane.stepRight);
  }

  void moveToLane(Lane lane) {
    if (!_acceptsInput) return;
    _player.moveTo(lane);
    activeLane.value = lane;
  }

  /// A paused run still has its pad on screen under the panel, so the pause
  /// has to be checked here too or a tap beside the panel morphs the runner.
  bool get _acceptsInput =>
      !pauseNotifier.value &&
      (_state == GameState.running || _state == GameState.hit);

  /// Parks the run. Only meaningful mid-run: there is nothing to come back to
  /// from the menu or the game over screen.
  void requestPause() {
    if (pauseNotifier.value) return;
    if (_state != GameState.running && _state != GameState.hit) return;
    pauseNotifier.value = true;
    pauseEngine();
    unawaited(Audio.pauseMusic());
  }

  void resumePlay() {
    if (!pauseNotifier.value) return;
    pauseNotifier.value = false;
    resumeEngine();
    unawaited(Audio.resumeMusic());
  }

  void _clearPause() {
    if (!pauseNotifier.value) return;
    pauseNotifier.value = false;
    resumeEngine();
  }

  void shake(double amount) => _shake.add(amount);

  /// Where the camera sits when nothing is shaking it.
  static Vector2 _cameraHome() => Vector2(kWorldW / 2, kCameraCentreY);

  /// Coins are settled the moment they reach the runner's plane: taken if the
  /// runner is standing in that lane, missed otherwise. Missing costs nothing,
  /// so a coin trail is never a trap.
  void _collectCoins() {
    for (final coin in _field.coins) {
      if (coin.resolved || coin.z > kCoinCatchZ) continue;
      if (coin.lane != _player.lane) {
        coin.resolved = true;
        continue;
      }
      coin.collect();
      coins.value += 1;
      Audio.coin(coins.value);
    }
  }

  /// One test on depth, resolved exactly once per wall: a wall is settled the
  /// moment it reaches the runner's plane.
  void _resolve(double dt) {
    _collectCoins();
    for (final wall in _field.walls) {
      if (wall.resolved || wall.z > kWallHitZ) continue;

      if (_player.hasShield) {
        wall.resolved = true;
        _player.consumeShield();
        shielded.value = false;
        score.value += kScorePerWall;
        wall.shatter();
        shake(kShakeSmash);
        Audio.shieldSmash();
        continue;
      }

      if (wall.shape == _player.shape && wall.lane == _player.lane) {
        wall.resolved = true;
        score.value += kScorePerWall;
        _cleanPasses++;
        _streak++;
        _player.squeeze();
        world.add(
          sparkleBurst(Vector2(_player.position.x, kPlayerCentreY)),
        );
        Audio.pass(_streak);
        if (_cleanPasses % level.value.shieldEvery == 0) {
          _player.grantShield();
          shielded.value = true;
          Audio.shieldGranted();
        }
        continue;
      }

      // Wrong shape or wrong lane. Hold the verdict open for the level's
      // forgiveness window: small hands are late, and a tap or a nudge inside
      // it still counts as a clean pass.
      wall.graceT += dt;
      if (wall.graceT < level.value.forgiveSeconds) continue;
      wall.resolved = true;
      _applyPenalty(wall);
    }
  }

  /// The v1 rule: a wrong shape costs a life. If playtesting with children
  /// says that is too harsh, the fallback is a stumble that only slows the
  /// runner - swap the body of this one method and nothing else.
  void _applyPenalty(Wall wall) {
    _streak = 0;
    wall.shatter();
    shake(kShakeHit);
    _player.hitReact();

    // Still blinking from the last crash: the wall breaks but it is free.
    if (_player.isInvulnerable) return;

    lives.value -= 1;
    _player.setInvulnerable(kInvulnSeconds);
    Audio.hit();

    if (lives.value > 0) {
      _hitT = kHitFreezeSeconds;
      state = GameState.hit;
    } else {
      _gameOver();
    }
  }

  void _gameOver() {
    _streak = 0;
    if (score.value > highScore.value) highScore.value = score.value;
    unawaited(Prefs.setHighScore(level.value, score.value));
    Audio.gameOver();
    // The music keeps going under the game over screen; it only ducks for the
    // closing phrase. Cutting it dead reads as punishment.
    state = GameState.gameOver;
  }

  void _syncOverlays() {
    final wanted = Overlays.forState(_state);
    // Only touch overlays the host actually registered, so the game can also
    // be driven headlessly in tests.
    final registered = overlays.registeredOverlays.toSet();
    for (final name in Overlays.all) {
      if (!registered.contains(name)) continue;
      if (wanted.contains(name)) {
        overlays.add(name, priority: Overlays.priorityOf(name));
      } else {
        overlays.remove(name);
      }
    }
  }
}
