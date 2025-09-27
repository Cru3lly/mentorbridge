import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/theme_color_picker.dart';
import '../../widgets/clean_card.dart';
import '../../theme/app_theme.dart';

class ThemeColorSettings extends StatefulWidget {
  const ThemeColorSettings({super.key});

  @override
  State<ThemeColorSettings> createState() => _ThemeColorSettingsState();
}

class _ThemeColorSettingsState extends State<ThemeColorSettings> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          'Theme Color',
          style: AppTextStyles.headline.copyWith(
            color:
                isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color:
                isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main color picker card
              CleanCard.elevated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ThemeColorPicker(
                  onColorChanged: (color) {
                    // Force rebuild to show new colors
                    setState(() {});

                    // Give haptic feedback
                    HapticFeedback.mediumImpact();
                  },
                ),
              ),

              const SizedBox(height: AppSpacing.sectionSpacing),

              // Preview section
              Text(
                'Preview',
                style: AppTextStyles.subheadline.copyWith(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Preview cards showing how the new color looks
              Column(
                children: [
                  // Elevated card preview
                  CleanCard.elevated(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.palette,
                              color: AppColors.primary,
                              size: 24,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Text(
                              'Elevated Card Style',
                              style: AppTextStyles.subheadline.copyWith(
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'This is how your new theme color will look in elevated cards.',
                          style: AppTextStyles.bodySecondary.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        CleanButton(
                          text: 'Sample Button',
                          icon: Icons.star,
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Outlined card preview
                  CleanCard.outlined(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.border_style,
                              color: AppColors.primary,
                              size: 24,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Text(
                              'Outlined Card Style',
                              style: AppTextStyles.subheadline.copyWith(
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Outlined cards use the theme color for borders and accents.',
                          style: AppTextStyles.bodySecondary.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        CleanButton.outlined(
                          text: 'Outlined Button',
                          icon: Icons.favorite_border,
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Filled card preview
                  CleanCard.filled(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.format_color_fill,
                              color: AppColors.primary,
                              size: 24,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Text(
                              'Filled Card Style',
                              style: AppTextStyles.subheadline.copyWith(
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Filled cards have a subtle background tint of your theme color.',
                          style: AppTextStyles.bodySecondary.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.sectionSpacing),

              // Info section
              CleanCard.flat(
                backgroundColor: AppColors.info.withOpacity(0.1),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.info,
                      size: 24,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Theme Color Info',
                            style: AppTextStyles.bodySecondary.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Your theme color choice will be applied throughout the app, including buttons, icons, progress indicators, and accent elements.',
                            style: AppTextStyles.caption.copyWith(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
