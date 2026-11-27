import 'dart:js_interop';

@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external factory _Blob(JSArray<JSAny> parts, _BlobOptions options);
}

extension type _BlobOptions._(JSObject _) implements JSObject {
  external factory _BlobOptions({JSString type});
}

@JS('URL.createObjectURL')
external JSString _createObjectUrl(_Blob blob);

@JS('URL.revokeObjectURL')
external void _revokeObjectUrl(JSString url);

@JS('document.createElement')
external _Anchor _createElement(JSString tag);

extension type _Anchor._(JSObject _) implements JSObject {
  external set href(JSString value);
  external set download(JSString value);
  external void click();
}

bool downloadTextFile(
  String fileName,
  String text, {
  String mime = 'text/csv',
}) {
  // A byte-order mark lets Excel open UTF-8 CSV files with names intact.
  final blob = _Blob(
    ['﻿$text'.toJS].toJS,
    _BlobOptions(type: '$mime;charset=utf-8'.toJS),
  );
  final url = _createObjectUrl(blob);
  final a = _createElement('a'.toJS)
    ..href = url
    ..download = fileName.toJS;
  a.click();
  _revokeObjectUrl(url);
  return true;
}
