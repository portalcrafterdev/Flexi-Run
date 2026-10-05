import 'dart:async';

import 'package:flutter/material.dart';

import '../core/audio.dart';
import '../core/constants.dart';
import '../core/games.dart';

/// The two round buttons that open Play Games, in the menu's top corner.
///
/// Separate buttons, not one. Achievements used to hang off the signed-in
/// pill, which meant the only way to a child's badges was tapping a row that
/// looked like a label with somebody's name on it - nothing about it said it
/// could be pressed, and nobody found it.
///
/// In the corner rather than the column because a fifth slab under HOW TO PLAY
/// is what put the gear on top of the level picker the last time, and these
/// two are worth no vertical space at all next to PLAY.
///
/// The icons follow Play Games' own: a trophy for achievements, bars for
/// leaderboards. A player who has seen them anywhere else already knows which
/// is which.
class AchievementsButton extends StatelessWidget {
  const AchievementsButton({super.key});

  @override
  Widget build(BuildContext context) => _CornerButton(
    icon: Icons.emoji_events_rounded,
    tint: kTrophyInk,
    label: 'Show achievements',
    onPressed: Games.showAchievements,
  );
}

class LeaderboardButton extends StatelessWidget {
  const LeaderboardButton({super.key});

  @override
  Widget build(BuildContext context) => _CornerButton(
    icon: Icons.leaderboard_rounded,
    tint: kLeaderboardInk,
    label: 'Show leaderboards',
    onPressed: Games.showLeaderboards,
  );
}

/// Disconnects the games account from this game.
///
/// Not a platform sign-out, which is not on offer: Play Games Services v2
/// removed the API, so the session Google holds cannot be ended from here.
/// What it does do is everything the game controls - it forgets the player,
/// stops reporting scores and badges, and puts SIGN IN back on the menu.
///
/// Grey, and next to the gear. It is a thing a grown-up does once, not
/// something to compete with the trophy beside it.
class DisconnectButton extends StatelessWidget {
  const DisconnectButton({super.key});

  @override
  Widget build(BuildContext context) => _CornerButton(
    icon: Icons.link_off_rounded,
    tint: kDisconnectInk,
    label: 'Disconnect ${Games.serviceName}',
    onPressed: Games.disconnect,
  );
}

/// One round button, and the rule they all follow: nothing to sign in to,
/// or nobody signed in, means no button at all.
///
/// An empty leaderboard is not worth a control, and the corner must not change
/// width when somebody signs in mid-session.
class _CornerButton extends StatelessWidget {
  const _CornerButton({
    required this.icon,
    required this.tint,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final Color tint;
  final String label;
  /// Returns something or nothing; the button does not care which, so a
  /// handler that reports whether it worked can be passed straight in.
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    if (!Games.isSupported) return const SizedBox.shrink();

    return ValueListenableBuilder<String?>(
      valueListenable: Games.playerName,
      builder: (_, name, _) {
        if (name == null) return const SizedBox.shrink();
        return Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Audio.tap();
              unawaited(onPressed());
            },
            child: Container(
              width: kGearSize,
              height: kGearSize,
              decoration: const BoxDecoration(
                color: kMenuCard,
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: kMenuShadow,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: tint, size: kMenuIconSize),
            ),
          ),
        );
      },
    );
  }
}
