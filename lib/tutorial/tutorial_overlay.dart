import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'tutorial_caption.dart';
import 'tutorial_controller.dart';

/// The dim, the hole, the blockers and the caption.
///
/// Wrapped in a transparent [Material] - all of it, not just the caption. An
/// OverlayEntry mounts above the Navigator, so nothing in here inherits the
/// Scaffold's Material, and text without one falls back to WidgetsApp's error
/// style: a double yellow underline, in release builds too. It keeps the
/// colour and size it was given, so it reads as correctly styled text that is
/// also, inexplicably, underlined.
class TutorialOverlay extends StatelessWidget {
  const TutorialOverlay({required this.controller, this.hand, super.key});

  final TutorialController controller;

  /// Draws the pointing hand. Injected rather than imported so this file stays
  /// copyable to the next app, and so the sequence still works - minus the
  /// hand - before the animation has been chosen.
  final Widget Function(BuildContext, HandSpec)? hand;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => _Mark(controller: controller, hand: hand),
      ),
    );
  }
}

/// Everything the hand needs to draw itself, with no opinion about how.
@immutable
class HandSpec {
  const HandSpec({
    required this.tip,
    required this.gesture,
    required this.travel,
    required this.fromAbove,
    required this.replay,
  });

  /// Where the fingertip must land, in overlay coordinates.
  final Offset tip;

  final HandGesture gesture;
  final Offset travel;

  /// Reach down from above instead of up from below. True near the bottom
  /// edge, where a hand drawn below its own fingertip is mostly off screen.
  final bool fromAbove;

  /// Changes whenever the gesture should play again - a refused tap, or a new
  /// step. Key the hand widget off it.
  final int replay;
}

class _Mark extends StatelessWidget {
  const _Mark({required this.controller, this.hand});

  final TutorialController controller;
  final Widget Function(BuildContext, HandSpec)? hand;

  @override
  Widget build(BuildContext context) {
    final step = controller.current;
    if (step == null) return const SizedBox.shrink();

    final overlayBox = context.findRenderObject();
    final hole = _holeOf(overlayBox, step);
    if (hole == null) {
      // Never paint a scrim with no hole in it: that is a full-screen black
      // block with no way through and no way out. Show nothing and look again
      // next frame, by which time the target has been laid out - but only for
      // as long as the controller is willing to wait, because a target that
      // never arrives would otherwise loop here forever.
      if (controller.awaitTarget()) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => controller.refresh(),
        );
      }
      return const SizedBox.shrink();
    }

    final anywhere = step.advance == TutorialAdvance.anywhere;
    // The overlay's own box, not MediaQuery. The hole is measured in this
    // box's coordinates, so the screen has to be measured in them too - when
    // the two disagree the caption is placed relative to one and the hole to
    // the other, and a bottom target ends up with its caption laid directly
    // over the control the player has just been told to press. A null here is
    // impossible: _holeOf returned non-null, which needed a sized RenderBox.
    final size = (overlayBox as RenderBox).size;

    return Stack(
      children: <Widget>[
        // The dim. Never hit-tested - painting and blocking are separate jobs
        // done by separate widgets, because there is no way to let a tap fall
        // through something painted on top of what it should reach.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _ScrimPainter(hole: hole, radius: step.holeRadius),
            ),
          ),
        ),

        if (anywhere)
          // One blocker, not four. Four would leave the hole dead, and the one
          // place the player is told to look would be the one place that does
          // nothing.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: controller.advanceAnywhere,
            ),
          )
        else
          // Four rectangles around the hole. The hole itself has no widget
          // over it at all, so the real control receives the real pointer.
          ..._blockers(size, hole),

        if (hand != null)
          _placeHand(context, step, hole, size, anywhere),

        TutorialCaption(
          text: step.caption,
          hole: hole,
          screen: size,
          onSkip: controller.skip,
          // The panel is a solid box and cannot be tapped through, so it is
          // given the same meaning as the ground around it: carry on where any
          // tap carries on, a refusal where only the target will do.
          onTap: anywhere ? controller.advanceAnywhere : controller.nudge,
        ),
      ],
    );
  }

  /// The target's rectangle in overlay space, or null while it cannot be
  /// measured.
  Rect? _holeOf(RenderObject? overlayBox, TutorialStep step) {
    final targetBox = step.targetKey.currentContext?.findRenderObject();
    if (overlayBox is! RenderBox || targetBox is! RenderBox) return null;
    if (!overlayBox.hasSize || !targetBox.hasSize) return null;
    if (targetBox.size.isEmpty) return null;

    final topLeft = targetBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    return (topLeft & targetBox.size).inflate(step.holePadding);
  }

  List<Widget> _blockers(Size screen, Rect hole) {
    // Opaque, not translucent. Opaque is what makes hit testing stop here -
    // with translucent a tap is absorbed but a DRAG still reaches the widget
    // underneath, so a slider under the scrim stays draggable and no tap-based
    // test ever notices.
    Widget block(double left, double top, double width, double height) {
      if (width <= 0 || height <= 0) return const SizedBox.shrink();
      return Positioned(
        left: left,
        top: top,
        width: width,
        height: height,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: controller.nudge,
          // A drag has to be caught too, or the control underneath is only
          // half protected.
          onPanStart: (_) => controller.nudge(),
        ),
      );
    }

    return <Widget>[
      block(0, 0, screen.width, hole.top),
      block(0, hole.bottom, screen.width, screen.height - hole.bottom),
      block(0, hole.top, hole.left, hole.height),
      block(hole.right, hole.top, screen.width - hole.right, hole.height),
    ];
  }

  Widget _placeHand(
    BuildContext context,
    TutorialStep step,
    Rect hole,
    Size screen,
    bool anywhere,
  ) {
    // Decided here, not at the step definition. A finger jabbing with ripples
    // coming off it says "press this" while the caption says "tap anywhere" -
    // it points at the one place the instruction does not mean. Leaving the
    // choice to whoever writes the step means it is wrong in a month, and the
    // mistake is invisible in review.
    final gesture = anywhere ? HandGesture.point : step.gesture;
    final fromAbove = hole.center.dy > screen.height * kHandFlipShare;

    // A tap aims at the middle, because that is where a finger lands on a
    // button and a hand briefly over the button it is pressing reads correctly.
    //
    // A point does not. It marks something to be READ - a score, a row of
    // hearts, a meter - and a hand laid across the middle of that hides the
    // very thing being explained. So it aims at the edge the hand's own body
    // falls away from: the body hangs down and to the right of the fingertip,
    // and up and to the left once it is turned over.
    final tip = gesture == HandGesture.point
        ? Offset(fromAbove ? hole.left : hole.right, hole.center.dy)
        : hole.center;

    return hand!(
      context,
      HandSpec(
        tip: tip,
        gesture: gesture,
        travel: step.travel,
        fromAbove: fromAbove,
        replay: controller.nudges,
      ),
    );
  }
}

/// Below this fraction of the screen the hand reaches up from under the
/// target; past it the hand would be mostly off the bottom edge, so it comes
/// down from above instead.
const kHandFlipShare = 0.62;

class _ScrimPainter extends CustomPainter {
  const _ScrimPainter({required this.hole, required this.radius});

  final Rect hole;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    // A path difference, not a clip. clipRRect has no clipOp - only clipRect
    // does - so a rounded hole cannot be cut by clipping.
    final screen = Path()..addRect(Offset.zero & size);
    final cut = Path()
      ..addRRect(RRect.fromRectAndRadius(hole, Radius.circular(radius)));
    canvas.drawPath(
      Path.combine(ui.PathOperation.difference, screen, cut),
      Paint()..color = kScrimColor,
    );
    // A soft rim, so the hole reads as deliberate rather than as a gap.
    canvas.drawRRect(
      RRect.fromRectAndRadius(hole, Radius.circular(radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = kScrimRimWidth
        ..color = kScrimRim,
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter old) =>
      old.hole != hole || old.radius != radius;
}

/// How long a step will wait for its target to be laid out before the sequence
/// gives up.
///
/// Generous, and wall time rather than a frame count: a cold start can pump a
/// lot of frames while the game is still loading, and a budget spent before
/// the screen exists is a tutorial that silently never appears.
const kTargetWait = Duration(seconds: 6);

const kScrimColor = Color(0xB3000000);
const kScrimRim = Color(0x66FFFFFF);
const kScrimRimWidth = 3.0;
