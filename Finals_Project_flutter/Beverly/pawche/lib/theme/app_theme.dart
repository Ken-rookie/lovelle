import 'package:flutter/material.dart';

class PawcheColors {
  static const pink = Color(0xFFFF3F83);
  static const darkPink = Color(0xFFD92D6C);
  static const blush = Color(0xFFFFE8EF);
  static const pale = Color(0xFFFFF8FA);
  static const navy = Color(0xFF18385C);
  static const muted = Color(0xFF7B8BA0);
  static const border = Color(0xFFF0D5DF);
  static const green = Color(0xFF21A675);
}

class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: PawcheColors.pink,
      surface: Colors.white,
    ).copyWith(
      primary: PawcheColors.pink,
      onPrimary: Colors.white,
      secondary: PawcheColors.navy,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: PawcheColors.navy,
      error: const Color(0xFFB3261E),
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: PawcheColors.border),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: PawcheColors.pale,
      appBarTheme: const AppBarTheme(
        backgroundColor: PawcheColors.pale,
        foregroundColor: PawcheColors.navy,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: PawcheColors.navy,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        prefixIconColor: PawcheColors.muted,
        suffixIconColor: PawcheColors.muted,
        labelStyle: const TextStyle(color: PawcheColors.muted),
        hintStyle: const TextStyle(color: PawcheColors.muted),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: PawcheColors.pink, width: 1.5),
        ),
        errorBorder: border.copyWith(
          borderSide: const BorderSide(color: Color(0xFFB3261E)),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: const BorderSide(color: Color(0xFFB3261E), width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: PawcheColors.pink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: PawcheColors.pink.withValues(alpha: .45),
          disabledForegroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PawcheColors.navy,
          minimumSize: const Size(48, 46),
          side: const BorderSide(color: PawcheColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: PawcheColors.blush,
        elevation: 8,
        height: 66,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? PawcheColors.darkPink
                : PawcheColors.muted,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: PawcheColors.blush,
        side: const BorderSide(color: PawcheColors.border),
        labelStyle: const TextStyle(
          color: PawcheColors.navy,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: PawcheColors.navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerColor: PawcheColors.border,
    );
  }
}
