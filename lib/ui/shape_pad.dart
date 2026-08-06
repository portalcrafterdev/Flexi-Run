import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/shape_kind.dart';
import '../game/shape_shifter_game.dart';
import 'shape_glyph.dart';

/// The three shape buttons, the two lane arrows, and the optional
/// tap-and-swipe-anywhere layer underneath them.
///
/// A run needs both halves: the right shape *and* the right lane. Shapes are
/// tapped, lanes are nudged.
class ShapePad extends StatelessWidget {
  const ShapePad({required this.game, super.key});

  final ShapeShifterGame game;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        // Always on. It was a setting, but a child who cannot find the buttons
        // has no way to discover the setting that would help them, and there
        // is no cost to leaving it enabled: a tap that lands on a button is a
        // button press, and one that misses still counts.
        Positioned.fill(child: _TapLayer(game: game)),
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
                  onPressed: () => game.stepLane(-1),
                ),
                Expanded(child: _ShapeRow(game: game)),
                _LaneArrow(
                  icon: Icons.chevron_right_rounded,
                  label: 'Move right',
                  onPressed: () => game.stepLane(1),
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
  const _ShapeRow({required this.game});

  final ShapeShifterGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ShapeKind>(
      valueListenable: game.activeShape,
      builder: (_, active, _) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          for (final kind in ShapeKind.values)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: kShapeButtonGap / 2,
              ),
              child: _ShapeButton(
                kind: kind,
                active: kind == active,
                onTap: () => game.morph(kind),
              ),
            ),
        ],
      ),
    );
  }
}

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
    return Semantics(
      button: true,
      label: kind.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => onTap(),
        // Never smaller than kMinTapTarget. This is a game for six year olds.
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: kMinTapTarget,
            minHeight: kMinTapTarget,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: kShapeButton,
            height: kShapeButton,
            decoration: BoxDecoration(
              // Glass: brighter along the top edge where the light catches,
              // with a shadow under it so it floats over the world.
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[kUiButtonGloss, kUiButtonFill],
              ),
              borderRadius: BorderRadius.circular(kShapeButtonRadius),
              border: Border.all(
                color: active ? kUiAccent : kUiButtonBorder,
                width: active ? kActiveRingWidth : 2,
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: kUiDropShadow,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: ShapeGlyph(
                kind: kind,
                color: Colors.white,
                size: kShapeButton - kShapeGlyphInset * 2,
              ),
            ),
          ),
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
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => onPressed(),
        child: Container(
          width: kLaneArrow,
          height: kLaneArrow,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[kUiButtonGloss, kUiButtonFill],
            ),
            borderRadius: BorderRadius.circular(kLaneArrow / 2),
            border: Border.all(color: kUiButtonBorder, width: 2),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: kUiDropShadow,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: kLaneArrowIcon),
        ),
      ),
    );
  }
}

/// Tap a third of the screen for a shape, swipe sideways to change lane.
///
/// The two do not fight: a gesture that moves is a swipe, one that does not is
/// a tap.
class _TapLayer extends StatelessWidget {
  const _TapLayer({required this.game});

  final ShapeShifterGame game;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.velocity.pixelsPerSecond.dx;
        if (velocity.abs() < 1) return;
        game.stepLane(velocity < 0 ? -1 : 1);
      },
      child: Row(
        children: <Widget>[
          for (final kind in ShapeKind.values)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => game.morph(kind),
              ),
            ),
        ],
      ),
    );
  }
}

