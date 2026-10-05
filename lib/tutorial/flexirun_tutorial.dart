import 'package:flutter/widgets.dart';

import '../core/level.dart';
import 'tutorial_controller.dart';

// Flexi Run's own coach marks: what they point at, what they say, and the one
// object the screen holds to tie them to the real controls.
//
// Everything else under lib/tutorial/ is general machinery with no idea what
// this game is. This file is the only part that does.

/// What each step reports when it is satisfied.
///
/// Strings rather than an enum because the machinery is deliberately ignorant
/// of this game - [TutorialController.report] takes an id and compares it.
const kStepStats = 'stats';
const kStepShape = 'shape';
const kStepLane = 'lane';

const kStepLevels = 'levels';
const kStepHowTo = 'howTo';
const kStepPlay = 'play';

/// Versioned, and per level.
///
/// Per level because the levels do not teach the same thing: Easy opens every
/// wall on the middle track, so it has no lane lesson to give. A single flag
/// would mean a child who learned on Easy moved up to Medium and was never
/// shown the one control that had just become necessary.
String tutorialFlagFor(Level level) => 'tutorial.run.v1.${level.name}';

/// The home screen's own sequence.
///
/// Not per level: the menu is the same screen whichever level is chosen, and
/// the one thing on it that depends on the level - which tile is lit - is what
/// the first mark is pointing at.
const kMenuTutorialFlag = 'tutorial.menu.v1';

/// The keys the marks are measured from, and the sink the real controls report
/// into.
///
/// One object so a screen holds one thing. The controls stay ignorant of the
/// controller: they call [report] whether or not a tutorial is up, which is
/// what keeps the taught path and the ordinary path the same path.
class TutorialLink {
  /// The three (or four) shape buttons, as a group.
  ///
  /// The group rather than one button: a mark over a single shape would be
  /// teaching "press the star", and the lesson is "these change your shape".
  final GlobalKey shapeRow = GlobalKey(debugLabel: 'tutorial.shapeRow');

  /// The right-hand chevron. One arrow is enough to explain both.
  final GlobalKey laneArrow = GlobalKey(debugLabel: 'tutorial.laneArrow');

  /// Hearts, score and coins together.
  final GlobalKey stats = GlobalKey(debugLabel: 'tutorial.stats');

  /// The three level tiles, as a group.
  final GlobalKey levels = GlobalKey(debugLabel: 'tutorial.levels');

  final GlobalKey howTo = GlobalKey(debugLabel: 'tutorial.howTo');
  final GlobalKey play = GlobalKey(debugLabel: 'tutorial.play');

  TutorialController? _active;

  /// Binds the controller the marks are currently coming from, or null.
  void bind(TutorialController? controller) => _active = controller;

  /// Tells whatever sequence is up that [id] happened. A no-op the rest of the
  /// time, which is the point: no call site has to ask first.
  void report(String id) => _active?.report(id);

  /// The home screen's sequence.
  ///
  /// Ends on PLAY, so the last thing it asks for is the thing that starts the
  /// game - the mark hands straight over to the run instead of stopping to be
  /// dismissed.
  ///
  /// Only the last step waits for its own control. The other two mark things
  /// to look at rather than press: a child made to open HOW TO PLAY before
  /// they are allowed to play has been given a chore, not a lesson.
  List<TutorialStep> menuSteps() {
    return <TutorialStep>[
      TutorialStep(
        id: kStepLevels,
        targetKey: levels,
        advance: TutorialAdvance.anywhere,
        caption: 'Pick how hard it is. Tap to go on.',
      ),
      TutorialStep(
        id: kStepHowTo,
        targetKey: howTo,
        advance: TutorialAdvance.anywhere,
        caption: 'Not sure what to do? Look here.',
      ),
      TutorialStep(
        id: kStepPlay,
        targetKey: play,
        caption: 'Tap PLAY to start!',
      ),
    ];
  }

  /// The sequence for [level], in order.
  List<TutorialStep> stepsFor(Level level) {
    return <TutorialStep>[
      TutorialStep(
        id: kStepStats,
        targetKey: stats,
        // Nothing here can be pressed, so there is no interaction to wait for.
        advance: TutorialAdvance.anywhere,
        caption: 'Hearts are your lives, and you score by going through the '
            'walls. Tap to carry on.',
      ),
      TutorialStep(
        id: kStepShape,
        targetKey: shapeRow,
        caption: 'Every wall has a hole. Tap a shape to turn into it!',
      ),
      // Only where it does something. On Easy every wall opens on the middle
      // track, so a mark saying "change track" would be teaching a control the
      // level never asks for - and the step would sit there waiting for a tap
      // the player has no reason to make.
      if (!level.centreLaneOnly)
        TutorialStep(
          id: kStepLane,
          targetKey: laneArrow,
          caption: 'Walls open on three tracks. Tap the arrows to move across '
              '- or swipe anywhere.',
        ),
    ];
  }
}
