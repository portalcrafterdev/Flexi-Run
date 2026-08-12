import 'package:flutter/material.dart';

import '../core/audio.dart';
import '../core/constants.dart';
import '../core/prefs.dart';
import 'menu_widgets.dart';

/// The Sound and Music bars.
///
/// One widget, used by both the settings sheet and the pause panel, rather
/// than the same two rows written twice: they have to agree, and a child who
/// turns the music down mid-run should find it down on the menu afterwards.
///
/// In [compact] form the two sit side by side with no labels, which is what
/// fits on a paused landscape screen. The speaker and the note say which is
/// which without a word being read.
class SoundLevels extends StatefulWidget {
  const SoundLevels({this.compact = false, super.key});

  final bool compact;

  @override
  State<SoundLevels> createState() => _SoundLevelsState();
}

class _SoundLevelsState extends State<SoundLevels> {
  @override
  Widget build(BuildContext context) {
    if (!widget.compact) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          MenuLevel(
            label: 'Sound',
            icon: _soundIcon,
            mutedIcon: Icons.volume_off_rounded,
            tint: _soundTint,
            value: Prefs.soundLevel,
            onChanged: _setSound,
          ),
          MenuLevel(
            label: 'Music',
            icon: _musicIcon,
            mutedIcon: Icons.music_off_rounded,
            tint: _musicTint,
            value: Prefs.musicLevel,
            onChanged: _setMusic,
          ),
        ],
      );
    }
    return Row(
      children: <Widget>[
        Expanded(
          child: _CompactLevel(
            label: 'Sound',
            icon: _soundIcon,
            mutedIcon: Icons.volume_off_rounded,
            tint: _soundTint,
            value: Prefs.soundLevel,
            onChanged: _setSound,
          ),
        ),
        const SizedBox(width: kMenuButtonGap * 0.6),
        Expanded(
          child: _CompactLevel(
            label: 'Music',
            icon: _musicIcon,
            mutedIcon: Icons.music_off_rounded,
            tint: _musicTint,
            value: Prefs.musicLevel,
            onChanged: _setMusic,
          ),
        ),
      ],
    );
  }

  static const _soundIcon = Icons.volume_up_rounded;
  static const _musicIcon = Icons.music_note_rounded;
  static final Color _soundTint = kTitleLetterColors[6];
  static final Color _musicTint = kTitleLetterColors[2];

  void _setSound(double value) {
    if (value == Prefs.soundLevel) return;
    Prefs.setSoundLevel(value);
    // A chime at the new level, so the bar is audible while the finger is
    // still on it. Silence would be indistinguishable from a broken control.
    if (value > 0) Audio.preview();
    setState(() {});
  }

  void _setMusic(double value) {
    if (value == Prefs.musicLevel) return;
    Prefs.setMusicLevel(value);
    // Applied straight away. During a pause this only sets the volume the
    // track will come back at - see Audio.applyMusicLevel.
    Audio.applyMusicLevel();
    setState(() {});
  }
}

/// A badge and a bar, no label. For the pause panel, where the panel is short
/// and the icon carries the meaning.
class _CompactLevel extends StatelessWidget {
  const _CompactLevel({
    required this.label,
    required this.icon,
    required this.mutedIcon,
    required this.tint,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final IconData mutedIcon;
  final Color tint;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final on = value > 0;
    return Semantics(
      label: label,
      slider: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: kSettingRowPad,
          vertical: kSettingRowPad * 0.5,
        ),
        decoration: BoxDecoration(
          color: kSettingRowFill,
          borderRadius: BorderRadius.circular(kSettingRowRadius),
          border: Border.all(color: kSettingRowEdge, width: 1.5),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: kLevelBadgeCompact,
              height: kLevelBadgeCompact,
              decoration: BoxDecoration(
                // Dimmed at zero, so off reads at a glance and not only from
                // where the bar happens to sit.
                color: on ? tint : tint.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                on ? icon : mutedIcon,
                size: kLevelIconCompact,
                color: kMenuButtonInk,
              ),
            ),
            const SizedBox(width: kMenuButtonGap * 0.4),
            Expanded(
              child: SizedBox(
                height: kLevelRowCompactH,
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: kLevelBarH,
                    activeTrackColor: tint,
                    inactiveTrackColor: kSwitchOffFill,
                    thumbColor: kSwitchThumbColor,
                    overlayColor: tint.withValues(alpha: 0.15),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: kLevelThumb,
                      elevation: 2,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: kLevelThumb * 1.5,
                    ),
                    trackShape: const RoundedRectSliderTrackShape(),
                    showValueIndicator: ShowValueIndicator.never,
                  ),
                  child: Slider(
                    value: value,
                    onChanged: onChanged,
                    // Coarse steps. A continuous bar is fiddly for small hands
                    // and nobody needs 0.37 of the music.
                    divisions: kLevelSteps,
                    label: label,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
