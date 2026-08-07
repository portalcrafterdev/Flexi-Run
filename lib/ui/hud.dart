import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../game/shape_shifter_game.dart';

/// Hearts and score top left, shield pill top right.
class Hud extends StatelessWidget {
  const Hud({required this.game, super.key});

  final ShapeShifterGame game;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // Extra clearance at the top for the same reason as the menu's gear:
      // the pause button lives up there and the system owns the top edge.
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
            builder: (_, lives, _) => _Hearts(lives: lives),
          ),
          const SizedBox(width: kHudPad),
          ValueListenableBuilder<int>(
            valueListenable: game.score,
            builder: (_, score, _) => _Score(score: score),
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
          const SizedBox(width: kHudPad / 2),
          _PauseButton(onPressed: game.requestPause),
        ],
      ),
    );
  }
}

class _PauseButton extends StatelessWidget {
  const _PauseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Pause',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          width: kPauseButton,
          height: kPauseButton,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[kUiButtonGloss, kUiButtonFill],
            ),
            borderRadius: BorderRadius.circular(kShapeButtonRadius),
            border: Border.all(color: kUiButtonBorder, width: 2),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: kUiDropShadow,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.pause_rounded,
            color: Colors.white,
            size: kPauseIcon,
          ),
        ),
      ),
    );
  }
}

class _Hearts extends StatelessWidget {
  const _Hearts({required this.lives});

  final int lives;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (var i = 0; i < kLives; i++)
          Padding(
            padding: const EdgeInsets.only(right: kHeartGap),
            child: Icon(
              i < lives ? Icons.favorite : Icons.favorite_border,
              size: kHeartSize,
              color: i < lives ? kUiHeart : kUiHeartEmpty,
            ),
          ),
      ],
    );
  }
}

class _Score extends StatelessWidget {
  const _Score({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Text(
      score.toString().padLeft(kScoreDigits, '0'),
      style: const TextStyle(
        fontSize: kScoreFontSize,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: 2,
        shadows: <Shadow>[
          Shadow(blurRadius: 4, offset: Offset(0, 2), color: kUiScrim),
        ],
      ),
    );
  }
}

class _ShieldPill extends StatelessWidget {
  const _ShieldPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kShieldPillH,
      padding: const EdgeInsets.symmetric(horizontal: kHudPad),
      decoration: BoxDecoration(
        color: kShieldColor,
        borderRadius: BorderRadius.circular(kShieldPillRadius),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.shield, size: kHeartSize * 0.7, color: kUiInk),
          SizedBox(width: kHeartGap),
          Text(
            'SHIELD',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: kUiInk,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
