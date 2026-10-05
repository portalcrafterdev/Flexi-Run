import 'package:flutter/material.dart';

import '../core/audio.dart';
import '../core/cloud_save.dart';
import '../core/constants.dart';
import '../core/games.dart';
import '../core/prefs.dart';

/// Throws away the progress of whoever is playing now.
///
/// Asks twice. One tap arms it and the second does it, because this sits in a
/// settings sheet a six year old can open and the thing it destroys is the
/// thing they care most about. A plain button here would be a trap.
///
/// Clears the account's copy as well when signed in - without that the next
/// sync would merge the cloud back down and the button would appear to have
/// done nothing.
class ClearProgressRow extends StatefulWidget {
  const ClearProgressRow({super.key});

  @override
  State<ClearProgressRow> createState() => _ClearProgressRowState();
}

enum _Step { idle, armed, done }

class _ClearProgressRowState extends State<ClearProgressRow> {
  _Step _step = _Step.idle;

  Future<void> _tapped() async {
    Audio.tap();
    if (_step == _Step.idle) {
      setState(() => _step = _Step.armed);
      return;
    }
    if (_step == _Step.done) return;

    // The cloud first: a failure there must not stop the local clear, and the
    // local clear is the half the player can actually see.
    await CloudSave.wipe();
    await Prefs.clearProgress();
    if (!mounted) return;
    setState(() => _step = _Step.done);
  }

  String get _label => switch (_step) {
    _Step.idle => 'Clear progress',
    _Step.armed => 'Tap again to clear',
    _Step.done => 'Progress cleared',
  };

  String get _note => switch (_step) {
    _Step.idle => Games.isSignedIn
        ? 'Removes scores, coins and badges for ${Games.playerName.value}.'
        : 'Removes scores, coins and badges saved on this phone.',
    _Step.armed => 'This cannot be undone.',
    _Step.done => 'Starting again from zero.',
  };

  @override
  Widget build(BuildContext context) {
    final armed = _step == _Step.armed;
    return Padding(
      padding: const EdgeInsets.only(top: kMenuButtonGap),
      child: Semantics(
        button: true,
        label: _label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _step == _Step.done ? null : _tapped,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: kHudPad,
              vertical: kHudPad * 0.6,
            ),
            decoration: BoxDecoration(
              color: kSheetFill,
              borderRadius: BorderRadius.circular(kMenuCardRadius),
              border: Border.all(
                color: armed ? kSignInFailInk : kSheetEdge,
                width: armed ? 3 : 2,
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  _step == _Step.done
                      ? Icons.check_circle_rounded
                      : Icons.delete_outline_rounded,
                  size: kMenuIconSize,
                  color: armed ? kSignInFailInk : kUiInk,
                ),
                const SizedBox(width: kHudPad * 0.6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _label,
                        style: TextStyle(
                          fontSize: kMenuButtonFontSize,
                          fontWeight: FontWeight.w900,
                          color: armed ? kSignInFailInk : kUiInk,
                        ),
                      ),
                      Text(
                        _note,
                        style: const TextStyle(
                          fontSize: kSignInNoteSize,
                          fontWeight: FontWeight.w700,
                          color: kSheetNoteInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
