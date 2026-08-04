import 'package:shared_preferences/shared_preferences.dart';

/// Local storage only. No accounts, no backend, no analytics in v1.
class Prefs {
  Prefs._();

  static const _kHighScore = 'high_score';
  static const _kSoundLevel = 'sound_level';
  static const _kMusicLevel = 'music_level';

  static SharedPreferences? _prefs;

  /// Safe to skip: every getter falls back to its default when storage is
  /// unavailable, so tests and the first frame never block on disk.
  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } on Exception {
      _prefs = null;
    }
  }

  static int get highScore => _prefs?.getInt(_kHighScore) ?? 0;

  static Future<void> setHighScore(int value) async {
    if (value <= highScore) return;
    await _prefs?.setInt(_kHighScore, value);
  }

  /// Sound and music levels, 0 to 1. Zero is off, so a level replaces both the
  /// old on/off switch and a separate volume control with one thing to set.
  static double get soundLevel => _prefs?.getDouble(_kSoundLevel) ?? 1;

  static Future<void> setSoundLevel(double value) =>
      _prefs?.setDouble(_kSoundLevel, value.clamp(0, 1)) ??
      Future<void>.value();

  static double get musicLevel => _prefs?.getDouble(_kMusicLevel) ?? 1;

  static Future<void> setMusicLevel(double value) =>
      _prefs?.setDouble(_kMusicLevel, value.clamp(0, 1)) ??
      Future<void>.value();
}
