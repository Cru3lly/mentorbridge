import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'custom_bottom_navigation.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  
  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: widget.child,
      bottomNavigationBar: CustomBottomNavigation(
        selectedIndex: 0,
        onTap: (index) => _onNavTap(context, index),
      ),
      resizeToAvoidBottomInset: false,
    );
  }



  void _onNavTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/unifiedDashboard');
        break;
      case 1:
        // For now show snackbar, later add route
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Statistics - Coming Soon!'),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 100), // Above navigation bar
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;
      case 2:
        // Navigate to add habit page
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
}
