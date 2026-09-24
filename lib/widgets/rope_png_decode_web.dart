import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui' as ui;

@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external _Blob(JSArray<JSAny> parts, _BlobOptions options);
}

@JS()
@anonymous
extension type _BlobOptions._(JSObject _) implements JSObject {
  external factory _BlobOptions({String type});
}

@JS('URL.createObjectURL')
external String _createObjectUrl(JSObject blob);

@JS('URL.revokeObjectURL')
external void _revokeObjectUrl(String url);

@JS('Image')
extension type _DomImage._(JSObject _) implements JSObject {
  external _DomImage();
  external set src(String value);
  external int get naturalWidth;
  external int get naturalHeight;
  external set onload(JSFunction? value);
  external set onerror(JSFunction? value);
}

@JS('document.createElement')
external JSObject _createElement(String tag);

extension type _Canvas._(JSObject _) implements JSObject {
  external set width(int value);
  external set height(int value);
  external _Context getContext(String type);
}

extension type _Context._(JSObject _) implements JSObject {
  external void drawImage(_DomImage image, num x, num y);
  external _ImageData getImageData(int x, int y, int width, int height);
}

extension type _ImageData._(JSObject _) implements JSObject {
  external JSUint8ClampedArray get data;
}

/// Browser decode. CanvasKit's PNG codec throws EncodingError on these files,
/// while an HTML image loads them.
Future<ui.Image> decodeRopePng(Uint8List bytes) async {
  final blob = _Blob([bytes.toJS].toJS, _BlobOptions(type: 'image/png'));
  final url = _createObjectUrl(blob);
  try {
    final image = _DomImage();
    final loaded = Completer<void>();
    image.onload = (() {
      if (!loaded.isCompleted) loaded.complete();
    }).toJS;
    image.onerror = (() {
      if (!loaded.isCompleted) {
        loaded.completeError(StateError('browser image decode failed'));
      }
    }).toJS;
    image.src = url;
    await loaded.future;
    final width = image.naturalWidth;
    final height = image.naturalHeight;
    if (width == 0 || height == 0) {
      throw StateError('browser image decode failed');
    }
    final canvas = _Canvas._(_createElement('canvas'));
    canvas.width = width;
    canvas.height = height;
    final context = canvas.getContext('2d');
    context.drawImage(image, 0, 0);
    final pixels = Uint8List.fromList(
      context.getImageData(0, 0, width, height).data.toDart,
    );
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  } finally {
    _revokeObjectUrl(url);
  }
}
