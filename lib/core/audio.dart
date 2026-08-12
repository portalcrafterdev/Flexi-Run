import 'dart:async';

import 'package:flame_audio/flame_audio.dart';

import 'constants.dart';
import 'prefs.dart';

/// Sound effect and music front end.
///
/// Every call is guarded: until the real mp3 files land in assets/audio the
/// clips simply fail to load and the whole class degrades to a no-op rather
/// than crashing the game.
class Audio {
  Audio._();

  // Placeholder clips synthesised by tool/generate_placeholder_audio.dart.
  // Swapping in the commissioned mp3s is a change to these six names.
  static const _pass = 'pass.wav';
  static const _hit = 'hit.wav';
  static const _shield = 'shield.wav';
  static const _smash = 'smash.wav';
  static const _gameOver = 'gameover.wav';
  static const _tapClip = 'tap.wav';
  static const _music = 'music_loop.wav';

  static const _clips = <String>[_pass, _hit, _shield, _smash, _gameOver];

  /// Pitch rise per clean pass in a row, and the ceiling it stops at.
  static const _pitchStep = 0.06;
  static const _pitchMax = 1.6;

  /// Coins start above the pass chime so the two are never confused.
  static const _coinBaseRate = 1.25;

  /// The loudest the music is ever played, before the player's own level is
  /// applied. Music sits under the effects, never level with them.
  static const _musicHeadroom = 0.45;

  /// How far the music dips under a sound effect, as a share of its level.
  static const _duckShare = 0.4;
  static const _duckMs = 350;

  /// What the music should be playing at right now.
  static double get _musicVolume => _musicHeadroom * Prefs.musicLevel;

  static bool _sfxReady = false;
  static bool _musicReady = false;

  /// Effect players that are currently making a noise.
  ///
  /// Tracked so they can be silenced the instant the app leaves the screen.
  /// Every one of these is a platform-side player that carries on to the end
  /// of its clip on its own; nothing about the Flutter side going away stops
  /// it. Players remove themselves when their clip finishes, so this holds at
  /// most the handful of sounds actually in the air.
  static final Set<AudioPlayer> _effects = <AudioPlayer>{};

  /// Whether the app is off the screen.
  ///
  /// Backgrounding used to pause the music and leave the effects alone, which
  /// is how a coin taken in the last moment before the home button ended up
  /// chiming over the launcher. Nothing starts while this is set.
  static bool _offScreen = false;

  /// A ring of pre-built players for the tap click.
  ///
  /// Every other sound here creates a player when it fires, which is fine a
  /// couple of times a second. The tap fires on every button in the game and a
  /// child will happily drum on the shape pad, so it gets a pool: the players
  /// are made once and reused, instead of a new one per press.
  static AudioPool? _tapPool;

  /// When the last click was allowed through, in milliseconds since the epoch.
  /// Drumming faster than [kTapMinGapMs] is one press as far as the ear is
  /// concerned, and every extra click is a platform call for nothing.
  static int _lastTapMs = 0;

  /// Whether the track is parked rather than stopped.
  ///
  /// Needed because a paused player reports itself as not playing, and "not
  /// playing" is otherwise indistinguishable from "never started" - so turning
  /// the music up during a pause would start the loop again over the top of a
  /// paused game.
  static bool _paused = false;

  static Timer? _duckTimer;

  static Future<void> init() async {
    try {
      await FlameAudio.audioCache.loadAll(_clips);
      _sfxReady = true;
    } catch (_) {
      _sfxReady = false;
    }
    // The ambient category honours the iOS silent switch.
    final context = AudioContext(
      iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    );
    try {
      await AudioPlayer.global.setAudioContext(context);
    } catch (_) {
      // Not every platform implements a global context.
    }
    try {
      // Given the same context as everything else, or the pool would build its
      // own players with the default one and the tap click would be the one
      // sound in the game that ignored a silenced iPhone.
      _tapPool = await FlameAudio.createPool(
        _tapClip,
        minPlayers: kTapPoolMin,
        maxPlayers: kTapPoolMax,
        audioContext: context,
      );
    } catch (_) {
      _tapPool = null;
    }
    try {
      await FlameAudio.bgm.initialize(audioContext: context);
      await FlameAudio.audioCache.load(_music);
      _musicReady = true;
    } catch (_) {
      _musicReady = false;
    }
  }

  static Future<void> _sfx(String clip, {double rate = 1.0}) async {
    if (!_sfxReady || _offScreen || Prefs.soundLevel <= 0) return;
    try {
      final player = await FlameAudio.play(clip, volume: Prefs.soundLevel);
      // This await is the other half of the problem. Starting a sound is a
      // round trip to the platform, so a coin taken in the last frame before
      // the home button lands here after the app has already gone - and would
      // start playing over whatever the player is looking at now.
      if (_offScreen) {
        await _silence(player);
        return;
      }
      _effects.add(player);
      // Release mode disposes the player itself when the clip ends; this is
      // only so the set does not grow for the length of a run.
      unawaited(
        player.onPlayerComplete.first
            .then((_) => _effects.remove(player))
            .catchError((_) => false),
      );
      if (rate != 1.0) await player.setPlaybackRate(rate);
    } catch (_) {
      // A missing or unplayable clip must never interrupt the run.
    }
  }

  /// Stops everything and refuses anything new, for when the app leaves the
  /// screen. The music is parked by the same call, so a backgrounded game
  /// cannot be making any noise at all.
  static Future<void> suspend() async {
    _offScreen = true;
    final playing = List<AudioPlayer>.of(_effects);
    _effects.clear();
    for (final player in playing) {
      await _silence(player);
    }
    await pauseMusic();
  }

  /// Lets sound back in. Separate from resuming the music, which depends on
  /// whether the player left the game parked.
  static void wake() => _offScreen = false;

  /// Whether sound is currently refused because the app is off the screen.
  static bool get isOffScreen => _offScreen;

  static Future<void> _silence(AudioPlayer player) async {
    try {
      await player.stop();
    } catch (_) {
      // Already finished, already released, or never really started.
    }
  }

  /// Soft chime whose pitch rises with the current clean-pass streak.
  static void pass(int streak) {
    final rate = (1.0 + streak * _pitchStep).clamp(1.0, _pitchMax);
    _duck();
    unawaited(_sfx(_pass, rate: rate));
  }

  static void hit() {
    _duck();
    unawaited(_sfx(_hit));
  }

  /// A coin, pitched up a step for each one taken in the current trail so a
  /// run of them climbs. Uses the pass chime for now; a coin of its own is on
  /// the list for when the real audio is commissioned.
  static void coin(int taken) {
    final rate = (_coinBaseRate + (taken % kCoinsPerTrail) * _pitchStep * 2)
        .clamp(1.0, _pitchMax);
    unawaited(_sfx(_pass, rate: rate));
  }

  static void shieldGranted() => unawaited(_sfx(_shield));

  static void shieldSmash() {
    _duck();
    unawaited(_sfx(_smash));
  }

  static void gameOver() {
    _duck();
    unawaited(_sfx(_gameOver));
  }

  /// The click a control makes when it is pressed.
  ///
  /// Fires on every button in the game. Deliberately quieter than the game's
  /// own sounds: it is confirmation that a press landed, not an event, and it
  /// must never compete with the chime for getting a wall right.
  static void tap() {
    final pool = _tapPool;
    if (pool == null || _offScreen || Prefs.soundLevel <= 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTapMs < kTapMinGapMs) return;
    _lastTapMs = now;
    unawaited(pool.start(volume: Prefs.soundLevel * kTapVolume));
  }

  /// A sample of the sound effects, for when the Sound bar moves.
  ///
  /// Without it the bar is silent until the next wall arrives, and a child
  /// dragging it has no way to tell what it did.
  static void preview() => unawaited(_sfx(_pass));

  /// Music work, run strictly one job at a time.
  ///
  /// This is the whole fix for the bar that killed the music. Every one of
  /// these is a round trip to a platform player, and the Music bar fires a
  /// fresh one on every step of a drag. Run loose they interleave: the stop
  /// from the moment the bar passed zero lands *after* the start from the
  /// moment it came back up, so the track is left stopped with nothing
  /// remaining to turn it on. Queued, the last thing the player did is the
  /// last thing that happens - and because each job reads the level when it
  /// runs rather than when it was queued, the bar's final position wins.
  static Future<void> _musicQueue = Future<void>.value();

  static Future<void> _queue(Future<void> Function() work) {
    final next = _musicQueue.then((_) => work()).catchError((_) {});
    _musicQueue = next;
    return next;
  }

  /// Applies the player's music level to whatever is already playing, and
  /// starts or stops the track if they have just crossed zero.
  static Future<void> applyMusicLevel() => _queue(_applyMusicLevel);

  // Each job below calls the private forms of the others, never the queued
  // ones: a queued job waiting on the queue it is already at the head of would
  // wait for itself.

  static Future<void> _applyMusicLevel() async {
    if (!_musicReady) return;
    if (Prefs.musicLevel <= 0) {
      await _stopMusic();
      return;
    }
    // Parked, not stopped: set the volume the track will come back at, and
    // leave it parked. Starting it here would play music over a paused game.
    if (_paused) {
      await _setMusicVolume(_musicVolume);
      return;
    }
    if (!FlameAudio.bgm.isPlaying) {
      await _startMusic();
      return;
    }
    await _setMusicVolume(_musicVolume);
  }

  static Future<void> startMusic() => _queue(_startMusic);

  static Future<void> _startMusic() async {
    if (!_musicReady || Prefs.musicLevel <= 0 || FlameAudio.bgm.isPlaying) {
      return;
    }
    try {
      await FlameAudio.bgm.play(_music, volume: _musicVolume);
      _paused = false;
    } catch (_) {
      _musicReady = false;
    }
  }

  static Future<void> stopMusic() => _queue(_stopMusic);

  static Future<void> _stopMusic() async {
    _paused = false;
    // Check readiness first: touching FlameAudio.bgm builds a platform-backed
    // player, which must not happen when audio never came up.
    if (!_musicReady || !FlameAudio.bgm.isPlaying) return;
    try {
      await FlameAudio.bgm.stop();
    } catch (_) {
      // Nothing to stop.
    }
  }

  static Future<void> pauseMusic() => _queue(_pauseMusic);

  static Future<void> _pauseMusic() async {
    if (!_musicReady || !FlameAudio.bgm.isPlaying) return;
    _paused = true;
    try {
      await FlameAudio.bgm.pause();
    } catch (_) {
      // Nothing to pause.
    }
  }

  static Future<void> resumeMusic() => _queue(_resumeMusic);

  static Future<void> _resumeMusic() async {
    if (!_musicReady) return;
    // Turned off while the game was parked: there is nothing to come back to,
    // and the level is what decides that, not the pause.
    if (Prefs.musicLevel <= 0) {
      await _stopMusic();
      return;
    }
    _paused = false;
    try {
      await FlameAudio.bgm.resume();
      await _setMusicVolume(_musicVolume);
      // A resume on a player that was stopped rather than paused does nothing
      // at all, and leaves the game silent with no way back. Coming out of a
      // pause is exactly where that happens, so it is checked rather than
      // assumed.
      if (!FlameAudio.bgm.isPlaying) await _startMusic();
    } catch (_) {
      // Nothing to resume.
    }
  }

  /// Whether the track is parked. Exposed for the pause panel's tests: turning
  /// the music up mid-pause must not start it playing over the panel.
  static bool get isMusicParked => _paused;

  /// Dips the music under a sound effect, then lifts it back.
  static void _duck() {
    if (!_musicReady || !FlameAudio.bgm.isPlaying) return;
    _duckTimer?.cancel();
    unawaited(_setMusicVolume(_musicVolume * _duckShare));
    _duckTimer = Timer(
      const Duration(milliseconds: _duckMs),
      () => unawaited(_setMusicVolume(_musicVolume)),
    );
  }

  static Future<void> _setMusicVolume(double volume) async {
    try {
      await FlameAudio.bgm.audioPlayer.setVolume(volume);
    } catch (_) {
      // Volume is cosmetic; ignore.
    }
  }
}
