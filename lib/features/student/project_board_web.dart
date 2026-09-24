import 'dart:js_interop';

@JS('window.location.origin')
external JSString get _boardOrigin;

@JS('window.open')
external void _openBoard(JSString url, JSString target);

bool openBoardWindow(String path) {
  _openBoard('${_boardOrigin.toDart}$path'.toJS, '_blank'.toJS);
  return true;
}
