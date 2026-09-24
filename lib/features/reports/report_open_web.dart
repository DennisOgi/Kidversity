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

@JS('window.open')
external JSAny? _open(JSString url, JSString target);

bool openHtmlDocument(String html) {
  final blob = _Blob(
    [html.toJS].toJS,
    _BlobOptions(type: 'text/html;charset=utf-8'.toJS),
  );
  _open(_createObjectUrl(blob), '_blank'.toJS);
  return true;
}
