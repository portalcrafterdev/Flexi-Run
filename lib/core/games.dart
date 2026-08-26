import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

import 'awards.dart';
import 'prefs.dart';

/// Google Play Games on Android, Game Center on iOS.
///
/// Guarded exactly like [Audio] and [Ads]: a game account is a nice-to-have,
/// not something the game needs. Play Services missing, a device signed out of
/// Google entirely, a Play Console project that has not been published yet -
/// all of them end here as "signed out", never as a broken menu.
///
/// Nothing signs in on its own. The platform reports an existing session at
/// launch if there is one, and past that it takes a press: a sign-in sheet
/// appearing unasked over a children's game is the kind of thing a parent
/// reasonably objects to.
class Games {
  Games._();

  /// The signed-in player's display name, or null when signed out.
  ///
  /// A notifier rather than a stream so the menu can rebuild off it directly,
  /// and so the state survives the panel being rebuilt.
  static final ValueNotifier<String?> playerName = ValueNotifier<String?>(null);

  /// Whether a sign-in is in flight. The button goes quiet while it is.
  static final ValueNotifier<bool> busy = ValueNotifier<bool>(false);

  /// Set when a sign-in was tried and did not work, so the menu can say so
  /// rather than looking like the button did nothing.
  static final ValueNotifier<bool> failed = ValueNotifier<bool>(false);

  static bool _watching = false;
  static StreamSubscription<PlayerData?>? _sub;

  /// Stands in for the platform check under test, which otherwise runs on a
  /// desktop host where the answer is always no and the button never renders.
  @visibleForTesting
  static bool? debugSupported;

  /// Only where there is something to sign in to.
  static bool get isSupported =>
      debugSupported ?? (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

  static bool get isSignedIn => playerName.value != null;

  /// What the platform's own account is called, for the button's label. Using
  /// the wrong one is the fastest way to look like a port of someone else's
  /// game.
  static String get serviceName {
    if (!isSupported) return 'Games';
    return Platform.isIOS ? 'Game Center' : 'Play Games';
  }

  /// Starts listening for an existing session. Does not prompt.
  static Future<void> init() async {
    if (!isSupported || _watching) return;
    _watching = true;
    try {
      _sub = GameAuth.player.listen(
        (data) {
          playerName.value = data?.displayName;
          if (data != null) failed.value = false;
        },
        // A stream error is just "no session"; it is not a reason to make the
        // player look at anything.
        onError: (_) => playerName.value = null,
      );
    } catch (_) {
      _watching = false;
    }
  }

  /// Signs in, showing the platform's own sheet. Returns whether it worked.
  static Future<bool> signIn() async {
    if (!isSupported || busy.value) return isSignedIn;
    busy.value = true;
    failed.value = false;
    try {
      await GameAuth.signIn();
      // signIn returns before the player stream has caught up, so the name is
      // read back rather than assumed.
      final data = await GameAuth.isSignedIn;
      if (!data) {
        failed.value = true;
      } else {
        // Hand over anything won while signed out. A child who has been
        // playing for a week should see their badges arrive on the first
        // sign-in, not have to earn them all over again.
        unawaited(flushPending());
      }
      return data;
    } catch (_) {
      // Play Services out of date, no Play Games project configured, the sheet
      // dismissed, no network. All the same to a six year old: it did not work
      // and the game carries on regardless.
      failed.value = true;
      return false;
    } finally {
      busy.value = false;
    }
  }

  /// Records everything [stats] earned, and the coins it added to the total.
  ///
  /// Safe to call on a run that has already been reported: the awards are a
  /// set, and the coin total is banked by the caller. Never throws and never
  /// blocks a run - a store being unreachable is not the player's problem.
  static Future<void> report(RunStats stats, {required int coins}) async {
    final won = awardsFor(stats).map((a) => a.name);
    await Prefs.addAwardsWon(won);
    final total = await Prefs.addLifetimeCoins(coins);
    await _push(total);
  }

  /// Sends anything earned but not yet accepted by a store, plus the current
  /// coin total. Called after a sign-in, so a backlog built up while signed
  /// out arrives all at once.
  static Future<void> flushPending() => _push(Prefs.lifetimeCoins);

  /// Whether a store will accept anything right now.
  ///
  /// [isSignedIn] reads the player stream, which lags a sign-in by a moment -
  /// so a flush fired the instant sign-in returned would find it still null
  /// and quietly drop the backlog. The notifier is the fast path; the
  /// platform is asked directly when it says no.
  static Future<bool> get _authed async {
    if (!isSupported) return false;
    if (isSignedIn) return true;
    try {
      return await GameAuth.isSignedIn;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _push(int coinTotal) async {
    if (!await _authed) return;

    final pending = Prefs.awardsWon.difference(Prefs.awardsSynced);
    final sent = <String>[];
    for (final name in pending) {
      final award = _byName(name);
      if (award == null || award == Award.coinHunter) continue;
      if (await _unlock(award)) sent.add(name);
    }
    if (sent.isNotEmpty) await Prefs.addAwardsSynced(sent);

    await _pushCoins(coinTotal);
  }

  static Future<bool> _unlock(Award award) async {
    try {
      await Achievements.unlock(
        achievement: Achievement(
          androidID: award.androidId,
          iOSID: award.iosId,
        ),
      );
      return true;
    } catch (_) {
      // Left out of the synced set, so the next run tries again.
      return false;
    }
  }

  /// Coin Hunter, the one incremental achievement.
  ///
  /// Pushed as an absolute total rather than a delta. `setSteps` never lowers
  /// existing progress and is idempotent, so a run reported twice - or a week
  /// of runs played signed out - lands on the right number instead of double
  /// counting the way `increment` would.
  static Future<void> _pushCoins(int total) async {
    final steps = total.clamp(0, kAwardCoinTarget);
    if (steps <= 0) return;
    final achievement = Achievement(
      androidID: Award.coinHunter.androidId,
      iOSID: Award.coinHunter.iosId,
      steps: steps,
      percentComplete: steps * 100 / kAwardCoinTarget,
    );
    try {
      // setSteps is Android only. Game Center has no incremental type, so on
      // iOS the same total goes up as a percentage instead.
      if (Platform.isAndroid) {
        await Achievements.setSteps(achievement: achievement);
      } else {
        await Achievements.unlock(achievement: achievement);
      }
    } catch (_) {
      // Retried on the next run, from the same absolute total.
    }
  }

  static Award? _byName(String name) {
    for (final award in Award.values) {
      if (award.name == name) return award;
    }
    // A badge retired between versions. Nothing to send, nothing to fix.
    return null;
  }

  /// Opens the platform's own achievements screen.
  static Future<void> showAchievements() async {
    if (!isSupported || !isSignedIn) return;
    try {
      await Achievements.showAchievements();
    } catch (_) {
      // The player pressed a button and nothing happened. Better than a
      // crash, and there is nothing useful to say about it.
    }
  }

  /// For tests, which have no platform channel to listen to.
  @visibleForTesting
  static void reset() {
    _sub?.cancel();
    _sub = null;
    _watching = false;
    debugSupported = null;
    playerName.value = null;
    busy.value = false;
    failed.value = false;
  }
}
