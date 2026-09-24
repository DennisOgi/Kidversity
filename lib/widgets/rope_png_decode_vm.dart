import 'dart:typed_data';
import 'dart:ui' as ui;

Future<ui.Image> decodeRopePng(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}
