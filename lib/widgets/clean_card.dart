import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A clean, minimal card widget following Material 3 design principles
class CleanCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final bool hasBorder;
  final double? width;
  final double? height;
  
  const CleanCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.hasBorder = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final cardColor = backgroundColor ?? 
        (isDark ? AppColors.cardDark : AppColors.cardLight);
    
    Widget content = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.card),
        border: hasBorder 
            ? Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                width: 1.0,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
    
    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppBorderRadius.card),
          child: content,
        ),
      );
    }
    
    return content;
  }
}

/// A minimal progress indicator that follows the clean design principles
class CleanProgressIndicator extends StatelessWidget {
  final double value;
  final Color? color;
  final double height;
  final bool showPercentage;
  
  const CleanProgressIndicator({
    super.key,
    required this.value,
    this.color,
    this.height = 6.0,
    this.showPercentage = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progressColor = color ?? AppColors.primary;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            color: isDark 
                ? AppColors.neutral800 
                : AppColors.neutral200,
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
  
  const CleanCircularProgress({
    super.key,
    required this.value,
    this.color,
    this.size = 80.0,
    this.strokeWidth = 4.0,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progressColor = color ?? AppColors.primary;
    
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
                isDark 
                    ? AppColors.neutral800 
                    : AppColors.neutral200,
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
  }
}
