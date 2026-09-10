import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'narration_service.dart';
import 'supabase_service.dart';

/// Controlled Mandarin audio path.
///
/// Reviewed cloud audio wins when present. Browser/device TTS remains the
/// explicit fallback while Foundation V1 has no approved clip URL.
class MandarinAudioService {
  static final MandarinAudioService instance = MandarinAudioService._();
  MandarinAudioService._();

  static const _storagePrefix = 'storage:';
  static const _signTtl = Duration(seconds: 3600);

  final AudioPlayer _player = AudioPlayer();
  final Map<String, ({String url, DateTime expires})> _signed = {};

  Future<String?> resolveUrl(String? audioUrl) async {
    if (audioUrl == null) return null;
    final value = audioUrl.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    final path = value.startsWith(_storagePrefix)
        ? value.substring(_storagePrefix.length)
        : value;
    final cached = _signed[path];
    if (cached != null &&
        cached.expires.isAfter(DateTime.now().add(const Duration(minutes: 2)))) {
      return cached.url;
    }
    final service = SupabaseService.instance;
    if (!service.isInitialized) return null;
    final url = await service.client.storage
        .from('mandarin-audio')
        .createSignedUrl(path, _signTtl.inSeconds);
    _signed[path] = (
      url: url,
      expires: DateTime.now().add(_signTtl - const Duration(minutes: 5)),
    );
    return url;
  }

  Future<void> play({
    required String text,
    String? audioUrl,
    double rate = 0.82,
  }) async {
    await stop();
    final resolved = await resolveUrl(audioUrl);
    if (resolved != null && resolved.isNotEmpty) {
      await _player.play(UrlSource(resolved));
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
