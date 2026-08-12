import 'dart:math';

import 'package:flutter/material.dart';

import '../core/art_icon.dart';
import '../core/constants.dart';

/// The runner, waiting on the hill.
///
/// The home screen had nothing alive on it - a name, three pills and two
/// slabs, over an empty meadow. The character was on the launcher icon and
/// nowhere else, so the app you tapped and the screen it opened had different
/// faces. This is the same drawing code the icon uses, so it cannot drift:
/// retune the character and both follow.
///
/// It bobs. A still character over a still meadow reads as a screenshot.
class MenuRunner extends StatefulWidget {
  const MenuRunner({required this.size, super.key});

  final double size;

  @override
  State<MenuRunner> createState() => _MenuRunnerState();
}

class _MenuRunnerState extends State<MenuRunner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(seconds: kMenuRunnerSeconds),
  )..repeat();

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _bob,
            builder: (_, _) => CustomPaint(
              painter: _RunnerPainter(_bob.value),
              size: Size.square(widget.size),
            ),
          ),
        ),
      ),
    );
  }
}

class _RunnerPainter extends CustomPainter {
  const _RunnerPainter(this.phase);

  /// 0 to 1, one full bob.
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    paintIconRunner(
      canvas,
      size,
      bodyWidth: kMenuRunnerWidth,
      centreY: kMenuRunnerY,
      bob: -sin(phase * 2 * pi) * kMenuRunnerBob,
    );
  }

  @override
  bool shouldRepaint(_RunnerPainter old) => old.phase != phase;
}
