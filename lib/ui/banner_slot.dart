import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/ad_ids.dart';
import '../core/ads.dart';

/// The banner strip along the bottom of the menu.
///
/// Only on the menu. A landscape phone gives about 360 points of height and a
/// banner takes fifty of them; spending that during a run would either cover
/// the road or squeeze the shape pad, and this is a reflex game where the
/// bottom of the screen is where the player's thumbs are.
///
/// It takes up no room at all until an ad has actually loaded, so a failure to
/// fill leaves the menu exactly as it was rather than a grey gap where an
/// advert should be.
class BannerSlot extends StatefulWidget {
  const BannerSlot({super.key});

  @override
  State<BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<BannerSlot> {
  BannerAd? _ad;
  bool _loaded = false;

  bool _asked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Once. This fires again on things like a metrics change, and each call
    // would otherwise start another banner and leak the last one.
    if (_asked) return;
    _asked = true;
    unawaited(_load());
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  /// The plain 320x50 banner, not an adaptive one.
  ///
  /// Adaptive sounds better and was tried first, but the only sizes the SDK
  /// still offers are the *large* ones: on this phone that came back 90 points
  /// tall, a quarter of the usable height of a landscape screen, and the ad
  /// that filled it was a 468x60 leaderboard sitting across the bottom of a
  /// children's game. A fixed 50 is a known quantity - it can be laid over the
  /// scene without the layout having to move for it.
  Future<void> _load() async {
    if (!AdIds.isSupportedPlatform) return;
    // Wait for the SDK rather than test whether it happens to be up. The menu
    // is built well before start-up finishes, so checking would fail every
    // time and there would be nothing to ask again later.
    await Ads.init();
    if (!Ads.isReady || !mounted) return;

    final ad = BannerAd(
      adUnitId: AdIds.banner,
      size: AdSize.banner,
      request: Ads.request,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _ad = null;
            _loaded = false;
          });
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
