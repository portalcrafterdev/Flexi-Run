import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

import 'games.dart';
import 'prefs.dart';
import 'save_data.dart';

/// Somewhere a save can be kept. Behind an interface so the merge can be
/// tested without a phone, and so a second backend could be dropped in without
/// touching anything that calls [CloudSave].
abstract class CloudStore {
  Future<String?> load(String name);
  Future<void> save(String name, String data);
  Future<void> delete(String name);
}

/// Play Games Saved Games - a snapshot kept against the player's account.
class PlayGamesStore implements CloudStore {
  const PlayGamesStore();

  @override
  Future<String?> load(String name) => SaveGame.loadGame(name: name);

  @override
  Future<void> save(String name, String data) async {
    await SaveGame.saveGame(data: data, name: name, description: kSaveLabel);
  }

  @override
  Future<void> delete(String name) async {
    await SaveGame.deleteGame(name: name);
  }
}

/// For tests, and for anything that wants a save that does not leave the room.
class MemoryCloudStore implements CloudStore {
  MemoryCloudStore([this._data]);

  String? _data;

  /// How many times a save was written, so a test can show that syncing twice
  /// does not keep rewriting the same thing.
  int writes = 0;

  int deletes = 0;

  String? get data => _data;

  @override
  Future<String?> load(String name) async => _data;

  @override
  Future<void> save(String name, String data) async {
    _data = data;
    writes++;
  }

  @override
  Future<void> delete(String name) async {
    _data = null;
    deletes++;
  }
}

/// Progress kept against the player's Play Games account.
///
/// The phone is the source of truth and the cloud is a copy of it. That order
/// matters: the game has to work with no signal and for a child who never
/// signs in, so nothing here is ever allowed to block a run or to be the only
/// place a score lives. Every failure is swallowed, because the worst case is
/// that the copy is out of date - never that the player lost anything.
abstract final class CloudSave {
  /// One slot. The game has a single line of progress, not save files.
  static const slot = 'flexirun_progress';

  @visibleForTesting
  static CloudStore? debugStore;

  static CloudStore get _store => debugStore ?? const PlayGamesStore();

  /// Only with an account, and only while the player still wants one.
  ///
  /// The disconnect button clears both, so a player who has let go of their
  /// account does not keep quietly uploading to it.
  static bool get isOn => Games.isSignedIn && !Prefs.gamesOptedOut;

  /// Whether a sync is already running, so two triggers do not overlap.
  static bool _busy = false;

  /// Watches for a sign-in and pulls progress down when one happens.
  ///
  /// The button is not enough. The platform hands an existing session straight
  /// back at launch, so on a NEW phone the player is simply signed in without
  /// ever pressing anything - and that is precisely the moment their progress
  /// needs fetching. Without this, carrying progress to a new phone would only
  /// work for somebody who happened to sign out and in again.
  static void watchSignIn() {
    Games.playerName.removeListener(_onPlayerChanged);
    Games.playerName.addListener(_onPlayerChanged);
    _onPlayerChanged();
  }

  /// Stops watching. The listener is static, so a test that leaves one on
  /// has it fire during the next test.
  static void stopWatching() =>
      Games.playerName.removeListener(_onPlayerChanged);

  static void _onPlayerChanged() {
    if (isOn) unawaited(sync());
  }

  /// Throws away the account's copy.
  ///
  /// Has to happen, and has to happen with the local clear rather than after
  /// it: the next sync merges the two, so clearing only the phone would see
  /// everything pulled straight back down and look like the button did
  /// nothing at all.
  static Future<void> wipe() async {
    if (!isOn) return;
    try {
      await _store.delete(slot);
    } catch (_) {
      // Nothing to delete, or no signal. The local clear still stands.
    }
  }

  /// Reads the cloud, joins it with this phone, and writes the result back.
  ///
  /// Always the full round trip, never a blind upload. Another phone may have
  /// played since, and an upload of local values alone would delete whatever
  /// it had done.
  static Future<void> sync() async {
    if (!isOn || _busy) return;
    _busy = true;
    try {
      final raw = await _store.load(slot);
      final cloud = SaveData.decode(raw);
      // Written by a newer version of the game than this one. Left exactly
      // where it is: writing back what this version understood would quietly
      // drop whatever it did not.
      if (cloud == null) return;

      final merged = SaveData.fromPrefs().mergedWith(cloud);
      await merged.applyToPrefs();
      if (merged.isEmpty) return;
      // Nothing changed on either side, so nothing to upload.
      if (merged == cloud) return;
      await _store.save(slot, merged.encode());
    } catch (_) {
      // No signal, Saved Games not switched on for the game, a quota, a
      // signed-out account. The phone still holds everything.
    } finally {
      _busy = false;
    }
  }
}

/// What the player sees beside the save in the Play Games app.
const kSaveLabel = 'Flexi Run progress';
