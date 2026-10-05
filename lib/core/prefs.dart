import 'package:shared_preferences/shared_preferences.dart';

import 'level.dart';

/// Where this device remembers things.
///
/// Two kinds of thing live here, and they are kept apart on purpose.
///
/// PROGRESS - best scores, coins, badges - belongs to whoever earned it, so it
/// is stored under a profile. Without that, a score set while signed in stays
/// on screen after signing out, and the next person to sign in on the same
/// phone inherits it as their own.
///
/// SETTINGS - volume, the chosen level, whether the tutorial has been seen -
/// belong to the phone. Carrying the volume to a new device is not progress,
/// and a tutorial marked seen by a parent should still run for the child.
class Prefs {
  Prefs._();

  /// The old single best, from before there were levels.
  static const _kLegacyHighScore = 'high_score';

  /// Set once the progress keys have been moved under a profile.
  static const _kScoped = 'progress_scoped_v1';

  // Settings: one copy for the phone.
  static const _kSoundLevel = 'sound_level';
  static const _kMusicLevel = 'music_level';
  static const _kLevel = 'level';
  static const _kGamesOptedOut = 'games_opted_out';

  // Progress: one copy per profile. Never read directly - see [_scoped].
  static const _kAwardsWon = 'awards_won';
  static const _kAwardsSynced = 'awards_synced';
  static const _kLifetimeCoins = 'lifetime_coins';
  static const _kHighScore = 'high_score';

  /// Nobody signed in. A real profile all of its own, not an absence of one:
  /// a child who plays without an account still has progress, and it is still
  /// theirs when they come back to it.
  static const guest = 'guest';

  static SharedPreferences? _prefs;
  static String _profile = guest;

  /// Whose progress is being read and written.
  static String get profile => _profile;

  /// Switches whose progress the game is looking at.
  ///
  /// Nothing is copied or deleted - the other profile's keys simply stop being
  /// the ones in use, and are waiting untouched when it comes back.
  static void useProfile(String id) => _profile = id.isEmpty ? guest : id;

  /// Turns an account's identifier into something safe to put in a key.
  static String profileFor(String id) {
    final safe = id.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
    return safe.isEmpty ? guest : 'acct_$safe';
  }

  /// Safe to skip: every getter falls back to its default when storage is
  /// unavailable, so tests and the first frame never block on disk.
  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } on Exception {
      _prefs = null;
    }
    _profile = guest;
    await _carryIntoGuest();
    await _carryLegacyHighScore();
  }

  static String _scoped(String key) => '$key@$_profile';

  /// Moves progress that predates profiles into [guest].
  ///
  /// Runs once. Whoever earned it, it was earned on this phone with no account
  /// attached to it, so the signed-out profile is where it belongs - and that
  /// is also the profile the game opens on.
  static Future<void> _carryIntoGuest() async {
    final prefs = _prefs;
    if (prefs == null || (prefs.getBool(_kScoped) ?? false)) return;

    for (final level in Level.values) {
      final old = prefs.getInt('${_kHighScore}_${level.name}');
      if (old != null) {
        await prefs.setInt('${_kHighScore}_${level.name}@$guest', old);
        await prefs.remove('${_kHighScore}_${level.name}');
      }
    }
    final coins = prefs.getInt(_kLifetimeCoins);
    if (coins != null) {
      await prefs.setInt('$_kLifetimeCoins@$guest', coins);
      await prefs.remove(_kLifetimeCoins);
    }
    for (final key in <String>[_kAwardsWon, _kAwardsSynced]) {
      final names = prefs.getStringList(key);
      if (names != null) {
        await prefs.setStringList('$key@$guest', names);
        await prefs.remove(key);
      }
    }
    await prefs.setBool(_kScoped, true);
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

  /// Whether the player has disconnected their games account from this game.
  ///
  /// Remembered, because the platform session outlives the choice: without
  /// this the name would simply reappear on the next launch and the disconnect
  /// would look like it had not worked.
  static bool get gamesOptedOut => _prefs?.getBool(_kGamesOptedOut) ?? false;

  static Future<void> setGamesOptedOut(bool value) =>
      _prefs?.setBool(_kGamesOptedOut, value) ?? Future<void>.value();

  /// A best per level, because a score on Easy is not the same achievement as
  /// one on Hard and a single number would quietly let the easiest setting
  /// beat the hardest.
  static int highScore(Level level) => _prefs?.getInt(_levelKey(level)) ?? 0;

  static Future<void> setHighScore(Level level, int value) async {
    if (value <= highScore(level)) return;
    await _prefs?.setInt(_levelKey(level), value);
  }

  static String _levelKey(Level level) =>
      _scoped('${_kHighScore}_${level.name}');

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

  /// Achievements this profile has earned, whether or not a store ever heard
  /// about them.
  ///
  /// Kept locally as well as pushed, because the two questions are different:
  /// a child playing signed out still earned the badge, and it should appear
  /// the moment they do sign in rather than having to be won all over again.
  static Set<String> get awardsWon => _read(_scoped(_kAwardsWon));

  /// The subset a store has accepted. [awardsWon] minus this is the backlog.
  static Set<String> get awardsSynced => _read(_scoped(_kAwardsSynced));

  static Future<void> addAwardsWon(Iterable<String> names) =>
      _add(_scoped(_kAwardsWon), names);

  static Future<void> addAwardsSynced(Iterable<String> names) =>
      _add(_scoped(_kAwardsSynced), names);

  static Set<String> _read(String key) =>
      (_prefs?.getStringList(key) ?? const <String>[]).toSet();

  static Future<void> _add(String key, Iterable<String> names) async {
    final merged = _read(key)..addAll(names);
    await _prefs?.setStringList(key, merged.toList()..sort());
  }

  /// Every coin collected by this profile, across every run.
  ///
  /// The only lifetime total the game keeps. Coins are otherwise thrown away
  /// at the start of each run, which left nothing to hang a long achievement
  /// off at all.
  static int get lifetimeCoins => _prefs?.getInt(_scoped(_kLifetimeCoins)) ?? 0;

  /// Raises the total to [total], or leaves it alone when it is already
  /// higher.
  ///
  /// Only ever raises, so applying a merged save can never cost this profile
  /// coins it had already banked.
  static Future<void> raiseLifetimeCoins(int total) async {
    if (total <= lifetimeCoins) return;
    await _prefs?.setInt(_scoped(_kLifetimeCoins), total);
  }

  static Future<int> addLifetimeCoins(int count) async {
    final total = lifetimeCoins + count;
    await _prefs?.setInt(_scoped(_kLifetimeCoins), total);
    return total;
  }

  /// Throws away the progress of whoever is playing now.
  ///
  /// This profile only. Signing out and clearing does not touch the account's
  /// copy, and clearing while signed in does not touch the signed-out one -
  /// which is the whole point of them being separate.
  ///
  /// Settings are left alone: nobody asking to clear their progress means
  /// "and turn the music back up".
  static Future<void> clearProgress() async {
    final prefs = _prefs;
    if (prefs == null) return;
    for (final level in Level.values) {
      await prefs.remove(_levelKey(level));
    }
    await prefs.remove(_scoped(_kLifetimeCoins));
    await prefs.remove(_scoped(_kAwardsWon));
    await prefs.remove(_scoped(_kAwardsSynced));
  }

  static double get musicLevel => _prefs?.getDouble(_kMusicLevel) ?? 1;

  static Future<void> setMusicLevel(double value) =>
      _prefs?.setDouble(_kMusicLevel, value.clamp(0, 1)) ??
      Future<void>.value();
}
