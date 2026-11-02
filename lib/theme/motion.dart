import 'package:flutter/widgets.dart';

/// Motion tokens from Emil Kowalski's design-eng rules, mapped to Flutter.
/// Enter/press: strong ease-out. On-screen morph: ease-in-out. Never ease-in.
class AppMotion {
  AppMotion._();

  /// cubic-bezier(0.23, 1, 0.32, 1)
  static const Curve easeOut = Cubic(0.23, 1, 0.32, 1);

  /// cubic-bezier(0.77, 0, 0.175, 1)
  static const Curve easeInOut = Cubic(0.77, 0, 0.175, 1);

  static const Duration press = Duration(milliseconds: 140);
  static const Duration hint = Duration(milliseconds: 160);
  static const Duration panel = Duration(milliseconds: 200);

  static const double pressScale = 0.97;

  static bool reduce(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  static Duration of(BuildContext context, Duration duration) =>
      reduce(context) ? Duration.zero : duration;

  static Curve curve(BuildContext context, [Curve fallback = easeOut]) =>
      reduce(context) ? Curves.linear : fallback;
}
