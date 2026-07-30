import 'dart:math';

import '../core/constants.dart';

// Pure functions only. This file is unit tested.

/// World scroll speed in px per second for [score].
///
/// Rises linearly and stops at [kSpeedMax]; after that the game is a stamina
/// test rather than a speed test.
double speedFor(int score) =>
    min(kSpeedMax, kSpeedStart + score * kSpeedPerPoint);

/// Seconds between wall spawns for [score]. This is the child's thinking time.
double gapFor(int score) => max(kGapMin, kGapStart - score * kGapDecay);
