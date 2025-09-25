import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import 'modern_bottom_nav.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  
  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateCurrentIndex();
  }
  
  void _updateCurrentIndex() {
    final location = GoRouterState.of(context).uri.toString();
    setState(() {
      if (location.contains('/unifiedDashboard')) {
        _currentIndex = 0;
      } else if (location.contains('/addHabit')) {
        _currentIndex = 2;
      } else if (location.contains('/profile')) {
        _currentIndex = 3;
      } else if (location.contains('/settings')) {
        _currentIndex = 4;
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: widget.child,
      bottomNavigationBar: ModernBottomNav(
        selectedIndex: _currentIndex,
        onTap: (index) => _onNavTap(context, index),
      ),
    );
  }



  void _onNavTap(BuildContext context, int index) {
    setState(() {
      _currentIndex = index;
    });
    
    switch (index) {
      case 0:
        context.go('/unifiedDashboard');
        break;
      case 1:
        _showComingSoon(context, 'Statistics');
        break;
      case 2:
        context.go('/addHabit');
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
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Coming Soon!'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.button),
        ),
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding, 
          0, 
          AppSpacing.screenPadding, 
          AppSpacing.screenPadding + 60, // Bottom navigation için yer bırak
        ),
      ),
    );
  }
}
