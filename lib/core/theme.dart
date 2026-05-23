import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class GharsTheme {
  static ThemeData get light {
    final base = ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: GharsColors.charcoal900,
      colorScheme: const ColorScheme.light(
        surface:     GharsColors.charcoal900,
        primary:     GharsColors.green,
        onPrimary:   Colors.white,
        secondary:   GharsColors.gold,
        onSecondary: GharsColors.textPrimary,
      ),
      textTheme: GoogleFonts.cairoTextTheme(base.textTheme).apply(
        bodyColor:    GharsColors.textPrimary,
        displayColor: GharsColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor:         GharsColors.charcoal900,
        elevation:               0,
        scrolledUnderElevation:  0,
        centerTitle:             false,
        systemOverlayStyle:      SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.cairo(
          fontSize:   20,
          fontWeight: FontWeight.w700,
          color:      GharsColors.gold,
        ),
        iconTheme: const IconThemeData(color: GharsColors.textPrimary),
      ),
      dividerColor:  GharsColors.charcoal700,
      cardColor:     GharsColors.charcoal800,
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: GharsColors.green,
      ),
    );
  }

  /// Keep for backward compat — resolves to light.
  static ThemeData get dark => light;
}
