import 'dart:io';

import 'package:flutter/foundation.dart';

/// AdMob unit IDs.
///
/// Kept out of constants.dart on purpose. That file is the game's tuning - the
/// numbers you change to make the game play differently - and these are
/// account configuration that happens to live in the binary. Mixing them up
/// means every ad change looks like a gameplay change in the history.
///
/// The app ID is not here: it goes in the Android manifest and the iOS
/// Info.plist, because the SDK reads it before any Dart runs.
class AdIds {
  AdIds._();

  /// Google's own test units. Every debug and profile build uses these.
  ///
  /// This is not a nicety. Requesting live ads from a development build, and
  /// especially tapping one, is what gets an AdMob account suspended for
  /// invalid traffic - and the account is worth more than the convenience of
  /// seeing the real thing while building.
  static const _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  static const _banner = 'ca-app-pub-8244651657160773/6796573678';
  static const _interstitial = 'ca-app-pub-8244651657160773/1975491834';
  static const _rewarded = 'ca-app-pub-8244651657160773/5483492005';

  /// Live units only in a release build. [kReleaseMode] is the compiler's own
  /// flag, so there is no way to ship a build that forgot to switch over.
  static String get banner => kReleaseMode ? _banner : _testBanner;
  static String get interstitial =>
      kReleaseMode ? _interstitial : _testInterstitial;
  static String get rewarded => kReleaseMode ? _rewarded : _testRewarded;

  /// The units above are the same on both stores. Kept as a single check so
  /// that stops being an assumption buried in three getters if it ever
  /// changes.
  static bool get isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);
}
