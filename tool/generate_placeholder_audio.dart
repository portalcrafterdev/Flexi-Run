// Generates placeholder sound effects and a music loop into assets/audio/.
//
// Run with: dart run tool/generate_placeholder_audio.dart
//
// These are stand-ins in the same spirit as the code-drawn placeholder art:
// simple synthesised tones so the game is playable with sound today. When the
// commissioned audio arrives, drop the real files in and point the filenames in
// lib/core/audio.dart at them.

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const _rate = 22050;
const _outDir = 'assets/audio';

// Note frequencies, in Hz.
const _c3 = 130.81;
const _f3 = 174.61;
const _g3 = 196.00;
const _a3 = 220.00;
const _c5 = 523.25;
const _d5 = 587.33;
const _e5 = 659.25;
const _g5 = 783.99;
const _a5 = 880.00;
const _c6 = 1046.50;

void main() {
  Directory(_outDir).createSync(recursive: true);
  _write('music_loop.wav', _musicLoop());
  _write('pass.wav', _pass());
  _write('hit.wav', _hit());
  _write('shield.wav', _shield());
  _write('smash.wav', _smash());
  _write('gameover.wav', _gameOver());
}

void _write(String name, Float64List samples) {
  final file = File('$_outDir/$name');
  file.writeAsBytesSync(_wav(samples));
  final kb = (file.lengthSync() / 1024).round();
  stdout.writeln('wrote $_outDir/$name (${kb}kB)');
}

/// A cheerful four bar loop at 120 bpm: plucked melody over a simple bass.
Float64List _musicLoop() {
  const beat = 0.5;
  const bars = 4;
  final out = Float64List((_rate * beat * 4 * bars).round());

  const melody = <double>[
    _e5, _g5, _a5, _g5, //
    _e5, _d5, _c5, _d5, //
    _e5, _g5, _c6, _a5, //
    _g5, _e5, _d5, _c5, //
  ];
  for (var i = 0; i < melody.length; i++) {
    _mix(out, _pluck(melody[i], beat * 0.9, 0.22), (i * beat * _rate).round());
  }

  const bass = <double>[_c3, _a3, _f3, _g3];
  for (var i = 0; i < bass.length; i++) {
    _mix(
      out,
      _pluck(bass[i], beat * 3.6, 0.16, harmonic: 0.15),
      (i * beat * 4 * _rate).round(),
    );
  }
  return out;
}

/// Soft chime. The game raises the playback rate as a streak builds.
Float64List _pass() {
  final out = Float64List((_rate * 0.32).round());
  _mix(out, _pluck(_g5, 0.16, 0.3), 0);
  _mix(out, _pluck(_c6, 0.26, 0.3), (_rate * 0.08).round());
  return out;
}

/// Dull thud plus a little rubble.
Float64List _hit() {
  final out = Float64List((_rate * 0.42).round());
  _mix(out, _tone(90, 0.28, 0.42, decay: 14), 0);
  _mix(out, _noise(0.3, 0.16, decay: 11, seed: 3), 0);
  return out;
}

/// Sparkle rise for the shield being granted.
Float64List _shield() {
  final out = Float64List((_rate * 0.5).round());
  const notes = <double>[_c5, _e5, _g5, _c6];
  for (var i = 0; i < notes.length; i++) {
    _mix(out, _pluck(notes[i], 0.24, 0.24), (_rate * 0.06 * i).round());
  }
  return out;
}

/// Crunch for a wall smashed by the shield.
Float64List _smash() {
  final out = Float64List((_rate * 0.36).round());
  _mix(out, _noise(0.34, 0.3, decay: 9, seed: 11), 0);
  _mix(out, _tone(140, 0.2, 0.22, decay: 16), 0);
  return out;
}

/// Gentle descending three note phrase. Never harsh.
Float64List _gameOver() {
  final out = Float64List((_rate * 1.1).round());
  const notes = <double>[_g5, _e5, _c5];
  for (var i = 0; i < notes.length; i++) {
    _mix(out, _pluck(notes[i], 0.5, 0.26), (_rate * 0.26 * i).round());
  }
  return out;
}

/// A plucked note: sine plus a touch of second harmonic, exponential decay.
/// Reads as a music box, which suits the age group.
Float64List _pluck(
  double freq,
  double seconds,
  double gain, {
  double harmonic = 0.3,
}) {
  final n = (_rate * seconds).round();
  final out = Float64List(n);
  for (var i = 0; i < n; i++) {
    final t = i / _rate;
    final env = _attack(t) * exp(-t * 5.0);
    out[i] =
        gain *
        env *
        (sin(2 * pi * freq * t) + harmonic * sin(4 * pi * freq * t));
  }
  return out;
}

Float64List _tone(
  double freq,
  double seconds,
  double gain, {
  double decay = 8,
}) {
  final n = (_rate * seconds).round();
  final out = Float64List(n);
  for (var i = 0; i < n; i++) {
    final t = i / _rate;
    out[i] = gain * _attack(t) * exp(-t * decay) * sin(2 * pi * freq * t);
  }
  return out;
}

Float64List _noise(
  double seconds,
  double gain, {
  double decay = 10,
  int seed = 1,
}) {
  final n = (_rate * seconds).round();
  final rng = Random(seed);
  final out = Float64List(n);
  var last = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / _rate;
    // Low passed a little so it crumbles rather than hisses.
    last = last * 0.6 + (rng.nextDouble() * 2 - 1) * 0.4;
    out[i] = gain * exp(-t * decay) * last;
  }
  return out;
}

/// 5 ms fade in, so nothing starts with a click.
double _attack(double t) => t < 0.005 ? t / 0.005 : 1.0;

void _mix(Float64List target, Float64List source, int offset) {
  for (var i = 0; i < source.length; i++) {
    final at = offset + i;
    if (at >= target.length) break;
    target[at] += source[i];
  }
}

/// 16 bit mono PCM WAV.
Uint8List _wav(Float64List samples) {
  final dataLength = samples.length * 2;
  final bytes = BytesBuilder();

  void ascii(String s) => bytes.add(s.codeUnits);
  void u32(int v) =>
      bytes.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
  void u16(int v) =>
      bytes.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));

  ascii('RIFF');
  u32(36 + dataLength);
  ascii('WAVE');
  ascii('fmt ');
  u32(16);
  u16(1); // PCM
  u16(1); // mono
  u32(_rate);
  u32(_rate * 2); // byte rate
  u16(2); // block align
  u16(16); // bits per sample
  ascii('data');
  u32(dataLength);

  final pcm = Uint8List(dataLength);
  final view = pcm.buffer.asByteData();
  for (var i = 0; i < samples.length; i++) {
    final clamped = samples[i].clamp(-1.0, 1.0);
    view.setInt16(i * 2, (clamped * 32767).round(), Endian.little);
  }
  bytes.add(pcm);
  return bytes.toBytes();
}
