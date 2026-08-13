import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

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
      if (!data) failed.value = true;
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
