import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// A widget that allows users to pick a global theme color
class ThemeColorPicker extends StatefulWidget {
  final Function(Color)? onColorChanged;

  const ThemeColorPicker({
    super.key,
    this.onColorChanged,
  });

  @override
  State<ThemeColorPicker> createState() => _ThemeColorPickerState();
}

class _ThemeColorPickerState extends State<ThemeColorPicker> {
  static const List<Color> _predefinedColors = [
    Color(0xFF007AFF), // iOS Blue (default)
    Color(0xFF34C759), // iOS Green
    Color(0xFFAF52DE), // iOS Purple
    Color(0xFFFF9500), // iOS Orange
    Color(0xFFFF2D92), // iOS Pink
    Color(0xFF5AC8FA), // iOS Light Blue
    Color(0xFFFFCC02), // iOS Yellow
    Color(0xFFFF3B30), // iOS Red
    Color(0xFF8E8E93), // iOS Gray
    Color(0xFF00C7BE), // Teal
    Color(0xFF6C5CE7), // Purple Variant
    Color(0xFF2D3436), // Dark Gray
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentColor = GlobalColors.themeColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Text(
          'Theme Color',
          style: AppTextStyles.subheadline.copyWith(
            color:
                isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Description
        Text(
          'Choose a color that will be used throughout the app',
          style: AppTextStyles.bodySecondary.copyWith(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Color grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.0,
          ),
          itemCount: _predefinedColors.length,
          itemBuilder: (context, index) {
            final color = _predefinedColors[index];
            final isSelected = color.value == currentColor.value;

            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _updateThemeColor(color);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppBorderRadius.md),
                  border: isSelected
                      ? Border.all(
                          color: isDark ? Colors.white : Colors.black,
                          width: 3,
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: isSelected ? 8 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        color: _getContrastColor(color),
                        size: 24,
                      )
                    : null,
              ),
            );
          },
        ),

        const SizedBox(height: AppSpacing.lg),

        // Current color preview
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(AppBorderRadius.card),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Row(
            children: [
              // Color preview
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: currentColor,
                  borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                  boxShadow: [
                    BoxShadow(
                      color: currentColor.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Color info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Theme Color',
                      style: AppTextStyles.bodySecondary.copyWith(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '#${currentColor.value.toRadixString(16).substring(2).toUpperCase()}',
                      style: AppTextStyles.caption.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _updateThemeColor(Color color) {
    setState(() {
      GlobalColors.setThemeColor(color);
    });

    // Notify parent widget
    widget.onColorChanged?.call(color);

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Theme color updated!'),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.button),
        ),
      ),
    );
  }

  Color _getContrastColor(Color color) {
    // Calculate luminance to determine if we should use white or black text
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
