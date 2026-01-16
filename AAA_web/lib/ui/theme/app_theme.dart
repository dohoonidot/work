import 'package:flutter/material.dart';
import 'package:ASPN_AI_AGENT/ui/theme/color_schemes.dart';

class AppTheme {
  static ThemeData getThemeData(AppColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Spoqa Han Sans Neo',
      colorScheme: ColorScheme(
        brightness: _getBrightness(colorScheme),
        primary: colorScheme.primaryColor,
        onPrimary: colorScheme.onPrimaryColor,
        secondary: colorScheme.secondaryColor,
        onSecondary: colorScheme.onSecondaryColor,
        surface: colorScheme.surfaceColor,
        onSurface: colorScheme.onSurfaceColor,
        background: colorScheme.backgroundColor,
        onBackground: colorScheme.onBackgroundColor,
        error: colorScheme.errorColor,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.appBarBackgroundColor,
        foregroundColor: colorScheme.appBarTextColor,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.appBarTextColor),
        titleTextStyle: TextStyle(
          color: colorScheme.appBarTextColor,
          fontSize: 20,
          fontWeight: FontWeight.w500,
          fontFamily: 'Spoqa Han Sans Neo',
        ),
      ),
      scaffoldBackgroundColor: colorScheme.backgroundColor,
      cardTheme: CardThemeData(
        color: colorScheme.surfaceColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primaryColor,
          foregroundColor: colorScheme.onPrimaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primaryColor,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colorScheme.onBackgroundColor,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.chatInputBackgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.textFieldBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
              color: colorScheme.textFieldBorderColor.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: colorScheme.textFieldBorderColor, width: 2),
        ),
      ),
      // 텍스트 테마 설정
      textTheme: TextTheme(
        bodyLarge: TextStyle(
          fontFamily: 'Spoqa Han Sans Neo',
          color: colorScheme.onBackgroundColor,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Spoqa Han Sans Neo',
          color: colorScheme.onBackgroundColor,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Spoqa Han Sans Neo',
          color: colorScheme.onBackgroundColor,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Spoqa Han Sans Neo',
          color: colorScheme.onBackgroundColor,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Spoqa Han Sans Neo',
          color: colorScheme.onBackgroundColor,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: TextStyle(
          fontFamily: 'Spoqa Han Sans Neo',
          color: colorScheme.onBackgroundColor,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Spoqa Han Sans Neo',
          color: colorScheme.onBackgroundColor,
        ),
        labelMedium: TextStyle(
          fontFamily: 'Spoqa Han Sans Neo',
          color: colorScheme.onBackgroundColor,
        ),
        labelSmall: TextStyle(
          fontFamily: 'Spoqa Han Sans Neo',
          color: colorScheme.onBackgroundColor,
        ),
      ),
    );
  }

  static Brightness _getBrightness(AppColorScheme colorScheme) {
    return colorScheme.backgroundColor.computeLuminance() > 0.5
        ? Brightness.light
        : Brightness.dark;
  }
}
