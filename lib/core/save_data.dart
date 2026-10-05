import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'level.dart';
import 'prefs.dart';

/// The progress worth carrying between phones, and the rules for joining two
/// copies of it together.
///
/// Pure on purpose: no platform, no storage of its own beyond reading and
/// writing [Prefs]. Everything that decides whether a child loses a score
/// lives here, where it can be tested without a device.
///
/// What is NOT here is as deliberate as what is. Sound and music levels, the
/// chosen level and the tutorial flags belong to the phone, not the player -
/// carrying the volume across to a new device is not progress, and a tutorial
/// marked seen on a parent's phone should still run on the child's.
@immutable
class SaveData {
  const SaveData({
    this.bestScores = const <String, int>{},
    this.coins = 0,
    this.awards = const <String>{},
  });

  /// Bumped when the shape changes. A save written by a NEWER version is left
  /// strictly alone rather than guessed at - see [decode].
  static const version = 1;

  /// Best score per level, keyed by [Level.name].
  final Map<String, int> bestScores;

  /// Lifetime coins.
  final int coins;

  /// Award names won, as [Prefs.awardsWon] holds them.
  final Set<String> awards;

  /// What this device currently holds.
  static SaveData fromPrefs() => SaveData(
    bestScores: <String, int>{
      for (final level in Level.values) level.name: Prefs.highScore(level),
    },
    coins: Prefs.lifetimeCoins,
    awards: Prefs.awardsWon,
  );

  String encode() => jsonEncode(<String, Object?>{
    'v': version,
    'best': bestScores,
    'coins': coins,
    'awards': awards.toList()..sort(),
  });

  /// Reads a save, or null when it cannot be trusted.
  ///
  /// Null means "do not sync", never "start fresh". A save from a newer
  /// version of the game would be flattened into whatever this version happens
  /// to understand, and the difference would be lost the moment this device
  /// wrote back - so an unreadable save is left exactly where it is.
  static SaveData? decode(String? raw) {
    if (raw == null || raw.isEmpty) return const SaveData();
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      if (json['v'] != version) return null;

      final best = <String, int>{};
      final storedBest = json['best'];
      if (storedBest is Map) {
        for (final entry in storedBest.entries) {
          final value = entry.value;
          if (entry.key is String && value is int) {
            best[entry.key as String] = value;
          }
        }
      }
      final storedAwards = json['awards'];
      return SaveData(
        bestScores: best,
        coins: json['coins'] is int ? json['coins'] as int : 0,
        awards: storedAwards is List
            ? storedAwards.whereType<String>().toSet()
            : const <String>{},
      );
    } on FormatException {
      return null;
    }
  }

  /// Joins two copies, taking the best of each rather than the newest.
  ///
  /// The newest is the wrong answer every time: a child who got 200 on one
  /// phone and then 50 on another would have the 200 deleted by the later
  /// save. So scores take the higher, awards take both, and coins take the
  /// higher - NOT the sum, which would double the total on every single sync.
  SaveData mergedWith(SaveData other) {
    final best = Map<String, int>.of(bestScores);
    for (final entry in other.bestScores.entries) {
      final mine = best[entry.key] ?? 0;
      if (entry.value > mine) best[entry.key] = entry.value;
    }
    return SaveData(
      bestScores: best,
      coins: coins > other.coins ? coins : other.coins,
      awards: <String>{...awards, ...other.awards},
    );
  }

  /// Writes this into local storage.
  ///
  /// Every write here only ever raises a value, so applying a merge can never
  /// cost the device something it already had.
  Future<void> applyToPrefs() async {
    for (final level in Level.values) {
      final score = bestScores[level.name];
      if (score != null) await Prefs.setHighScore(level, score);
    }
    await Prefs.raiseLifetimeCoins(coins);
    await Prefs.addAwardsWon(awards);
  }

  /// Nothing worth uploading. A brand new install, in other words.
  bool get isEmpty =>
      coins == 0 &&
      awards.isEmpty &&
      bestScores.values.every((score) => score == 0);

  @override
  bool operator ==(Object other) =>
      other is SaveData &&
      other.coins == coins &&
      setEquals(other.awards, awards) &&
      mapEquals(other.bestScores, bestScores);

  @override
  int get hashCode => Object.hash(coins, awards.length, bestScores.length);

  @override
  String toString() =>
      'SaveData(best: $bestScores, coins: $coins, awards: ${awards.length})';
}
