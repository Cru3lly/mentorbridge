import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:go_router/go_router.dart';

class CustomBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final Function(int)? onTap;
  final bool showPageIndicators;
  final int totalPages;
  final int currentPage;

  const CustomBottomNavigation({
    super.key,
    this.selectedIndex = 0,
    this.onTap,
    this.showPageIndicators = false,
    this.totalPages = 1,
    this.currentPage = 0,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;
    
    return GlassmorphicContainer(
      width: double.infinity,
      height: isLargeScreen ? 90 : 80, // Responsive height
      borderRadius: isLargeScreen ? 24 : 20, // Responsive border radius
      blur: 25,
      border: 2,
              linearGradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.2),
                  Colors.white.withOpacity(0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderGradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.3),
                  Colors.white.withOpacity(0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                  _buildNavItem(
                    icon: Icons.home_rounded,
                    index: 0,
                    label: 'Home',
                    isLargeScreen: isLargeScreen,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (onTap != null) {
                        onTap!(0);
                      } else {
                        // Do nothing - already on home
                      }
                    },
                  ),
                  _buildNavItem(
                    icon: Icons.bar_chart_rounded,
                    index: 1,
                    label: 'Statistics',
                    isLargeScreen: isLargeScreen,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (onTap != null) {
                        onTap!(1);
                      } else {
                        // Navigate to stats page
                        _showComingSoon(context, 'Statistics');
                      }
                    },
                  ),
                  _buildNavItem(
                    icon: Icons.add,
                    index: 2,
                    label: 'Add',
                    isCenter: true,
                    isLargeScreen: isLargeScreen,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      if (onTap != null) {
                        onTap!(2);
                      } else {
                        // Navigate to add page or show modal
                        _showComingSoon(context, 'Add New Activity');
                      }
                    },
                  ),
                  _buildNavItem(
                    icon: Icons.person_rounded,
                    index: 3,
                    label: 'Profile',
                    isLargeScreen: isLargeScreen,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (onTap != null) {
                        onTap!(3);
                      } else {
                        // Navigate to profile page
                        context.go('/profile');
                      }
                    },
                  ),
                  _buildNavItem(
                    icon: Icons.settings_rounded,
                    index: 4,
                    label: 'Settings',
                    isLargeScreen: isLargeScreen,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (onTap != null) {
                        onTap!(4);
                      } else {
                        // Navigate to settings page
                        context.go('/settings');
                      }
                    },
                  ),
                  ],
                ),
              ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required int index,
    required String label,
    required bool isLargeScreen,
    required VoidCallback onTap,
    bool isCenter = false,
  }) {
    final isSelected = selectedIndex == index;
    final iconSize = isLargeScreen ? 36.0 : 32.0;
    final padding = isLargeScreen ? 16.0 : 12.0;
    
    return Semantics(
      label: '$label navigation button',
      button: true,
      selected: isSelected,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(padding + iconSize / 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(padding + iconSize / 2),
          splashColor: Colors.white.withOpacity(0.2),
          highlightColor: Colors.white.withOpacity(0.1),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(padding),
            constraints: BoxConstraints(
              minWidth: 44, // Apple/Google minimum touch target
              minHeight: 44,
            ),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCenter 
                  ? Colors.orange.withOpacity(0.8)
                  : (isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent),
              boxShadow: isCenter ? [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: isCenter 
                  ? Colors.white
                  : (isSelected ? Colors.white : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    try {
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$feature - Coming Soon!'),
          backgroundColor: Colors.blue.withOpacity(0.8),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 100), // Above navigation
        ),
      );
    } catch (e) {
      // Fallback for navigation errors
      debugPrint('Navigation error: $e');
    }
  }
}
