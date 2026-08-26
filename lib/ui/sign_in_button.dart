import 'dart:async';

import 'package:flutter/material.dart';

import '../core/audio.dart';
import '../core/constants.dart';
import '../core/games.dart';
import 'menu_widgets.dart';

/// Sign in to Play Games or Game Center, and the signed-in state afterwards.
///
/// Last in the column and deliberately quiet. A game account is worth having -
/// it is what a saved best score and a leaderboard would hang off - but it is
/// not what a child came to this screen for, and it must never compete with
/// PLAY. Pale slab, dark ink, no icon shouting for attention.
///
/// It takes up no room at all on a platform with nothing to sign in to, so a
/// desktop or web build simply does not have it.
class SignInButton extends StatelessWidget {
  const SignInButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Games.isSupported) return const SizedBox.shrink();

    return ValueListenableBuilder<String?>(
      valueListenable: Games.playerName,
      builder: (_, name, _) => ValueListenableBuilder<bool>(
        valueListenable: Games.busy,
        builder: (_, busy, _) {
          if (name != null) return _SignedIn(name: name);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Above the button, not under it. Under it the line lands in the
              // bottom strip of the screen, which is where the banner sits,
              // and half of it disappeared behind an advert.
              const _FailureNote(),
              const SizedBox(height: kMenuButtonGap * 0.3),
              ChunkyButton(
                // Named after the platform's own service. Calling Game Center
                // "Play Games" on an iPhone reads as a port of someone else's
                // game that nobody finished.
                label: busy
                    ? 'SIGNING IN…'
                    : 'SIGN IN TO ${Games.serviceName.toUpperCase()}',
                icon: Icons.sports_esports_rounded,
                fill: kSignInFill,
                edge: kSignInEdge,
                ink: kSignInInk,
                onPressed: busy ? () {} : () => unawaited(Games.signIn()),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Who is signed in, and the way through to their badges.
///
/// The only place achievements are reachable from, and it costs the menu
/// nothing: a fifth slab in that column is what put the settings gear on top
/// of the level picker the last time, and this row is already on screen for
/// exactly the players who have anything to look at.
class _SignedIn extends StatelessWidget {
  const _SignedIn({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Signed in to ${Games.serviceName} as $name. Show achievements',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Audio.tap();
          unawaited(Games.showAchievements());
        },
        child: _pill(),
      ),
    );
  }

  Widget _pill() {
    return Container(
      height: kMenuButtonH,
      padding: const EdgeInsets.symmetric(horizontal: kMenuButtonGap),
      decoration: BoxDecoration(
        color: kSignInFill,
        borderRadius: BorderRadius.circular(kMenuButtonRadius),
        border: Border.all(color: kSignInEdge, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(
            Icons.check_circle_rounded,
            size: kMenuIconSize,
            color: kPlayFill,
          ),
          const SizedBox(width: kMenuButtonGap * 0.6),
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: kMenuTaglineSize,
                fontWeight: FontWeight.w800,
                color: kSignInInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One line, only after a press that failed.
class _FailureNote extends StatelessWidget {
  const _FailureNote();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Games.failed,
      builder: (_, failed, _) {
        if (!failed) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: kMenuButtonGap * 0.2),
          child: Text(
            // Says what happened and stops. No error code, no retry advice:
            // the button is right there and the game does not need it.
            '${Games.serviceName} could not sign in.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: kSignInNoteSize,
              fontWeight: FontWeight.w600,
              color: kSignInFailInk,
            ),
          ),
        );
      },
    );
  }
}
