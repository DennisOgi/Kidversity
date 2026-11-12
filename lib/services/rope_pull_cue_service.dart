import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mute-first courtyard cues. Uses the existing audioplayers dependency.
///
/// Cues play on a small pool of players so they can overlap: a "correct"
/// chime no longer cuts off the countdown or the win fanfare.
class RopePullCueService {
  RopePullCueService({List<AudioPlayer>? players, int poolSize = 3})
    : _players = players ?? List.generate(poolSize, (_) => AudioPlayer()),
      _ownsPlayers = players == null;

  static const prefKey = 'kidversity_rope_pull_sound';

  static const files = {
    'correct': 'rope_pull/audio/correct.wav',
    'incorrect': 'rope_pull/audio/incorrect.wav',
    'countdown': 'rope_pull/audio/countdown.wav',
    'start': 'rope_pull/audio/start.wav',
    'win': 'rope_pull/audio/win.wav',
  };

  final List<AudioPlayer> _players;
  final bool _ownsPlayers;
  int _next = 0;
  bool enabled = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    enabled = prefs.getBool(prefKey) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, value);
    if (!value) {
      for (final player in _players) {
        await player.stop();
      }
    }
  }

  Future<void> play(String name) async {
    if (!enabled || _players.isEmpty) return;
    final path = files[name];
    if (path == null) return;
    // The oldest player in the pool is reused, so at most a few cues overlap.
    final player = _players[_next % _players.length];
    _next++;
    try {
      await player.stop();
      await player.play(AssetSource(path));
    } catch (error) {
      debugPrint('RopePullCueService: could not play $name ($error)');
    }
  }

  Future<void> dispose() async {
    if (!_ownsPlayers) return;
    for (final player in _players) {
      await player.dispose();
    }
  }
}
