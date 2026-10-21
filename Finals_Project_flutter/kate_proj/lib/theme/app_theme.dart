import 'package:flutter/material.dart';

abstract final class LovelleColors {
  static const blush = Color(0xFFFFF4F5);
  static const rose = Color(0xFFDB6791);
  static const roseDark = Color(0xFF9D476A);
  static const palePink = Color(0xFFFFE5EB);
  static const cream = Color(0xFFFFFAF5);
  static const plum = Color(0xFF49343F);
  static const mauve = Color(0xFF806A76);
  static const sage = Color(0xFF5E8A70);
  static const border = Color(0xFFF2DCE4);
}

abstract final class LovelleTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: LovelleColors.rose,
      primary: LovelleColors.rose,
      surface: LovelleColors.cream,
      onSurface: LovelleColors.plum,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: LovelleColors.blush,
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: LovelleColors.plum,
          fontSize: 25,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
        titleLarge: TextStyle(
          color: LovelleColors.plum,
          fontSize: 21,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: LovelleColors.plum,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: LovelleColors.plum,
          fontSize: 15,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          color: LovelleColors.mauve,
          fontSize: 14,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: .1,
        ),
      ),
      dividerColor: LovelleColors.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: LovelleColors.blush,
        foregroundColor: LovelleColors.plum,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: LovelleColors.plum,
          fontSize: 21,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: LovelleColors.border),
        ),
      ),
      iconTheme: const IconThemeData(color: LovelleColors.mauve),
      listTileTheme: const ListTileThemeData(
        iconColor: LovelleColors.rose,
        textColor: LovelleColors.plum,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: LovelleColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: LovelleColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: LovelleColors.rose, width: 1.6),
        ),
        labelStyle: const TextStyle(color: LovelleColors.mauve),
        hintStyle: const TextStyle(color: LovelleColors.mauve),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: LovelleColors.rose,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: LovelleColors.rose,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: LovelleColors.roseDark,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: LovelleColors.border),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: LovelleColors.palePink,
        side: const BorderSide(color: LovelleColors.border),
        shape: const StadiumBorder(),
        labelStyle: const TextStyle(color: LovelleColors.plum),
        secondaryLabelStyle: const TextStyle(color: LovelleColors.roseDark),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: LovelleColors.palePink,
        elevation: 8,
        height: 70,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? LovelleColors.roseDark
                  : LovelleColors.mauve,
            )),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: LovelleColors.plum,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: LovelleColors.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: const TextStyle(
          color: LovelleColors.plum,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: const TextStyle(
          color: LovelleColors.mauve,
          height: 1.4,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: LovelleColors.rose,
      ),
    );
  }
}
