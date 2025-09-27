import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Card style variants for different use cases
enum CleanCardStyle {
  /// Default elevated card with shadow
  elevated,

  /// Outlined card with border
  outlined,

  /// Filled card with background color
  filled,

  /// Flat card without elevation or border
  flat,

  /// Glass morphism style card
  glass,
}

/// A clean, minimal card widget following Material 3 design principles
/// Supports multiple styles and automatically adapts to global theme colors
class CleanCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final CleanCardStyle style;
  final double? width;
  final double? height;
  final double? elevation;
  final BorderRadius? borderRadius;
  final bool isLoading;

  const CleanCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.style = CleanCardStyle.elevated,
    this.width,
    this.height,
    this.elevation,
    this.borderRadius,
    this.isLoading = false,
  });

  /// Factory constructor for elevated cards (default)
  const CleanCard.elevated({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.width,
    this.height,
    this.elevation,
    this.borderRadius,
    this.isLoading = false,
  }) : style = CleanCardStyle.elevated;

  /// Factory constructor for outlined cards
  const CleanCard.outlined({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.width,
    this.height,
    this.borderRadius,
    this.isLoading = false,
  })  : style = CleanCardStyle.outlined,
        elevation = null;

  /// Factory constructor for filled cards
  const CleanCard.filled({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.width,
    this.height,
    this.borderRadius,
    this.isLoading = false,
  })  : style = CleanCardStyle.filled,
        elevation = null;

  /// Factory constructor for flat cards
  const CleanCard.flat({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.width,
    this.height,
    this.borderRadius,
    this.isLoading = false,
  })  : style = CleanCardStyle.flat,
        elevation = null;

  /// Factory constructor for glass morphism cards
  const CleanCard.glass({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.width,
    this.height,
    this.borderRadius,
    this.isLoading = false,
  })  : style = CleanCardStyle.glass,
        elevation = null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (isLoading) {
      return _buildLoadingCard(isDark);
    }

    final cardDecoration = _buildCardDecoration(isDark);
    final cardBorderRadius =
        borderRadius ?? BorderRadius.circular(AppBorderRadius.card);

    Widget content = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: cardDecoration,
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: cardBorderRadius,
          child: content,
        ),
      );
    }

    return content;
  }

  BoxDecoration _buildCardDecoration(bool isDark) {
    final cardBorderRadius =
        borderRadius ?? BorderRadius.circular(AppBorderRadius.card);

    switch (style) {
      case CleanCardStyle.elevated:
        return BoxDecoration(
          color: backgroundColor ??
              (isDark ? AppColors.cardDark : AppColors.cardLight),
          borderRadius: cardBorderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
              blurRadius: elevation ?? 8,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
            if (elevation != null && elevation! > 4) ...[
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: (elevation! * 2).clamp(4, 16),
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ],
        );

      case CleanCardStyle.outlined:
        return BoxDecoration(
          color: backgroundColor ??
              (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
          borderRadius: cardBorderRadius,
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1.0,
          ),
        );

      case CleanCardStyle.filled:
        return BoxDecoration(
          color: backgroundColor ?? AppColors.primary.withOpacity(0.1),
          borderRadius: cardBorderRadius,
          border: Border.all(
            color: AppColors.primary.withOpacity(0.2),
            width: 1.0,
          ),
        );

      case CleanCardStyle.flat:
        return BoxDecoration(
          color: backgroundColor ??
              (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
          borderRadius: cardBorderRadius,
        );

      case CleanCardStyle.glass:
        return BoxDecoration(
          borderRadius: cardBorderRadius,
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(isDark ? 0.1 : 0.3),
              Colors.white.withOpacity(isDark ? 0.05 : 0.15),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Colors.white.withOpacity(isDark ? 0.2 : 0.4),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        );
    }
  }

  Widget _buildLoadingCard(bool isDark) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1000),
      tween: Tween(begin: 0.3, end: 0.7),
      builder: (context, value, child) {
        return Container(
          width: width,
          height: height ?? 120,
          margin: margin,
          decoration: BoxDecoration(
            color: (isDark ? AppColors.cardDark : AppColors.cardLight)
                .withOpacity(value),
            borderRadius:
                borderRadius ?? BorderRadius.circular(AppBorderRadius.card),
          ),
        );
      },
    );
  }
}

/// A minimal progress indicator that follows the clean design principles
class CleanProgressIndicator extends StatelessWidget {
  final double value;
  final Color? color;
  final double height;
  final bool showPercentage;
  final String? label;

  const CleanProgressIndicator({
    super.key,
    required this.value,
    this.color,
    this.height = 6.0,
    this.showPercentage = false,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progressColor = color ?? AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTextStyles.caption.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            color: isDark ? AppColors.neutral800 : AppColors.neutral200,
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height / 2),
                color: progressColor,
              ),
            ),
          ),
        ),
        if (showPercentage) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${(value * 100).round()}%',
            style: AppTextStyles.caption.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ],
    );
  }
}

/// Clean circular progress indicator for habit cards
class CleanCircularProgress extends StatelessWidget {
  final double value;
  final Color? color;
  final double size;
  final double strokeWidth;
  final Widget? child;
  final bool showAnimation;

  const CleanCircularProgress({
    super.key,
    required this.value,
    this.color,
    this.size = 80.0,
    this.strokeWidth = 4.0,
    this.child,
    this.showAnimation = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progressColor = color ?? AppColors.primary;

    Widget progressWidget = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: strokeWidth,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? AppColors.neutral800 : AppColors.neutral200,
              ),
            ),
          ),
          // Progress circle
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: value.clamp(0.0, 1.0),
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          // Center content
          if (child != null) child!,
        ],
      ),
    );

    if (showAnimation) {
      return TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 800),
        tween: Tween(begin: 0.0, end: value),
        builder: (context, animatedValue, child) {
          return SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background circle
                SizedBox(
                  width: size,
                  height: size,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: strokeWidth,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? AppColors.neutral800 : AppColors.neutral200,
                    ),
                  ),
                ),
                // Animated progress circle
                SizedBox(
                  width: size,
                  height: size,
                  child: CircularProgressIndicator(
                    value: animatedValue.clamp(0.0, 1.0),
                    strokeWidth: strokeWidth,
                    strokeCap: StrokeCap.round,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
                // Center content
                if (this.child != null) this.child!,
              ],
            ),
          );
        },
      );
    }

    return progressWidget;
  }
}

/// Clean button following the design system
class CleanButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isLoading;
  final IconData? icon;
  final bool isOutlined;
  final Size? size;

  const CleanButton({
    super.key,
    required this.text,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.isLoading = false,
    this.icon,
    this.isOutlined = false,
    this.size,
  });

  const CleanButton.outlined({
    super.key,
    required this.text,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.isLoading = false,
    this.icon,
    this.size,
  }) : isOutlined = true;

  @override
  Widget build(BuildContext context) {
    final buttonStyle = isOutlined
        ? OutlinedButton.styleFrom(
            foregroundColor: foregroundColor ?? AppColors.primary,
            side: BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.button),
            ),
            minimumSize: size,
          )
        : ElevatedButton.styleFrom(
            backgroundColor: backgroundColor ?? AppColors.primary,
            foregroundColor: foregroundColor ?? Colors.white,
            elevation: AppElevation.card,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.button),
            ),
            minimumSize: size,
          );

    Widget buttonChild = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                foregroundColor ??
                    (isOutlined ? AppColors.primary : Colors.white),
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(text, style: AppTextStyles.button),
            ],
          );

    return isOutlined
        ? OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: buttonStyle,
            child: buttonChild,
          )
        : ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: buttonStyle,
            child: buttonChild,
          );
  }
}
