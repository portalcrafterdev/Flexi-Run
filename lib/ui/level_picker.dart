import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/level.dart';
import '../core/prefs.dart';
import '../game/shape_shifter_game.dart';

/// Easy, Medium and Hard, side by side.
///
/// Three pills rather than a dropdown or a stepper: all the options are on
/// screen at once, so a parent setting this for a child can see what the
/// choices are without opening anything, and a child can see which one they
/// are on without reading it.
///
/// Only on the menu. Switching level mid-run would mean a score set under one
/// set of rules being recorded under another.
class LevelPicker extends StatelessWidget {
  const LevelPicker({required this.game, super.key});

  final ShapeShifterGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Level>(
      valueListenable: game.level,
      // Also rebuilt when the best changes, so a record set on the run you
      // just finished is already on the button when you get back here.
      builder: (_, current, _) => ValueListenableBuilder<int>(
        valueListenable: game.highScore,
        builder: (_, _, _) => Row(
          children: <Widget>[
            for (final level in Level.values) ...<Widget>[
              if (level != Level.values.first)
                const SizedBox(width: kLevelTileGap),
              Expanded(
                child: _LevelTile(
                  label: level.label,
                  best: Prefs.highScore(level),
                  selected: level == current,
                  onPressed: () => game.chooseLevel(level),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One pill. The same slab-on-a-lip as the menu buttons, at a smaller size, so
/// the picker belongs to the same screen rather than looking bolted on.
class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.label,
    required this.best,
    required this.selected,
    required this.onPressed,
  });

  final String label;

  /// This level's own best. Zero until it has been played, which is honest:
  /// an empty slot is an invitation.
  final int best;

  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          height: kLevelTileH + kLevelTileDepth,
          child: Stack(
            children: <Widget>[
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: kLevelTileH,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: selected ? kPlayEdge : kLevelTileEdge,
                    borderRadius: BorderRadius.circular(kLevelTileRadius),
                  ),
                ),
              ),
              // The unselected pills sit down on their lip, the chosen one
              // stands up off it. The state reads as a height difference
              // before it reads as a colour.
              AnimatedPositioned(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                left: 0,
                right: 0,
                top: selected ? 0 : kLevelTileDepth,
                height: kLevelTileH,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: selected ? kPlayFill : kLevelTileFill,
                    borderRadius: BorderRadius.circular(kLevelTileRadius),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: kLevelTileFontSize,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          height: 1,
                          color: selected ? kMenuButtonInk : kLevelTileInk,
                        ),
                      ),
                      const SizedBox(height: kLevelBestGap),
                      Text(
                        // Named, not just a number. A figure on its own under
                        // a level name could be anything - a score to beat, a
                        // level number, how many you have played.
                        //
                        // Unpadded, unlike the live score. That one is padded
                        // so it holds its width while it counts up; a record
                        // is a fact being reported, and 00400 overstates how
                        // big the numbers in this game get.
                        'Best $best',
                        style: TextStyle(
                          fontSize: kLevelBestFontSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          height: 1,
                          color: selected
                              ? kLevelBestSelectedInk
                              : kLevelBestInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
