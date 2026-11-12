import 'dart:typed_data';
import 'dart:ui' as ui;

/// Decodes [bytes], optionally scaled to [targetWidth] (height keeps aspect).
Future<ui.Image> decodeRopePng(Uint8List bytes, {int? targetWidth}) async {
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: targetWidth);
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}
