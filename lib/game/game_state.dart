enum GameState {
  /// World scrolls slowly behind the title, no walls spawn.
  menu,

  /// Normal play.
  running,

  /// Freeze frame with screen shake, then back to [running] if lives remain.
  hit,

  /// World stops, overlay shows score and high score.
  gameOver,
}

/// Names of the Flutter overlays the game switches between.
abstract final class Overlays {
  static const menu = 'menu';
  static const hud = 'hud';
  static const pad = 'pad';
  static const gameOver = 'gameOver';

  static const all = <String>[menu, hud, pad, gameOver];

  /// Stacking order, lowest first. Flame sorts the active overlays by this,
  /// and leaves the order undefined when they tie, so every overlay names its
  /// own layer rather than relying on the order they happened to be added in.
  ///
  /// [pad] has to sit *below* [hud]: the tap-anywhere layer inside it fills
  /// the screen, so anything stacked under it - the pause button in
  /// particular - can never be tapped.
  static const _priorities = <String, int>{
    pad: 10,
    hud: 20,
    menu: 30,
    gameOver: 30,
  };

  static int priorityOf(String name) => _priorities[name] ?? 0;

  /// The overlays that belong on screen in [state].
  static Set<String> forState(GameState state) {
    switch (state) {
      case GameState.menu:
        return const <String>{menu};
      case GameState.running:
      case GameState.hit:
        return const <String>{hud, pad};
      case GameState.gameOver:
        return const <String>{gameOver};
    }
  }
}
