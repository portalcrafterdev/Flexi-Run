import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'hand_art.dart';
import 'tutorial_controller.dart';
import 'tutorial_overlay.dart';

/// The pointing hand, placed by its fingertip.
///
/// Three gestures off one composition: [HandGesture.tap] plays it, while
/// [HandGesture.point] and [HandGesture.swipe] hold a single frame and move
/// the whole widget instead - a bob and a glide respectively.
class HandIndicator extends StatefulWidget {
  const HandIndicator({required this.spec, this.box = kHandBox, super.key});

  final HandSpec spec;
  final double box;

  @override
  State<HandIndicator> createState() => _HandIndicatorState();
}

class _HandIndicatorState extends State<HandIndicator>
    with TickerProviderStateMixin {
  /// One pass of the gesture.
  ///
  /// Separate from [_frame] because point and swipe hold a frame while
  /// something else moves - one controller cannot do both.
  late final AnimationController _run = AnimationController(
    vsync: this,
    // A placeholder until the file has loaded, which is where the real value
    // comes from.
    duration: const Duration(milliseconds: 1640),
  )..addStatusListener(_onPassEnd);

  /// The composition's own playhead.
  late final AnimationController _frame = AnimationController(vsync: this);

  int _passes = 0;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  @override
  void didUpdateWidget(HandIndicator old) {
    super.didUpdateWidget(old);
    // A refused tap bumps replay, which is the whole point of a refusal: the
    // gesture plays again.
    if (widget.spec.replay != old.spec.replay ||
        widget.spec.gesture != old.spec.gesture) {
      _begin();
    }
  }

  void _begin() {
    _passes = 0;
    if (widget.spec.gesture == HandGesture.tap) {
      // The composition drives itself.
      _frame.value = 0;
    } else {
      // Held still, so the bob or the glide is the only motion.
      _frame.value = HandArt.restingFrame / HandArt.lastFrame;
    }
    _run.forward(from: 0);
  }

  void _onPassEnd(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _passes++;
    // Finite. Lottie's repeat defaults to true, and a looping animation hangs
    // pumpAndSettle forever rather than failing it - so an infinite hand is a
    // test suite that never finishes and never says why.
    if (_passes >= kHandPasses || !mounted) return;
    _run.forward(from: 0);
  }

  @override
  void dispose() {
    _run.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final spec = widget.spec;
    final box = widget.box;

    // The screen, taken from the space the hand is given rather than from
    // MediaQuery: the hand is clamped into this box, and it must be the same
    // box the overlay measured its hole in.
    return LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: _run,
        builder: (context, _) {
          final t = still ? 0.0 : _run.value;
          if (spec.gesture == HandGesture.tap && !still) {
            _frame.value = t;
          }

          final shift = switch (spec.gesture) {
            // Eases out and back, so the hand lands on the target rather than
            // stopping short of it.
            HandGesture.swipe => spec.travel * Curves.easeInOut.transform(t),
            HandGesture.point => Offset(0, -math.sin(t * math.pi) * kHandBob),
            HandGesture.tap => Offset.zero,
          };

          final tip = clampHandTip(
            tip: spec.tip + shift,
            screen: constraints.biggest,
            fromAbove: spec.fromAbove,
            box: box,
          );
          return IgnorePointer(
            child: Stack(
              children: <Widget>[
                if (spec.gesture == HandGesture.swipe)
                  Positioned.fill(
                    child: CustomPaint(
                      // Drawn here rather than baked into the asset, for the
                      // same reason the travel is: a Lottie file fixes its
                      // motion at author time.
                      painter: _TrackPainter(
                        from: spec.tip,
                        to: spec.tip + spec.travel,
                      ),
                    ),
                  ),
                Positioned(
                  left: tip.dx - HandArt.hotspot.dx * box,
                  top: tip.dy - HandArt.hotspot.dy * box,
                  width: box,
                  height: box,
                  child: _turned(spec.fromAbove, _hand()),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _hand() => Lottie.asset(
    HandArt.asset,
    controller: _frame,
    delegates: HandArt.delegates(),
    fit: BoxFit.contain,
    onLoaded: (composition) {
      // The real cycle length. A controller spanning several cycles would play
      // the composition once at a fraction of its speed, because Lottie maps
      // 0..1 onto the WHOLE composition.
      _run.duration = composition.duration;
    },
  );

  /// Turned about the fingertip, not mirrored.
  ///
  /// A mirrored cursor hand does not read as a hand reaching down - it reads
  /// as a glyph. Turning about the hotspot also means the fingertip does not
  /// move, because it is the point being turned about.
  Widget _turned(bool fromAbove, Widget child) {
    if (!fromAbove) return child;
    return Transform.rotate(
      angle: math.pi,
      alignment: Alignment(
        HandArt.hotspot.dx * 2 - 1,
        HandArt.hotspot.dy * 2 - 1,
      ),
      child: child,
    );
  }
}

/// The faint line a swipe travels along, with an arrowhead at the end.
class _TrackPainter extends CustomPainter {
  const _TrackPainter({required this.from, required this.to});

  final Offset from;
  final Offset to;

  @override
  void paint(Canvas canvas, Size size) {
    if (from == to) return;
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = kHandTrack
        ..strokeWidth = kHandTrackWidth
        ..strokeCap = StrokeCap.round,
    );

    final angle = (to - from).direction;
    final head = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(
        to.dx - math.cos(angle - kHandArrowSpread) * kHandArrowLen,
        to.dy - math.sin(angle - kHandArrowSpread) * kHandArrowLen,
      )
      ..moveTo(to.dx, to.dy)
      ..lineTo(
        to.dx - math.cos(angle + kHandArrowSpread) * kHandArrowLen,
        to.dy - math.sin(angle + kHandArrowSpread) * kHandArrowLen,
      );
    canvas.drawPath(
      head,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = kHandTrack
        ..strokeWidth = kHandTrackWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_TrackPainter old) => old.from != from || old.to != to;
}

/// Pulls [tip] in far enough that the whole hand stays on screen.
///
/// The fingertip is what gets aimed, but the hand is DRAWN around it - mostly
/// below and to the right of it, and above and to the left once it is turned
/// over. A target hard against an edge therefore puts most of the hand past
/// that edge, and the sliver left behind reads as a stray white shape rather
/// than as a hand pointing at anything.
///
/// Returns [tip] unchanged when the screen is smaller than the hand, because
/// there is then no position that satisfies both edges and a clamp would just
/// pick one arbitrarily.
Offset clampHandTip({
  required Offset tip,
  required Size screen,
  required bool fromAbove,
  double box = kHandBox,
}) {
  if (screen.isEmpty) return tip;

  // How far the drawing reaches past the fingertip on each side. Turning the
  // hand over swaps them, because it is rotated about the fingertip.
  final near = HandArt.hotspot.dx * box;
  final far = (1 - HandArt.hotspot.dx) * box;
  final above = HandArt.hotspot.dy * box;
  final below = (1 - HandArt.hotspot.dy) * box;

  final minX = fromAbove ? far : near;
  final maxX = screen.width - (fromAbove ? near : far);
  final minY = fromAbove ? below : above;
  final maxY = screen.height - (fromAbove ? above : below);
  if (minX > maxX || minY > maxY) return tip;

  return Offset(tip.dx.clamp(minX, maxX), tip.dy.clamp(minY, maxY));
}

/// How big the hand is drawn, edge to edge of its composition box.
const kHandBox = 132.0;

/// How many times a gesture plays before the hand holds still. Finite on
/// purpose - see the status listener.
const kHandPasses = 3;

/// How far a pointing hand bobs.
const kHandBob = 10.0;

const kHandTrack = Color(0x8CFFFFFF);
const kHandTrackWidth = 4.0;
const kHandArrowLen = 16.0;
const kHandArrowSpread = 0.5;
