import 'package:shared_preferences/shared_preferences.dart';

import 'level.dart';

/// Local storage only. No accounts, no backend, no analytics in v1.
class Prefs {
  Prefs._();

  /// The old single best, from before there were levels.
  static const _kLegacyHighScore = 'high_score';

  static const _kSoundLevel = 'sound_level';
  static const _kMusicLevel = 'music_level';
  static const _kLevel = 'level';
  static const _kAwardsWon = 'awards_won';
  static const _kAwardsSynced = 'awards_synced';
  static const _kLifetimeCoins = 'lifetime_coins';

  static SharedPreferences? _prefs;

  /// Safe to skip: every getter falls back to its default when storage is
  /// unavailable, so tests and the first frame never block on disk.
  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } on Exception {
      _prefs = null;
    }
    await _carryLegacyHighScore();
  }

  /// Which level the player last chose.
  static Level get level {
    final stored = _prefs?.getString(_kLevel);
    if (stored == null) return kStartLevel;
    for (final level in Level.values) {
      if (level.name == stored) return level;
    }
    return kStartLevel;
  }

  static Future<void> setLevel(Level value) =>
      _prefs?.setString(_kLevel, value.name) ?? Future<void>.value();

  /// A best per level, because a score on Easy is not the same achievement as
  /// one on Hard and a single number would quietly let the easiest setting
  /// beat the hardest.
  static int highScore(Level level) => _prefs?.getInt(_key(level)) ?? 0;

  static Future<void> setHighScore(Level level, int value) async {
    if (value <= highScore(level)) return;
    await _prefs?.setInt(_key(level), value);
  }

  static String _key(Level level) => 'high_score_${level.name}';

  /// Moves a pre-levels best onto Medium, which is the tuning it was set on.
  ///
  /// Runs once: the old key is cleared, so a player who has been at this for
  /// weeks does not open the update to find their record gone.
  static Future<void> _carryLegacyHighScore() async {
    final legacy = _prefs?.getInt(_kLegacyHighScore);
    if (legacy == null) return;
    await setHighScore(Level.medium, legacy);
    await _prefs?.remove(_kLegacyHighScore);
  }

  /// Sound and music levels, 0 to 1. Zero is off, so a level replaces both the
  /// old on/off switch and a separate volume control with one thing to set.
  static double get soundLevel => _prefs?.getDouble(_kSoundLevel) ?? 1;

  static Future<void> setSoundLevel(double value) =>
      _prefs?.setDouble(_kSoundLevel, value.clamp(0, 1)) ??
      Future<void>.value();

  /// Achievements this device has earned, whether or not a store ever heard
  /// about them.
  ///
  /// Kept locally as well as pushed, because the two questions are different:
  /// a child playing signed out still earned the badge, and it should appear
  /// the moment they do sign in rather than having to be won all over again.
  static Set<String> get awardsWon => _read(_kAwardsWon);

  /// The subset a store has accepted. [awardsWon] minus this is the backlog.
  static Set<String> get awardsSynced => _read(_kAwardsSynced);

  static Future<void> addAwardsWon(Iterable<String> names) =>
      _add(_kAwardsWon, names);

  static Future<void> addAwardsSynced(Iterable<String> names) =>
      _add(_kAwardsSynced, names);

  static Set<String> _read(String key) =>
      (_prefs?.getStringList(key) ?? const <String>[]).toSet();

  static Future<void> _add(String key, Iterable<String> names) async {
    final merged = _read(key)..addAll(names);
    await _prefs?.setStringList(key, merged.toList()..sort());
  }

  /// Every coin collected on this device, across every run.
  ///
  /// The only lifetime total the game keeps. Coins are otherwise thrown away
  /// at the start of each run, which left nothing to hang a long achievement
  /// off at all.
  static int get lifetimeCoins => _prefs?.getInt(_kLifetimeCoins) ?? 0;

  static Future<int> addLifetimeCoins(int count) async {
    final total = lifetimeCoins + count;
    await _prefs?.setInt(_kLifetimeCoins, total);
    return total;
  }

  static double get musicLevel => _prefs?.getDouble(_kMusicLevel) ?? 1;

  static Future<void> setMusicLevel(double value) =>
      _prefs?.setDouble(_kMusicLevel, value.clamp(0, 1)) ??
      Future<void>.value();
}
