import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'project_board_stub.dart'
    if (dart.library.js_interop) 'project_board_web.dart';

void projectRopeBoard(BuildContext context, String path) {
  if (kIsWeb && openBoardWindow(path)) return;
  context.go(path);
}
