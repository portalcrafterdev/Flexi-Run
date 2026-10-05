import 'package:flutter/material.dart';

import '../core/audio.dart';
import '../core/constants.dart';
import '../core/shape_kind.dart';
 import '../tutorial/flexirun_tutorial.dart';
import '../game/shape_shifter_game.dart';
import 'chunky.dart';
import 'shape_glyph.dart';

/// The three shape buttons, the two lane arrows, and the optional
/// tap-and-swipe-anywhere layer underneath them.
///
/// A run needs both halves: the right shape *and* the right lane. Shapes are
/// tapped, lanes are nudged.
class ShapePad extends StatelessWidget {
  const ShapePad({required this.game, this.link, super.key});

  final ShapeShifterGame game;

  /// Lets the coach marks point at these controls and hear when one is used.
  /// Null wherever no tutorial can run.
  final TutorialLink? link;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        // Always on. It was a setting, but a child who cannot find the buttons
        // has no way to discover the setting that would help them, and there
        // is no cost to leaving it enabled: a tap that lands on a button is a
        // button press, and one that misses still counts.
        Positioned.fill(child: _TapLayer(game: game, link: link)),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            minimum: const EdgeInsets.only(bottom: kPadBottomInset),
            child: Row(
              children: <Widget>[
                const SizedBox(width: kHudPad),
                _LaneArrow(
                  icon: Icons.chevron_left_rounded,
                  label: 'Move left',
                  onPressed: () {
                    game.stepLane(-1);
                    link?.report(kStepLane);
                  },
                ),
                Expanded(child: _ShapeRow(game: game, link: link)),
                _LaneArrow(
                  // The mark points at this one. Reporting from both anyway, so
                  // the lesson is satisfied by either arrow if it ever moves.
                  key: link?.laneArrow,
                  icon: Icons.chevron_right_rounded,
                  label: 'Move right',
                  onPressed: () {
                    game.stepLane(1);
                    link?.report(kStepLane);
                  },
                ),
                const SizedBox(width: kHudPad),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ShapeRow extends StatelessWidget {
  const _ShapeRow({required this.game, this.link});

  final ShapeShifterGame game;
  final TutorialLink? link;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ShapeKind>(
      valueListenable: game.activeShape,
      // Centre plus a shrink-wrapped row, rather than a full-width row with
      // its children centred. The two look identical, but only this one gives
      // the group a box that hugs the buttons - and a coach mark cut around a
      // full-width box would be a hole with most of the screen in it.
      builder: (_, active, _) => Center(
        child: Row(
          key: link?.shapeRow,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
          // The level's shapes, not every shape there is. Read straight off
          // the notifier rather than listened to: the level cannot change
          // while this row is on screen, because chooseLevel refuses during a
          // run and the pad only exists during one.
            for (final kind in game.level.value.shapes)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: kShapeButtonGap / 2,
                ),
                child: _ShapeButton(
                  kind: kind,
                  active: kind == active,
                  onTap: () {
                    game.morph(kind);
                    link?.report(kStepShape);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One shape. The worn one stands up, keeps its colour and takes a ring; the
/// other two sit back and go pale, so which shape the runner is wearing is
/// legible at a glance without reading anything.
class _ShapeButton extends StatelessWidget {
  const _ShapeButton({
    required this.kind,
    required this.active,
    required this.onTap,
  });

  final ShapeKind kind;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      scale: active ? kActiveLift : 1,
      child: ChunkyTile(
        size: kShapeButton,
        semanticLabel: kind.label,
        onPressed: onTap,
        face: active ? kPadFaceActive : kPadFace,
        ring: active ? kPadActiveRing : null,
        // Each shape in its own colour, and the same colour it wears under the
        // title on the menu.
        //
        // These were white, on the grounds that the holes in the walls have no
        // colour and a coloured button would teach a cue the wall cannot
        // answer. That still holds, and it is why the colour is not doing the
        // matching here: which shape to wear is read off the hole's silhouette
        // exactly as before. What the colour does is tell the three BUTTONS
        // apart. White on pale glass made them near identical at a glance, so
        // a child who had already decided on "star" still had to hunt for it.
        child: ShapeGlyph(
          kind: kind,
          color: active
              ? colourFor(kind)
              : colourFor(kind).withValues(alpha: 0.85),
          size: kShapeButton - kShapeGlyphInset * 2,
        ),
      ),
    );
  }
}

/// A big chevron in the bottom corner, for children who will not find a swipe.
class _LaneArrow extends StatelessWidget {
  const _LaneArrow({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ChunkyTile(
      size: kLaneArrow,
      circle: true,
      semanticLabel: label,
      onPressed: onPressed,
      child: OutlinedGlyph(
        icon: icon,
        size: kLaneArrowIcon,
        fill: kHudInk,
        outline: kGameInk,
      ),
    );
  }
}

/// Tap a third of the screen for a shape, swipe sideways to change lane.
///
/// The two do not fight: a gesture that moves is a swipe, one that does not is
/// a tap.
class _TapLayer extends StatelessWidget {
  const _TapLayer({required this.game, this.link});

  final ShapeShifterGame game;
  final TutorialLink? link;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.velocity.pixelsPerSecond.dx;
        if (velocity.abs() < 1) return;
        Audio.tap();
        game.stepLane(velocity < 0 ? -1 : 1);
        link?.report(kStepLane);
      },
      child: Row(
        children: <Widget>[
          // Splits into as many bands as the level has shapes - thirds on Easy
          // and Medium, quarters on Hard - so the screen always matches the
          // buttons underneath it.
          for (final kind in game.level.value.shapes)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // Clicks like a button, because to a child this is one: they
                // aimed at the screen and something had to answer.
                onTapDown: (_) {
                  Audio.tap();
                  game.morph(kind);
                  // Reported here as well as from the button. The gaps between
                  // the buttons fall through to this layer, and a tap that
                  // morphs the runner but does not satisfy the step would look
                  // like a tutorial that had stopped working.
                  link?.report(kStepShape);
                },
              ),
            ),
        ],
      ),
    );
  }
}

