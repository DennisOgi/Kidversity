import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mute-first courtyard cues. Uses the existing audioplayers dependency.
class RopePullCueService {
  RopePullCueService({AudioPlayer? player})
    : _player = player ?? AudioPlayer(),
      _ownsPlayer = player == null;

  static const prefKey = 'kidversity_rope_pull_sound';

  static const files = {
    'correct': 'rope_pull/audio/correct.wav',
    'incorrect': 'rope_pull/audio/incorrect.wav',
    'countdown': 'rope_pull/audio/countdown.wav',
    'start': 'rope_pull/audio/start.wav',
    'win': 'rope_pull/audio/win.wav',
  };

  final AudioPlayer _player;
  final bool _ownsPlayer;
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
      await _player.stop();
    }
  }

  Future<void> play(String name) async {
    if (!enabled) return;
    final path = files[name];
    if (path == null) return;
    try {
      await _player.stop();
      await _player.play(AssetSource(path));
    } catch (error) {
      debugPrint('RopePullCueService: could not play $name ($error)');
    }
  }

  Future<void> dispose() async {
    if (_ownsPlayer) {
      await _player.dispose();
    }
  }
}
