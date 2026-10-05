import 'package:flutter/widgets.dart';
import 'package:lottie/lottie.dart';

/// Everything about the hand animation that is a fact of the file, kept apart
/// from the widget that draws it so a test can check the facts without
/// building anything.
///
/// See assets/lottie/SOURCE.md. The delegates key on layer and group names and
/// the placement depends on a measured fingertip, so swapping the file for
/// another silently breaks both.
abstract final class HandArt {
  static const asset = 'assets/lottie/hand_tap.json';

  /// The composition, as authored.
  static const canvas = Size(600, 600);
  static const frameRate = 25;
  static const firstFrame = 0;
  /// As authored. Lottie reports 40.99 for it - one frame short by its own
  /// arithmetic - so the test compares loosely rather than for equality.
  static const lastFrame = 41;

  /// The frame the hand holds while pointing or sweeping.
  ///
  /// Zero, because the tap begins at frame 7 and the ripples do not exist
  /// before it - so frame 0 is the only pose that is both still and clean.
  static const restingFrame = 0;

  /// Where the fingertip sits inside the composition box, as a fraction of it.
  ///
  /// MEASURED, not derived. The fingertip is nowhere near the centre, so a
  /// hand centred on its target points well below it. Deriving this through
  /// the parent transform chain is unreliable, and measuring the bare file is
  /// wrong the moment the stroke width changes - because that moves the outer
  /// edge. test/hand_art_test.dart re-measures it and fails if it drifts.
  static const hotspot = Offset(0.3979, 0.2958);

  /// How far the hand reaches below its own fingertip, as a fraction of the
  /// box. What decides whether it can come up from below without most of it
  /// falling off the bottom of the screen.
  static double reachBelow(double box) => (1 - hotspot.dy) * box;

  /// White hand, black outline, white ripples.
  ///
  /// Applied at runtime rather than edited into the JSON, so the palette lives
  /// where the rest of the app can see it and a swapped asset cannot arrive
  /// wearing somebody else's scheme.
  ///
  /// The ripples are white rather than the file's black: they are drawn over a
  /// dark scrim and over live gameplay, and black rings on either are a smudge.
  static LottieDelegates delegates({
    Color fill = const Color(0xFFFFFFFF),
    Color line = const Color(0xFF1B2A24),
    Color ripple = const Color(0xFFFFFFFF),
  }) {
    return LottieDelegates(
      values: <ValueDelegate<dynamic>>[
        ValueDelegate.color(
          const <String>['hand_tap_01 Outlines', 'Group 1', 'Fill 1'],
          value: fill,
        ),
        ValueDelegate.strokeColor(
          const <String>['hand_tap_01 Outlines', 'Group 2', 'Stroke 1'],
          value: line,
        ),
        // '**' is a wildcard for the rest of the path. Two ripple layers, one
        // trailing the other.
        ValueDelegate.strokeColor(
          const <String>['Shape Layer 3', '**'],
          value: ripple,
        ),
        ValueDelegate.strokeColor(
          const <String>['Shape Layer 4', '**'],
          value: ripple,
        ),
      ],
    );
  }
}
