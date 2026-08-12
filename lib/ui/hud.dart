import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../game/shape_shifter_game.dart';
import 'chunky.dart';

/// Lives and score top left, shield top right, pause in the corner.
///
/// Everything sits on a card. Bare text over a game world has to be readable
/// on grass, on sky and on brick at once, and no colour does that; a backing
/// card does, for the same reason road signs have one.
class Hud extends StatelessWidget {
  const Hud({required this.game, super.key});

  final ShapeShifterGame game;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // Extra clearance at the top: the pause button lives up there and the
      // system owns the top edge even in immersive mode.
      minimum: const EdgeInsets.fromLTRB(
        kHudPad,
        kEdgeGestureInset,
        kHudPad,
        kHudPad,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ValueListenableBuilder<int>(
            valueListenable: game.lives,
            builder: (_, lives, _) =>
                // The level decides how many there are, so Easy shows five.
                _Hearts(lives: lives, of: game.level.value.lives),
          ),
          const SizedBox(width: kHudPad / 2),
          ValueListenableBuilder<int>(
            valueListenable: game.score,
            builder: (_, score, _) => _Score(score: score),
          ),
          const SizedBox(width: kHudPad),
          ValueListenableBuilder<int>(
            valueListenable: game.coins,
            builder: (_, coins, _) => _Coins(count: coins),
          ),
          const Spacer(),
          ValueListenableBuilder<bool>(
            valueListenable: game.shielded,
            builder: (_, shielded, _) => AnimatedScale(
              alignment: Alignment.centerRight,
              scale: shielded ? 1 : 0.6,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                opacity: shielded ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: const _ShieldPill(),
              ),
            ),
          ),
          // The pause button is not here. It has to sit above the pause panel
          // to stay tappable once the game is parked, so it lives in the app's
          // own stack rather than in this overlay - see PauseToggle.
          const SizedBox(width: kPauseButton),
        ],
      ),
    );
  }
}

/// The pause and resume button, in one control.
///
/// Shows a pause bar while running and a play arrow while parked, and does the
/// matching thing when tapped. Rendered above the pause panel, because the
/// panel's scrim swallows taps and a button that cannot be pressed while
/// paused could never be the thing that unpauses.
class PauseToggle extends StatelessWidget {
  const PauseToggle({required this.game, super.key});

  final ShapeShifterGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GameState>(
      valueListenable: game.stateNotifier,
      builder: (_, state, _) {
        final inPlay = state == GameState.running || state == GameState.hit;
        if (!inPlay) return const SizedBox.shrink();
        return SafeArea(
          minimum: const EdgeInsets.only(
            top: kEdgeGestureInset,
            right: kHudPad,
          ),
          child: Align(
            alignment: Alignment.topRight,
            child: ValueListenableBuilder<bool>(
              valueListenable: game.pauseNotifier,
              builder: (_, paused, _) => ChunkyTile(
                size: kPauseButton,
                circle: true,
                semanticLabel: paused ? 'Keep going' : 'Pause',
                onPressed: paused ? game.resumePlay : game.requestPause,
                face: paused ? kPadFaceActive : kPadFace,
                child: OutlinedGlyph(
                  icon: paused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  size: kPauseIcon,
                  fill: kHudInk,
                  outline: kGameInk,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Hearts, with the spent ones left in place as hollow outlines rather than
/// removed: a child should be able to see how many they started with.
class _Hearts extends StatelessWidget {
  const _Hearts({required this.lives, required this.of});

  final int lives;

  /// How many the run started with. Varies by level.
  final int of;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < of; i++)
          Padding(
            padding: const EdgeInsets.only(right: kHeartGap),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              scale: i < lives ? 1 : 0.82,
              child: OutlinedGlyph(
                icon: Icons.favorite_rounded,
                size: kHeartSize,
                fill: i < lives ? kHeartFill : kHeartSpent,
              ),
            ),
          ),
      ],
    );
  }
}

/// Coins taken this run, in their own pill so they are never mistaken for the
/// score. Kept off screen until the first one is picked up.
class _Coins extends StatelessWidget {
  const _Coins({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: count > 0 ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const _CoinDot(),
          const SizedBox(width: kHeartGap),
          OutlinedText('$count', size: kScoreFontSize * 0.85),
        ],
      ),
    );
  }
}

/// The coin itself, drawn rather than iconised so the counter and the thing
/// on the track are visibly the same object.
class _CoinDot extends StatelessWidget {
  const _CoinDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: kHeartSize,
      height: kHeartSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kCoinFace,
        border: Border.all(color: kHudOutline, width: 3),
      ),
    );
  }
}

class _Score extends StatelessWidget {
  const _Score({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return OutlinedText(
      score.toString().padLeft(kScoreDigits, '0'),
      size: kScoreFontSize,
    );
  }
}

/// Only on screen while the shield is held, so it needs no label saying it is
/// off. Green, because green means "carry on" everywhere else in the game.
class _ShieldPill extends StatelessWidget {
  const _ShieldPill();

  @override
  Widget build(BuildContext context) {
    return HudPill(
      color: kShieldColor,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.shield_rounded, size: kHeartSize, color: kGameInk),
          const SizedBox(width: kHeartGap),
          Text(
            'SHIELD',
            style: TextStyle(
              fontSize: kScoreFontSize * 0.55,
              fontWeight: FontWeight.w900,
              color: kGameInk,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
