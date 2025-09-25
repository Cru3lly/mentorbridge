import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

/// Modern Material 3 NavigationBar implementation
/// Follows global best practices used in Instagram, Notion, Calm, Apple Music
class ModernBottomNav extends StatelessWidget {
  final int selectedIndex;
  final Function(int)? onTap;

  const ModernBottomNav({
    super.key,
    this.selectedIndex = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.height < 700;
    
    // Responsive height: küçük ekranlarda daha kompakt
    final navHeight = isSmallScreen ? 56.0 : 60.0;
    
    return NavigationBar(
      selectedIndex: selectedIndex.clamp(0, 4),
      onDestinationSelected: (index) {
        HapticFeedback.lightImpact();
        if (onTap != null) {
          onTap!(index);
        } else {
          _handleDefaultNavigation(context, index);
        }
      },
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.primary.withOpacity(0.12),
      height: navHeight,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        NavigationDestination(
          icon: Icon(
            Icons.home_outlined,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
          selectedIcon: Icon(
            Icons.home_rounded,
            color: AppColors.primary,
          ),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(
            Icons.bar_chart_outlined,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
          selectedIcon: Icon(
            Icons.bar_chart_rounded,
            color: AppColors.primary,
          ),
          label: 'Statistics',
        ),
        NavigationDestination(
          icon: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppBorderRadius.button),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.add,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          selectedIcon: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppBorderRadius.button),
            ),
            child: const Icon(
              Icons.add,
              color: Colors.white,
              size: 20,
            ),
          ),
          label: 'Add',
        ),
        NavigationDestination(
          icon: Icon(
            Icons.person_outline,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
          selectedIcon: Icon(
            Icons.person_rounded,
            color: AppColors.primary,
          ),
          label: 'Profile',
        ),
        NavigationDestination(
          icon: Icon(
            Icons.settings_outlined,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
          selectedIcon: Icon(
            Icons.settings_rounded,
            color: AppColors.primary,
          ),
          label: 'Settings',
        ),
      ],
    );
  }

  void _handleDefaultNavigation(BuildContext context, int index) {
    switch (index) {
      case 0:
        // Home - do nothing if already there
        break;
      case 1:
        _showComingSoon(context, 'Statistics');
        break;
      case 2:
        _showComingSoon(context, 'Add New Activity');
        break;
      case 3:
        context.go('/profile');
        break;
      case 4:
        context.go('/settings');
        break;
    }
  }

  void _showComingSoon(BuildContext context, String feature) {
    if (!context.mounted) return;
    
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.height < 700;
    final navHeight = isSmallScreen ? 56.0 : 60.0;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Coming Soon!'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.button),
        ),
        margin: EdgeInsets.fromLTRB(
          AppSpacing.screenPadding, 
          0, 
          AppSpacing.screenPadding, 
          AppSpacing.screenPadding + navHeight, // Responsive navigation bar height
        ),
      ),
    );
  }
}
