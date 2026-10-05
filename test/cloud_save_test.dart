import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flexirun/core/cloud_save.dart';
import 'package:flexirun/core/games.dart';
import 'package:flexirun/core/level.dart';
import 'package:flexirun/core/prefs.dart';
import 'package:flexirun/core/save_data.dart';

// Progress carried between phones.
//
// Every test here is about the one way this feature can hurt somebody: taking
// something off them. A child who played on one phone and then another must
// end up with the best of both, never the newest of the two.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs.init();
  });

  tearDown(() {
    CloudSave.stopWatching();
    CloudSave.debugStore = null;
    Games.debugSupported = null;
    Games.playerName.value = null;
  });

  void signedIn() {
    Games.debugSupported = true;
    Games.playerName.value = 'Sam';
  }

  group('joining two phones', () {
    test('keeps the higher score, not the newer one', () {
      // The whole point. A later save holding 50 must not delete an earlier
      // 200 - that is a child watching their best run disappear.
      const old = SaveData(bestScores: <String, int>{'easy': 200});
      const recent = SaveData(bestScores: <String, int>{'easy': 50});

      expect(recent.mergedWith(old).bestScores['easy'], 200);
      expect(old.mergedWith(recent).bestScores['easy'], 200);
    });

    test('keeps every badge from both', () {
      const here = SaveData(awards: <String>{'first_run', 'ten_in_a_row'});
      const there = SaveData(awards: <String>{'first_run', 'the_long_run'});

      expect(here.mergedWith(there).awards, <String>{
        'first_run',
        'ten_in_a_row',
        'the_long_run',
      });
    });

    test('takes the higher coin total rather than adding them up', () {
      // Adding would double the total on every sync, which turns a counter
      // into a fountain.
      const here = SaveData(coins: 120);
      const there = SaveData(coins: 80);

      expect(here.mergedWith(there).coins, 120);
      expect(there.mergedWith(here).coins, 120);
    });

    test('a level only one phone has played still arrives', () {
      const here = SaveData(bestScores: <String, int>{'easy': 30});
      const there = SaveData(bestScores: <String, int>{'hard': 90});

      final merged = here.mergedWith(there);
      expect(merged.bestScores['easy'], 30);
      expect(merged.bestScores['hard'], 90);
    });
  });

  group('reading a save', () {
    test('survives a round trip', () {
      const data = SaveData(
        bestScores: <String, int>{'easy': 10, 'hard': 70},
        coins: 42,
        awards: <String>{'first_run'},
      );
      expect(SaveData.decode(data.encode()), data);
    });

    test('an empty slot is a fresh start, not a refusal', () {
      expect(SaveData.decode(null)?.isEmpty, isTrue);
      expect(SaveData.decode('')?.isEmpty, isTrue);
    });

    test('rubbish is refused rather than read as empty', () {
      // Refused matters: treating it as empty would upload this phone's data
      // over whatever was really there.
      expect(SaveData.decode('not json at all'), isNull);
      expect(SaveData.decode('[1,2,3]'), isNull);
    });

    test('a save from a newer game is refused', () {
      expect(SaveData.decode('{"v":99,"coins":5}'), isNull);
    });
  });

  group('syncing', () {
    test('does nothing at all while signed out', () async {
      final store = MemoryCloudStore();
      CloudSave.debugStore = store;
      await Prefs.setHighScore(Level.easy, 40);

      await CloudSave.sync();

      expect(store.data, isNull, reason: 'uploaded without an account');
    });

    test('does nothing after the player disconnects', () async {
      // The disconnect button must stop this too, or progress keeps flowing to
      // an account they have just let go of.
      signedIn();
      final store = MemoryCloudStore();
      CloudSave.debugStore = store;
      await Prefs.setGamesOptedOut(true);
      await Prefs.setHighScore(Level.easy, 40);

      await CloudSave.sync();

      expect(store.data, isNull);
    });

    test('uploads what this phone has', () async {
      signedIn();
      final store = MemoryCloudStore();
      CloudSave.debugStore = store;
      await Prefs.setHighScore(Level.easy, 40);
      await Prefs.addLifetimeCoins(7);

      await CloudSave.sync();

      final uploaded = SaveData.decode(store.data)!;
      expect(uploaded.bestScores['easy'], 40);
      expect(uploaded.coins, 7);
    });

    test('brings down what another phone did', () async {
      signedIn();
      const elsewhere = SaveData(
        bestScores: <String, int>{'hard': 310},
        coins: 90,
        awards: <String>{'top_of_the_hill'},
      );
      CloudSave.debugStore = MemoryCloudStore(elsewhere.encode());

      await CloudSave.sync();

      expect(Prefs.highScore(Level.hard), 310);
      expect(Prefs.lifetimeCoins, 90);
      expect(Prefs.awardsWon, contains('top_of_the_hill'));
    });

    test('never lowers what this phone already had', () async {
      signedIn();
      await Prefs.setHighScore(Level.easy, 500);
      await Prefs.addLifetimeCoins(200);
      CloudSave.debugStore = MemoryCloudStore(
        const SaveData(
          bestScores: <String, int>{'easy': 10},
          coins: 3,
        ).encode(),
      );

      await CloudSave.sync();

      expect(Prefs.highScore(Level.easy), 500);
      expect(Prefs.lifetimeCoins, 200);
    });

    test('leaves a save it cannot read exactly where it is', () async {
      // Written by a newer version. Overwriting it would drop whatever that
      // version knew and this one does not.
      signedIn();
      final store = MemoryCloudStore('{"v":99,"coins":5}');
      CloudSave.debugStore = store;
      await Prefs.setHighScore(Level.easy, 40);

      await CloudSave.sync();

      expect(store.data, '{"v":99,"coins":5}');
      expect(store.writes, 0);
    });

    test('a failing cloud costs the player nothing', () async {
      signedIn();
      CloudSave.debugStore = _BrokenStore();
      await Prefs.setHighScore(Level.easy, 40);

      await expectLater(CloudSave.sync(), completes);
      expect(Prefs.highScore(Level.easy), 40);
    });

    test('a fresh install uploads nothing', () async {
      // No point putting an empty save against the account, and it would be
      // the one thing that could overwrite a real one.
      signedIn();
      final store = MemoryCloudStore();
      CloudSave.debugStore = store;

      await CloudSave.sync();

      expect(store.writes, 0);
    });

    test('a session handed back at launch still pulls progress', () async {
      // The new-phone case, and the one the button cannot cover: the platform
      // reports an existing session by itself, so nobody ever presses sign in.
      // Without a watcher, progress would only ever arrive for a player who
      // happened to sign out and back in again.
      const elsewhere = SaveData(
        bestScores: <String, int>{'medium': 640},
        coins: 55,
      );
      CloudSave.debugStore = MemoryCloudStore(elsewhere.encode());
      Games.debugSupported = true;
      Games.playerName.value = null;

      CloudSave.watchSignIn();
      // As the player stream would, a moment after launch.
      Games.playerName.value = 'Sam';
      await Future<void>.delayed(Duration.zero);

      expect(Prefs.highScore(Level.medium), 640);
      expect(Prefs.lifetimeCoins, 55);
    });

    test('syncing twice in a row writes once', () async {

      signedIn();
      final store = MemoryCloudStore();
      CloudSave.debugStore = store;
      await Prefs.setHighScore(Level.easy, 40);

      await CloudSave.sync();
      await CloudSave.sync();

      expect(store.writes, 1, reason: 'uploaded the same save again');
    });
  });
}

/// Offline, or Saved Games not switched on for the game.
class _BrokenStore implements CloudStore {
  @override
  Future<String?> load(String name) async => throw Exception('no signal');

  @override
  Future<void> save(String name, String data) async =>
      throw Exception('no signal');

  @override
  Future<void> delete(String name) async => throw Exception('no signal');
}
