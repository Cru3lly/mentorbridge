import 'package:flutter/material.dart';

class AppColors {
  // Primary colors - simplified palette
  static const Color primary = Color(0xFF007AFF); // iOS blue
  static const Color primaryVariant = Color(0xFF0051D5);
  
  // Neutral colors for minimal design
  static const Color neutral900 = Color(0xFF1C1C1E);
  static const Color neutral800 = Color(0xFF2C2C2E);
  static const Color neutral600 = Color(0xFF636366);
  static const Color neutral400 = Color(0xFF8E8E93);
  static const Color neutral200 = Color(0xFFE5E5EA);
  static const Color neutral100 = Color(0xFFF2F2F7);
  static const Color neutral50 = Color(0xFFFAFAFA);
  
  // Clean background colors - no gradients
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color backgroundDark = Color(0xFF000000);
  
  // Surface colors - clean and simple
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1C1C1E);
  
  // Text colors - high contrast for readability
  static const Color textPrimaryLight = Color(0xFF1C1C1E);
  static const Color textSecondaryLight = Color(0xFF636366);
  static const Color textTertiaryLight = Color(0xFF8E8E93);
  
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFF8E8E93);
  static const Color textTertiaryDark = Color(0xFF636366);
  
  // Card colors - minimal and clean
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF2C2C2E);
  static const Color borderLight = Color(0xFFE5E5EA);
  static const Color borderDark = Color(0xFF38383A);
  
  // Status colors - iOS style
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9500);
  static const Color error = Color(0xFFFF3B30);
  
  // Simplified habit colors - fewer, more consistent
  static const List<Color> habitColors = [
    Color(0xFF34C759), // Green
    Color(0xFF007AFF), // Blue
    Color(0xFFAF52DE), // Purple
    Color(0xFFFF9500), // Orange
    Color(0xFFFF2D92), // Pink
    Color(0xFF5AC8FA), // Light Blue
  ];
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
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'NotoSans',
    colorScheme: const ColorScheme.light(
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

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'NotoSans',
    colorScheme: const ColorScheme.dark(
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
}
