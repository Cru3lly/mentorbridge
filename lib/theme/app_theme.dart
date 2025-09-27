import 'package:flutter/material.dart';

/// 🎨 Global Color Configuration - Single source of truth for all colors
class GlobalColors {
  // GLOBAL THEME COLOR - Change this to update entire app theme
  static Color _globalThemeColor = const Color(0xFF007AFF); // iOS Blue

  /// Get current global theme color
  static Color get themeColor => _globalThemeColor;

  /// Update global theme color - this will affect all components using it
  static void setThemeColor(Color newColor) {
    _globalThemeColor = newColor;
  }

  /// Generate color variants from global theme color
  static Color get themeColorLight =>
      HSLColor.fromColor(_globalThemeColor).withLightness(0.8).toColor();
  static Color get themeColorDark =>
      HSLColor.fromColor(_globalThemeColor).withLightness(0.3).toColor();
  static Color get themeColorVariant =>
      HSLColor.fromColor(_globalThemeColor).withLightness(0.6).toColor();
}

class AppColors {
  // 🌟 DYNAMIC PRIMARY COLORS - Based on global theme
  static Color get primary => GlobalColors.themeColor;
  static Color get primaryVariant => GlobalColors.themeColorDark;
  static Color get primaryLight => GlobalColors.themeColorLight;

  // 🎯 NEUTRAL COLORS - Consistent across themes
  static const Color neutral900 = Color(0xFF1C1C1E);
  static const Color neutral800 = Color(0xFF2C2C2E);
  static const Color neutral600 = Color(0xFF636366);
  static const Color neutral400 = Color(0xFF8E8E93);
  static const Color neutral200 = Color(0xFFE5E5EA);
  static const Color neutral100 = Color(0xFFF2F2F7);
  static const Color neutral50 = Color(0xFFFAFAFA);

  // 🌅 BACKGROUND COLORS - Clean and minimal
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color backgroundDark = Color(0xFF000000);

  // 📄 SURFACE COLORS - Cards and containers
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1C1C1E);

  // ✍️ TEXT COLORS - High contrast for readability
  static const Color textPrimaryLight = Color(0xFF1C1C1E);
  static const Color textSecondaryLight = Color(0xFF636366);
  static const Color textTertiaryLight = Color(0xFF8E8E93);

  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFF8E8E93);
  static const Color textTertiaryDark = Color(0xFF636366);

  // 🃏 CARD COLORS - Clean containers
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF2C2C2E);
  static const Color borderLight = Color(0xFFE5E5EA);
  static const Color borderDark = Color(0xFF38383A);

  // 🚦 STATUS COLORS - iOS style semantic colors
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9500);
  static const Color error = Color(0xFFFF3B30);
  static const Color info = Color(0xFF5AC8FA);

  // 🎨 HABIT COLORS - Consistent palette for habits
  static const List<Color> habitColors = [
    Color(0xFF34C759), // Green
    Color(0xFF007AFF), // Blue
    Color(0xFFAF52DE), // Purple
    Color(0xFFFF9500), // Orange
    Color(0xFFFF2D92), // Pink
    Color(0xFF5AC8FA), // Light Blue
    Color(0xFFFFCC02), // Yellow
    Color(0xFFFF6B6B), // Coral
    Color(0xFF4ECDC4), // Teal
    Color(0xFF45B7D1), // Sky Blue
  ];

  /// Get dynamic accent colors based on global theme
  static Color get accent => primary;
  static Color get accentLight => primaryLight;
  static Color get accentDark => primaryVariant;
}

class AppTextStyles {
  // Clean, minimal text styles
  static const TextStyle title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle subheadline = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    height: 1.4,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Standard screen padding
  static const double screenPadding = 16.0;
  static const double cardPadding = 16.0;
  static const double sectionSpacing = 24.0;
}

class AppBorderRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double card = 12.0;
  static const double button = 8.0;
}

class AppElevation {
  static const double none = 0.0;
  static const double minimal = 1.0;
  static const double card = 2.0;
  static const double modal = 8.0;
}

class AppTheme {
  /// Generate light theme with current global colors
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        fontFamily: 'NotoSans',
        colorScheme: ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.primary,
          surface: AppColors.surfaceLight,
          background: AppColors.backgroundLight,
          error: AppColors.error,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: AppColors.textPrimaryLight,
          onBackground: AppColors.textPrimaryLight,
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        canvasColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: AppColors.textPrimaryLight),
          titleTextStyle: TextStyle(
            color: AppColors.textPrimaryLight,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'NotoSans',
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.surfaceLight,
          elevation: AppElevation.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.card),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: AppElevation.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.button),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: AppTextStyles.title,
          headlineMedium: AppTextStyles.headline,
          titleLarge: AppTextStyles.subheadline,
          bodyLarge: AppTextStyles.body,
          bodyMedium: AppTextStyles.bodySecondary,
          labelLarge: AppTextStyles.button,
          bodySmall: AppTextStyles.caption,
        ).apply(
          bodyColor: AppColors.textPrimaryLight,
          displayColor: AppColors.textPrimaryLight,
        ),
      );

  /// Generate dark theme with current global colors
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        fontFamily: 'NotoSans',
        colorScheme: ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.primary,
          surface: AppColors.surfaceDark,
          background: AppColors.backgroundDark,
          error: AppColors.error,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: AppColors.textPrimaryDark,
          onBackground: AppColors.textPrimaryDark,
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        canvasColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: AppColors.textPrimaryDark),
          titleTextStyle: TextStyle(
            color: AppColors.textPrimaryDark,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'NotoSans',
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.surfaceDark,
          elevation: AppElevation.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.card),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: AppElevation.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.button),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: AppTextStyles.title,
          headlineMedium: AppTextStyles.headline,
          titleLarge: AppTextStyles.subheadline,
          bodyLarge: AppTextStyles.body,
          bodyMedium: AppTextStyles.bodySecondary,
          labelLarge: AppTextStyles.button,
          bodySmall: AppTextStyles.caption,
        ).apply(
          bodyColor: AppColors.textPrimaryDark,
          displayColor: AppColors.textPrimaryDark,
        ),
      );

  /// Update global theme color and rebuild app
  static void updateThemeColor(Color newColor) {
    GlobalColors.setThemeColor(newColor);
    // Note: You'll need to call setState() or use a state management solution
    // to rebuild the MaterialApp with the new theme
  }
}
