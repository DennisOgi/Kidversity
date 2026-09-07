import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'narration_service.dart';

/// Controlled Mandarin audio path.
///
/// Reviewed cloud audio wins when present. Browser/device TTS remains the
/// explicit fallback while Foundation V1 has no approved clip URL.
class MandarinAudioService {
  static final MandarinAudioService instance = MandarinAudioService._();
  MandarinAudioService._();

  final AudioPlayer _player = AudioPlayer();

  Future<void> play({
    required String text,
    String? audioUrl,
    double rate = 0.82,
  }) async {
    await stop();
    if (audioUrl != null && audioUrl.trim().isNotEmpty) {
      await _player.play(UrlSource(audioUrl));
      await _player.setPlaybackRate(rate < 0.7 ? 0.7 : 1);
      return;
    }
    debugPrint(
      'MandarinAudioService: no reviewed clip URL; using on-device Mandarin TTS.',
    );
    await NarrationService.instance.speak(text, lang: 'zh-CN', rate: rate);
  }

  Future<void> stop() async {
    await _player.stop();
    await NarrationService.instance.stop();
  }
}
