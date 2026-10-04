import 'package:flutter/material.dart';

/// Exact A320 CIDS FAP palette (see project instructions §2) plus the
/// CIDS colour convention: green = active/OK, amber = caution,
/// red = alarm, white = neutral information.
class FapColors {
  FapColors._();

  static const screenBg = Color(0xFF13212E);
  static const statusBar = Color(0xFF09131C);
  static const panel = Color(0xFF1A2C3D);
  static const panelBorder = Color(0xFF34506B);
  static const panelTitle = Color(0xFF223A50);

  static const activeGreen = Color(0xFF00FF44);
  static const okGreen = Color(0xFF00E040);
  static const inactive = Color(0xFF2C4257);
  static const inactiveHighlight = Color(0xFF4A6782);
  static const inactiveShadow = Color(0xFF15222F);
  static const disabled = Color(0xFF24323F);
  static const disabledText = Color(0xFF5F7387);

  static const red = Color(0xFFFF2D2D);
  static const amber = Color(0xFFFFB000);
  static const gold = Color(0xFFFFD700);
  static const cyan = Color(0xFF00E5FF);
  static const white = Color(0xFFFFFFFF);
  static const textDim = Color(0xFF9DB0C3);

  static const bezelLight = Color(0xFFC2C8CF);
  static const bezelDark = Color(0xFF8C95A0);

  // AISAT brand
  static const aisatCyan = Color(0xFF00A2E8);
  static const aisatSilver = Color(0xFFA8B2D1);
  static const landingBg = Color(0xFF0A1520);
}

class FapText {
  FapText._();

  static const mono = 'JetBrainsMono';

  static const title = TextStyle(
    color: FapColors.white,
    fontSize: 18,
    fontWeight: FontWeight.w800,
    letterSpacing: 3,
  );

  static const panelTitle = TextStyle(
    color: FapColors.white,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.6,
  );

  static const label = TextStyle(
    color: FapColors.textDim,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1,
  );

  static const body = TextStyle(
    color: FapColors.white,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static TextStyle monoStyle({
    double size = 14,
    Color color = FapColors.white,
    FontWeight weight = FontWeight.w400,
  }) => TextStyle(
    fontFamily: mono,
    fontSize: size,
    color: color,
    fontWeight: weight,
  );
}

ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: FapColors.screenBg,
    colorScheme: const ColorScheme.dark(
      primary: FapColors.activeGreen,
      secondary: FapColors.cyan,
      surface: FapColors.panel,
      error: FapColors.red,
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: FapColors.activeGreen,
      inactiveTrackColor: FapColors.inactive,
      thumbColor: FapColors.white,
      overlayColor: Color(0x3300FF44),
      trackHeight: 6,
    ),
    useMaterial3: true,
  );
}
