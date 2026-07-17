import 'dart:math';

import 'constants.dart';
import 'weighted_picker.dart';

/// Which of the three tracks along the path something sits on.
///
/// A wall's hole is punched in one of these, and the runner has to be standing
/// in the same one to get through it.
enum Lane { left, centre, right }

/// Where every run starts.
const kStartLane = Lane.centre;

extension LaneGeometry on Lane {
  /// Sideways offset from the middle of the path, in world units at z = 0.
  double get offset => (index - 1) * kLaneOffset;

  String get label {
    switch (this) {
      case Lane.left:
        return 'Left';
      case Lane.centre:
        return 'Middle';
      case Lane.right:
        return 'Right';
    }
  }

  /// One step toward the left edge, stopping at it.
  ///
  /// Named `step...` rather than `left`/`right` because those are already the
  /// enum's own values.
  Lane get stepLeft => Lane.values[max(0, index - 1)];

  /// One step toward the right edge, stopping at it.
  Lane get stepRight => Lane.values[min(Lane.values.length - 1, index + 1)];
}

class LanePicker extends WeightedPicker<Lane> {
  LanePicker({super.random}) : super(Lane.values);
}
