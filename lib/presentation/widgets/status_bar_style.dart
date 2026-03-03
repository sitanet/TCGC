import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Sets the status bar style for a page.
/// By default, status bar icons are white (Brightness.light).
/// Set [lightBackground] to true for white/light pages to make icons black.
class StatusBarStyle extends StatelessWidget {
  final Widget child;
  final bool lightBackground;

  const StatusBarStyle({
    super.key,
    required this.child,
    this.lightBackground = false,
  });

  /// White status bar icons (for dark backgrounds) - DEFAULT
  static const SystemUiOverlayStyle light = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );

  /// Black status bar icons (for light/white backgrounds)
  static const SystemUiOverlayStyle dark = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: lightBackground ? dark : light,
      child: child,
    );
  }
}
