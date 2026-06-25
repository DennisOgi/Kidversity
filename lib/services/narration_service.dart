import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Thin wrapper around [FlutterTts] that powers slide narration and
/// pronunciation playback.
///
/// On the web this uses the browser's built-in SpeechSynthesis engine, which
/// ships free Mandarin (`zh-CN`) voices on most modern OSes — no API keys, no
/// network audio files required. The same code path works on Android/iOS using
/// the on-device TTS engines.
///
/// For higher-fidelity, consistent narration in production you can swap the
/// implementation here for a cloud TTS provider (Google / Azure / ElevenLabs)
/// without touching the UI.
class NarrationService {
  NarrationService._();
  static final NarrationService instance = NarrationService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialised = false;
  String _lang = 'en-US';

  VoidCallback? _onComplete;

  Future<void> _ensureInit() async {
    if (_initialised) return;
    _initialised = true;
    await _tts.awaitSpeakCompletion(true);
    _tts.setCompletionHandler(() => _onComplete?.call());
    _tts.setCancelHandler(() {});
    _tts.setErrorHandler((_) => _onComplete?.call());
  }

  /// Approximate how long [text] will take to read so the UI scrubber can
  /// animate smoothly (TTS engines don't report duration up-front).
  Duration estimateDuration(String text, {double rate = 1.0}) {
    // ~2.6 spoken syllables/words per second feels natural for kids' pacing.
    final units = text.runes.length > text.split(RegExp(r'\s+')).length * 3
        ? text.runes.length / 1.8 // CJK: count characters
        : text.split(RegExp(r'\s+')).length.toDouble();
    final seconds = (units / 2.4 / rate).clamp(2.0, 30.0);
    return Duration(milliseconds: (seconds * 1000).round());
  }

  Future<void> speak(
    String text, {
    String lang = 'en-US',
    double rate = 0.9,
    double pitch = 1.05,
    VoidCallback? onComplete,
  }) async {
    await _ensureInit();
    _onComplete = onComplete;
    if (lang != _lang) {
      _lang = lang;
      try {
        await _tts.setLanguage(lang);
      } catch (_) {/* voice may be unavailable; engine falls back */}
    }
    // Web rate is roughly 0..1 around 0.5 = normal; mobile uses similar range.
    await _tts.setSpeechRate(rate.clamp(0.0, 1.0));
    await _tts.setPitch(pitch);
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    _onComplete = null;
    await _tts.stop();
  }
}
