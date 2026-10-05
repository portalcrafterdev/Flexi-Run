import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flexirun/tutorial/hand_art.dart';
import 'package:flexirun/tutorial/hand_indicator.dart';
import 'package:lottie/lottie.dart';

// The hand animation, as a set of facts about the file.
//
// The delegates key on layer and group names, and the placement depends on a
// measured fingertip - so a swapped asset breaks both, silently and in a way
// no amount of looking at the diff finds. These are what notice.

const _box = 240;

Future<LottieComposition> _load() async {
  final data = await rootBundle.load(HandArt.asset);
  return LottieComposition.fromByteData(data);
}

/// Renders the composition at [frame] with the delegates applied.
Future<ui.Image> _render(LottieComposition composition, int frame) async {
  final drawable = LottieDrawable(composition)
    // After construction, never as a constructor argument - passing
    // delegates: to the constructor throws LateInitializationError.
    ..delegates = HandArt.delegates()
    ..setProgress(frame / composition.endFrame);

  final recorder = ui.PictureRecorder();
  drawable.draw(
    ui.Canvas(recorder),
    const Rect.fromLTWH(0, 0, _box * 1.0, _box * 1.0),
    fit: BoxFit.contain,
  );
  return recorder.endRecording().toImage(_box, _box);
}

/// The topmost inked pixel, and the leftmost ink on that row.
Future<Offset> _fingertip(ui.Image image) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final data = bytes!.buffer.asUint8List();
  for (var y = 0; y < _box; y++) {
    final hits = <int>[];
    for (var x = 0; x < _box; x++) {
      // Alpha is the fourth byte of each pixel.
      if (data[(y * _box + x) * 4 + 3] > 8) hits.add(x);
    }
    if (hits.isNotEmpty) {
      // The middle of the inked run, so a stroke's rounded cap does not pull
      // the answer to one side.
      final mid = (hits.first + hits.last) / 2;
      return Offset(mid / _box, y / _box);
    }
  }
  throw StateError('nothing was drawn - the hand rendered empty');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the file is the one the code was written against', () async {
    final composition = await _load();
    expect(composition.bounds.width, HandArt.canvas.width);
    expect(composition.bounds.height, HandArt.canvas.height);
    expect(composition.frameRate, HandArt.frameRate);
    expect(composition.startFrame, HandArt.firstFrame);
    // Loosely: Lottie reports 40.99 for an op of 41.
    expect(composition.endFrame, closeTo(HandArt.lastFrame, 0.5));
  });

  test('the hand renders solid, not hollow', () async {
    // Catches the fill-rule regression. Two contours under the non-zero rule
    // put the fill on the band between them and leave the middle genuinely
    // unpainted - and no colour delegate can reach that.
    final image = await _render(await _load(), HandArt.restingFrame);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final data = bytes!.buffer.asUint8List();

    var inked = 0;
    for (var i = 3; i < data.length; i += 4) {
      if (data[i] > 8) inked++;
    }
    // A hollow hand is a thin outline: a few per cent of the box. A solid one
    // is a good deal more.
    final share = inked / (_box * _box);
    expect(
      share,
      greaterThan(0.08),
      reason: 'only ${(share * 100).toStringAsFixed(1)}% inked - hollow?',
    );
  });

  test('the measured fingertip still matches the composition', () async {
    final tip = await _fingertip(
      await _render(await _load(), HandArt.restingFrame),
    );
    // Tight, because this is what the hand is placed by: a few per cent out
    // and the finger points somewhere that looks like a layout bug.
    expect(tip.dx, closeTo(HandArt.hotspot.dx, 0.02), reason: 'tip x drifted');
    expect(tip.dy, closeTo(HandArt.hotspot.dy, 0.02), reason: 'tip y drifted');
  });

  group('the hand stays on screen', () {
    const screen = Size(800, 360);
    const box = 132.0;

    test('a target at the right edge pulls the hand back in', () {
      // What a coach mark over the level tiles does: they run almost to the
      // edge, and the hand is drawn to the RIGHT of its own fingertip - so
      // aiming at the edge put nearly all of it past the edge, leaving a white
      // sliver that reads as a rendering fault rather than as a hand.
      final tip = clampHandTip(
        tip: const Offset(798, 120),
        screen: screen,
        fromAbove: false,
      );
      final right = tip.dx + (1 - HandArt.hotspot.dx) * box;
      expect(right, lessThanOrEqualTo(screen.width + 0.01));
      expect(tip.dx, lessThan(798));
    });

    test('a target in the middle is left exactly where it was aimed', () {
      const aimed = Offset(400, 180);
      expect(clampHandTip(tip: aimed, screen: screen, fromAbove: false), aimed);
    });

    test('a turned-over hand is held in on the other side', () {
      // Rotated about the fingertip, so the body is up and to the LEFT and it
      // is the left edge that bites.
      final tip = clampHandTip(
        tip: const Offset(2, 300),
        screen: screen,
        fromAbove: true,
      );
      final left = tip.dx - (1 - HandArt.hotspot.dx) * box;
      expect(left, greaterThanOrEqualTo(-0.01));
    });

    test('a screen smaller than the hand is left alone', () {
      // No position satisfies both edges, and a clamp would just pick one.
      const aimed = Offset(20, 20);
      expect(
        clampHandTip(tip: aimed, screen: const Size(40, 40), fromAbove: false),
        aimed,
      );
    });
  });

  test('the fingertip sits well above the middle of the box', () async {
    // The reason this is measured at all. At 0.30 down, a hand centred on its
    // target would point roughly a fifth of its own height below it - which on
    // a 120pt hand is 24pt, and reads as a layout bug rather than a flourish.
    expect(HandArt.hotspot.dy, lessThan(0.4));
  });
}
