import 'dart:math';

import '../core/constants.dart';
import '../core/level.dart';

// Pure functions only. This file is unit tested.

/// World scroll speed in px per second for [score].
///
/// Flat, and the same on every level: whatever the score and whatever the
/// setting, a wall takes the same time to travel down the path. The game gets
/// harder by putting the walls closer together, not by making them faster.
double speedFor(int score) =>
    min(kSpeedMax, kSpeedStart + score * kSpeedPerPoint);

/// Seconds between wall spawns at [score] on [level]. This is the child's
/// thinking time, and it is the main thing a level changes.
double gapFor(int score, Level level) =>
    max(level.gapMin, level.gapStart - score * level.gapDecay);
