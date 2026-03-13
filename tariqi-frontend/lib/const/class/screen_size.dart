import 'package:flutter/material.dart';
/// A utility class for retrieving and storing screen size information.
///
/// The `ScreenSize` class provides static methods and properties to
/// initialize and access the screen width and height using the
/// `MediaQueryData` from the given `BuildContext`.
///
/// Usage:
/// - Call `ScreenSize.init(context)` to initialize the screen dimensions.
/// - Access `ScreenSize.screenWidth` and `ScreenSize.screenHeight` to
///   retrieve the current screen width and height, respectively.

class ScreenSize {
  static MediaQueryData? _mediaQueryData;
  static double? screenWidth;
  static double? screenHeight;

  static void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData!.size.width;
    screenHeight = _mediaQueryData!.size.height;
  }
}
