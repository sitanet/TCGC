import 'package:flutter/material.dart';
import 'dart:math' as math;

enum DeviceType { mobile, tablet, desktop }

class Responsive {
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;

  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return DeviceType.mobile;
    if (width < tabletBreakpoint) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  static bool isMobile(BuildContext context) =>
      getDeviceType(context) == DeviceType.mobile;

  static bool isTablet(BuildContext context) =>
      getDeviceType(context) == DeviceType.tablet;

  static bool isDesktop(BuildContext context) =>
      getDeviceType(context) == DeviceType.desktop;

  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static T value<T>(BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }

  static double fontSize(BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    return value(context, mobile: mobile, tablet: tablet, desktop: desktop);
  }

  static EdgeInsets padding(BuildContext context, {
    required EdgeInsets mobile,
    EdgeInsets? tablet,
    EdgeInsets? desktop,
  }) {
    return value(context, mobile: mobile, tablet: tablet, desktop: desktop);
  }

  static int gridCrossAxisCount(BuildContext context, {
    int mobile = 2,
    int tablet = 3,
    int desktop = 4,
  }) {
    return value(context, mobile: mobile, tablet: tablet, desktop: desktop);
  }

  static double gridChildAspectRatio(BuildContext context, {
    double mobile = 0.75,
    double tablet = 0.8,
    double desktop = 0.85,
  }) {
    return value(context, mobile: mobile, tablet: tablet, desktop: desktop);
  }

  static double horizontalPadding(BuildContext context) {
    return value(context, mobile: 16.0, tablet: 24.0, desktop: 32.0);
  }

  static double cardWidth(BuildContext context) {
    final width = screenWidth(context);
    if (isMobile(context)) return width - 32;
    if (isTablet(context)) return (width - 72) / 2;
    return (width - 128) / 3;
  }

  // New responsive helpers
  static double verticalSpacing(BuildContext context) {
    return value(context, mobile: 16.0, tablet: 20.0, desktop: 24.0);
  }

  static double buttonHeight(BuildContext context) {
    return value(context, mobile: 52.0, tablet: 56.0, desktop: 60.0);
  }

  static double iconSize(BuildContext context) {
    return value(context, mobile: 24.0, tablet: 28.0, desktop: 32.0);
  }

  static double avatarRadius(BuildContext context) {
    return value(context, mobile: 24.0, tablet: 32.0, desktop: 40.0);
  }

  static double logoSize(BuildContext context) {
    return value(context, mobile: 80.0, tablet: 100.0, desktop: 120.0);
  }

  static double maxContentWidth(BuildContext context) {
    return value(context, mobile: double.infinity, tablet: 600.0, desktop: 800.0);
  }

  static double eventCardHeight(BuildContext context) {
    return value(context, mobile: 180.0, tablet: 220.0, desktop: 260.0);
  }

  static double titleFontSize(BuildContext context) {
    return value(context, mobile: 28.0, tablet: 32.0, desktop: 36.0);
  }

  static double subtitleFontSize(BuildContext context) {
    return value(context, mobile: 20.0, tablet: 24.0, desktop: 28.0);
  }

  static double bodyFontSize(BuildContext context) {
    return value(context, mobile: 14.0, tablet: 16.0, desktop: 18.0);
  }

  static double smallFontSize(BuildContext context) {
    return value(context, mobile: 12.0, tablet: 14.0, desktop: 16.0);
  }

  static double borderRadius(BuildContext context) {
    return value(context, mobile: 12.0, tablet: 16.0, desktop: 20.0);
  }

  static double largeBorderRadius(BuildContext context) {
    return value(context, mobile: 24.0, tablet: 28.0, desktop: 32.0);
  }

  static double imageHeight(BuildContext context, {double baseHeight = 50.0}) {
    return value(
      context,
      mobile: baseHeight,
      tablet: baseHeight * 1.3,
      desktop: baseHeight * 1.5,
    );
  }

  static double navBarHeight(BuildContext context) {
    return value(context, mobile: 70.0, tablet: 80.0, desktop: 90.0);
  }

  static double navIconSize(BuildContext context) {
    return value(context, mobile: 24.0, tablet: 28.0, desktop: 32.0);
  }

  static double scale(BuildContext context) {
    final width = screenWidth(context);
    if (width < mobileBreakpoint) return 1.0;
    if (width < tabletBreakpoint) return 1.15;
    return 1.3;
  }

  static double sp(BuildContext context, double size) {
    return size * scale(context);
  }

  static double wp(BuildContext context, double percentage) {
    return screenWidth(context) * (percentage / 100);
  }

  static double hp(BuildContext context, double percentage) {
    return screenHeight(context) * (percentage / 100);
  }

  static double constrainedWidth(BuildContext context, {double maxWidth = 600}) {
    return math.min(screenWidth(context), maxWidth);
  }
}

class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, DeviceType deviceType) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return builder(context, Responsive.getDeviceType(context));
      },
    );
  }
}

class ResponsiveWidget extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveWidget({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType) {
        switch (deviceType) {
          case DeviceType.mobile:
            return mobile;
          case DeviceType.tablet:
            return tablet ?? mobile;
          case DeviceType.desktop:
            return desktop ?? tablet ?? mobile;
        }
      },
    );
  }
}
