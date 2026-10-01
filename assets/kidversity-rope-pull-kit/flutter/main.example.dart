// Optional local demo entry point, not a replacement for your application's main.dart.
import 'package:flutter/material.dart';
import 'rope_pull_demo.dart';
void main() => runApp(MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4433CC))),
  home: const RopePullDemoPage(),
));
