import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';
import 'constants.dart';

/// AdMob front end.
///
/// Every call is guarded the same way [Audio] is: if the SDK never came up, if
/// there is no network, or if a unit has no fill, the whole class degrades to
/// a no-op rather than blocking the game. Nothing here is allowed to be the
/// reason a child cannot press PLAY.
///
/// The two full-screen formats are always loaded ahead of the moment they are
/// wanted. Asking for an interstitial and then waiting for it to download is
/// how a game ends up with a two second stall on the button that starts it.
class Ads {
  Ads._();

  static bool _ready = false;
  static InterstitialAd? _interstitial;
  static RewardedAd? _rewarded;

  /// Runs completed since the last interstitial, so one does not appear
  /// between every single attempt.
  static int _runsSinceInterstitial = 0;

  /// Non-personalised, G rated, tagged as directed at children.
  ///
  /// This is the whole reason ads in this game need care. The players are six
  /// to ten, which puts the app under COPPA and Google Play's Families policy:
  /// requests have to be tagged child-directed, no behavioural profile may be
  /// built, and the content has to be rated for general audiences. These flags
  /// are the app's half of that. The other half is the AdMob console, where
  /// the app itself must also be marked as child-directed.
  static const AdRequest _request = AdRequest(nonPersonalizedAds: true);

  /// The same request the full-screen formats use, for the banner widget.
  /// Shared rather than rebuilt so the child-directed settings cannot end up
  /// applied to two of the three placements.
  static AdRequest get request => _request;

  /// The one and only start-up, cached so anything that needs the SDK can
  /// await it instead of guessing whether it has happened yet.
  ///
  /// The banner used to lose this race every time: the menu is built long
  /// before the SDK finishes starting, so [isReady] was false, the slot gave
  /// up, and nothing ever asked it again.
  static Future<void>? _starting;

  static Future<void> init() => _starting ??= _init();

  static Future<void> _init() async {
    if (!AdIds.isSupportedPlatform) return;
    try {
      await MobileAds.instance.initialize();
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          // One setting now, replacing the old pair of child-directed and
          // under-age-of-consent flags. Google treats setting it as a
          // certification that it is accurate, which for a game aimed at six
          // to ten year olds it plainly is.
          ageRestrictedTreatment: AgeRestrictedTreatment.child,
          maxAdContentRating: MaxAdContentRating.g,
        ),
      );
      _ready = true;
      _loadInterstitial();
      _loadRewarded();
    } catch (_) {
      _ready = false;
    }
  }

  static bool get isReady => _ready;

  /// Whether there is a rewarded ad in hand right now.
  ///
  /// The extra life button is only offered when this is true. Offering a
  /// reward and then failing to produce one is worse than never offering it,
  /// especially to a child who has just lost their last life.
  static bool get hasExtraLifeAd => _rewarded != null;

  static void _loadInterstitial() {
    if (!_ready || _interstitial != null) return;
    try {
      InterstitialAd.load(
        adUnitId: AdIds.interstitial,
        request: _request,
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) => _interstitial = ad,
          // No retry loop. A failed load means no ad this time, and a game
          // that keeps hammering a failing unit burns battery for nothing.
          onAdFailedToLoad: (_) => _interstitial = null,
        ),
      );
    } catch (_) {
      _interstitial = null;
    }
  }

  static void _loadRewarded() {
    if (!_ready || _rewarded != null) return;
    try {
      RewardedAd.load(
        adUnitId: AdIds.rewarded,
        request: _request,
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) => _rewarded = ad,
          onAdFailedToLoad: (_) => _rewarded = null,
        ),
      );
    } catch (_) {
      _rewarded = null;
    }
  }

  /// Starts a run, opening with an interstitial when one is due.
  ///
  /// The single door every run goes through, so the pacing cannot be counted
  /// twice or skipped depending on which button was pressed. [start] runs
  /// whether or not an ad appeared: an ad failing is never a reason a child
  /// cannot play.
  static Future<void> beforeRun(void Function() start) async {
    if (_shouldShowInterstitial()) await showInterstitial();
    start();
  }

  /// Counts a run and says whether this one should open with an interstitial.
  ///
  /// Not every run. A six year old's run can be over in fifteen seconds, and
  /// an ad between every one of them turns the game into a slideshow - they
  /// stop playing rather than sit through it. The counter starts at zero, so
  /// the first run after launch never has one in front of it.
  static bool _shouldShowInterstitial() {
    _runsSinceInterstitial++;
    return _ready &&
        _interstitial != null &&
        _runsSinceInterstitial >= kRunsPerInterstitial;
  }

  /// The run counter, for tests and for the pacing to be checkable at all.
  static int get runsSinceInterstitial => _runsSinceInterstitial;

  /// Shows the interstitial and waits for it to be dismissed.
  ///
  /// Returns as soon as the ad is gone either way. The caller starts the run
  /// afterwards, so a failure here just means the run starts immediately.
  static Future<void> showInterstitial() async {
    final ad = _interstitial;
    if (ad == null) return;
    _interstitial = null;
    _runsSinceInterstitial = 0;

    final gone = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (ad) => _finish(ad, gone, _loadInterstitial),
      onAdFailedToShowFullScreenContent: (ad, _) =>
          _finish(ad, gone, _loadInterstitial),
    );
    try {
      await ad.show();
      await gone.future;
    } catch (_) {
      _loadInterstitial();
    }
  }

  /// Shows the rewarded ad and reports whether it was watched far enough to
  /// earn the reward.
  ///
  /// False covers every way this can go wrong - no ad, failed to show, closed
  /// early - and the caller treats all of them the same: the run is over.
  static Future<bool> showExtraLifeAd() async {
    final ad = _rewarded;
    if (ad == null) return false;
    _rewarded = null;

    var earned = false;
    final gone = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (ad) => _finish(ad, gone, _loadRewarded),
      onAdFailedToShowFullScreenContent: (ad, _) =>
          _finish(ad, gone, _loadRewarded),
    );
    try {
      await ad.show(onUserEarnedReward: (_, _) => earned = true);
      await gone.future;
    } catch (_) {
      _loadRewarded();
      return false;
    }
    return earned;
  }

  /// Disposes a finished full-screen ad, releases whoever is waiting on it,
  /// and starts loading the next one.
  static void _finish(Ad ad, Completer<void> gone, void Function() reload) {
    ad.dispose();
    if (!gone.isCompleted) gone.complete();
    reload();
  }

  /// Forgets the run counter, for a fresh session or a test.
  static void resetPacing() => _runsSinceInterstitial = 0;
}
