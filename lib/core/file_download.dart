import 'file_download_stub.dart'
    if (dart.library.js_interop) 'file_download_web.dart'
    as impl;

/// Saves [text] as a file in the browser's downloads. Returns false where
/// downloads are not supported.
bool downloadTextFile(
  String fileName,
  String text, {
  String mime = 'text/csv',
}) => impl.downloadTextFile(fileName, text, mime: mime);
