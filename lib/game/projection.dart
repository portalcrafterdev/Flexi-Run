import '../core/constants.dart';

// Pure functions turning a depth into screen space. Everything drawn in the
// world goes through here, so the whole perspective is tunable from
// [kFocal], [kVanishX], [kNearLaneX], [kHorizonY] and [kNearGroundY].
//
// z = 0 is the runner's own plane, larger z is further up the path.
// This file is unit tested.

/// How big something at depth [z] appears, relative to its size at z = 0.
///
/// 1 at the runner's plane, falling toward 0 at the horizon, and growing above
/// 1 for anything that has passed the camera.
double scaleAt(double z) => kFocal / (kFocal + z);

/// Screen x of the lane centre at depth [z].
double laneXAt(double z) => kVanishX + (kNearLaneX - kVanishX) * scaleAt(z);

/// Screen y of the ground at depth [z].
double groundYAt(double z) =>
    kHorizonY + (kNearGroundY - kHorizonY) * scaleAt(z);

/// Screen x of a point [lateral] units to the side of the lane at depth [z].
double sideXAt(double lateral, double z) =>
    laneXAt(z) + lateral * scaleAt(z);

/// Draw order for something at depth [z].
///
/// Anything still ahead of the runner sits in a band below the runner's own
/// priority; anything that has passed it sits in a band above. That flip is
/// what makes a wall occlude the runner as it goes through the hole.
int depthPriority(double z) {
  if (z > kWallHitZ) {
    // Measured from the furthest thing drawn, not from the wall spawn: the
    // scenery starts further back than the walls, and anything past the
    // reference point clamps to the same priority with no order between them.
    final steps = ((kDepthPriorityFarZ - z) / kDepthPriorityStep).round();
    return kPrioFarBase + steps.clamp(0, kPrioFarSpan);
  }
  final steps = ((kWallHitZ - z) / kDepthPriorityStep).round();
  return kPrioNearBase + steps.clamp(0, kPrioNearSpan);
}
