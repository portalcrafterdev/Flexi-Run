import 'package:flutter/material.dart';

import '../core/audio.dart';
import '../core/constants.dart';
import '../core/games.dart';
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
      // And when the account changes. These tiles read storage directly, and
      // storage answers for whoever is signed in - so signing out has to put
      // the signed-out bests back on screen rather than leaving the account's
      // numbers sitting there until the app is restarted.
      builder: (_, current, _) => ValueListenableBuilder<String?>(
        valueListenable: Games.playerName,
        builder: (_, _, _) => ValueListenableBuilder<int>(
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
                    ink: _inkFor(level),
                    face: _faceFor(level),
                    faceColor: level == Level.hard
                        ? kLevelFaceHard
                        : kLevelFaceColor,
                    selected: level == current,
                    onPressed: () => game.chooseLevel(level),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The ink each level's name is written in: green, amber, red.
///
/// Kept here rather than on [Level] itself, which is game rules - what a level
/// looks like is the menu's business, and difficulty.dart has no opinion about
/// colour.
Color _inkFor(Level level) {
  switch (level) {
    case Level.easy:
      return kEasyInk;
    case Level.medium:
      return kMediumInk;
    case Level.hard:
      return kHardInk;
  }
}

/// A face per level. This is the part a child actually reads: the broad smile,
/// the smaller one, and the star. The word beside it is for whoever can read.
IconData _faceFor(Level level) {
  switch (level) {
    case Level.easy:
      return Icons.sentiment_very_satisfied_rounded;
    case Level.medium:
      return Icons.sentiment_satisfied_rounded;
    case Level.hard:
      return Icons.star_rounded;
  }
}

/// One pill. The same slab-on-a-lip as the menu buttons, at a smaller size, so
/// the picker belongs to the same screen rather than looking bolted on.
class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.label,
    required this.best,
    required this.ink,
    required this.face,
    required this.faceColor,
    required this.selected,
    required this.onPressed,
  });

  final String label;

  /// This level's own best. Zero until it has been played, which is honest:
  /// an empty slot is an invitation.
  final int best;

  final Color ink;
  final IconData face;
  final Color faceColor;
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
        onTap: () {
          Audio.tap();
          onPressed();
        },
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
                    color: selected ? ink : kLevelTileEdge,
                    borderRadius: BorderRadius.circular(kLevelTileRadius),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: kMenuShadow,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
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
                    // Parchment, and the same parchment whether or not this is
                    // the chosen level. The three pills are a set of options,
                    // and recolouring one of them broke that: it stopped
                    // looking like the same kind of thing as its neighbours.
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[kLevelTileTop, kLevelTileFill],
                    ),
                    borderRadius: BorderRadius.circular(kLevelTileRadius),
                    // The choice is carried by the rim instead: the level's own
                    // ink, thicker. With the pill also standing up off its lip,
                    // that is two signals, neither of them colour-alone.
                    border: Border.all(
                      color: selected ? ink : kLevelTileEdge,
                      width: selected
                          ? kLevelTileRimChosen
                          : kLevelTileRimWidth,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(face, size: kLevelFaceSize, color: faceColor),
                          const SizedBox(width: kLevelFaceGap),
                          // Shrinks rather than overflows: "Medium" is the
                          // longest of the three and the pill is a third of a
                          // 330pt column, so there is not much room spare.
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: kLevelTileFontSize,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                height: 1,
                                color: ink,
                              ),
                            ),
                          ),
                        ],
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
                          // One ink now, chosen or not: the pill no longer
                          // turns green underneath it, so the pale variant
                          // that used to sit on green has nothing to sit on.
                          color: kLevelBestInk,
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
