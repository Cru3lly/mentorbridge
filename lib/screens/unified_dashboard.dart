import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/drag_lock.dart';
import '../widgets/weekend_report_slide_up.dart';
import '../services/notification_service.dart';
import '../services/weekend_report_service.dart';
import 'user/user_spiritual_tracking.dart';
import 'universal/universal_role_dashboard.dart';

class UnifiedDashboard extends StatefulWidget {
  const UnifiedDashboard({super.key});

  @override
  State<UnifiedDashboard> createState() => _UnifiedDashboardState();
}

class _UnifiedDashboardState extends State<UnifiedDashboard>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;
  List<String> _userRoles = ['user']; // Everyone has 'user' role by default
  bool _isLoading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserRoles();
    _requestNotificationPermission();
    _checkWeekendReportPopup();
  }

  Future<void> _checkWeekendReportPopup() async {
    // Wait a bit for the dashboard to load
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    // Check if we should show the weekend report popup
    final shouldShow =
        await WeekendReportService.shouldShowWeekendReportPopup();
    final wasShownToday = await WeekendReportService.wasPopupShownToday();

    if (shouldShow && !wasShownToday && mounted) {
      await WeekendReportSlideUp.show(context);
    }
  }

  /// Request notification permission after login
  Future<void> _requestNotificationPermission() async {
    try {
      // Wait a bit for UI to settle
      await Future.delayed(const Duration(milliseconds: 500));

      // Check if already granted
      final isEnabled = await NotificationService.areNotificationsEnabled();
      if (isEnabled) {
        return;
      }

      // Request permission
      final granted = await NotificationService.requestPermissions();
      if (granted) {
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.notifications_active, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Notifications enabled! You\'ll receive habit reminders.',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        debugPrint('❌ Notification permission denied');

        // Show info message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Enable notifications in Settings to receive habit reminders.',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error requesting notification permission: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh user roles when app resumes
      if (mounted && !_isLoading) {
        _loadUserRoles();
      }
    }
  }

  void _handleError(String error) {
    if (mounted) {
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserRoles() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _handleError('User not authenticated. Please log in again.');
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get()
          .timeout(const Duration(seconds: 10));

      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData == null) {
          _handleError('Invalid user data. Please contact support.');
          return;
        }

        // Everyone has 'user' role by default
        List<String> roles = ['user'];

        // Add additional role if exists
        final additionalRole = userData['role'] as String?;
        if (additionalRole != null &&
            additionalRole != 'user' &&
            additionalRole.isNotEmpty) {
          roles.add(additionalRole);
        }

        // Apply user's preferred order if saved
        final orderedRoles =
            await _applyUserPreferredOrder(roles, currentUser.uid);

        if (mounted) {
          setState(() {
            _userRoles = orderedRoles;
            _isLoading = false;
            _error = null;
          });
        }
      } else {
        // Create user document with default 'user' role
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .set({
          'email': currentUser.email,
          'role': 'user',
          'displayName': currentUser.displayName ??
              currentUser.email?.split('@')[0] ??
              'User',
        }).timeout(const Duration(seconds: 10));

        if (mounted) {
          setState(() {
            _userRoles = ['user'];
            _isLoading = false;
            _error = null;
          });
        }
      }
    } on FirebaseException catch (e) {
      _handleError(_getFirebaseErrorMessage(e));
    } on TimeoutException catch (_) {
      _handleError(
          'Connection timeout. Please check your internet connection.');
    } catch (e) {
      _handleError('An unexpected error occurred. Please try again.');
    }
  }

  String _getFirebaseErrorMessage(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Access denied. Please check your permissions.';
      case 'unavailable':
        return 'Service temporarily unavailable. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return 'Database error: ${e.message ?? 'Unknown error'}';
    }
  }

  Future<List<String>> _applyUserPreferredOrder(
      List<String> roles, String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList('page_order_$userId');

      if (savedOrder == null || savedOrder.isEmpty) {
        return roles; // Return original order if no preference saved
      }

      List<String> orderedRoles = [];

      // Add roles in saved order
      for (String role in savedOrder) {
        if (roles.contains(role)) {
          orderedRoles.add(role);
        }
      }

      // Add any new roles not in saved order at the end
      for (String role in roles) {
        if (!orderedRoles.contains(role)) {
          orderedRoles.add(role);
        }
      }

      return orderedRoles;
    } catch (e) {
      return roles; // Return original order on error
    }
  }

  Widget _buildRolePage(String role, int index) {
    switch (role) {
      case 'user':
        return const UserSpiritualTracking();
      case 'admin':
      case 'moderator':
      case 'director':
      case 'middleSchoolCoordinator':
      case 'highSchoolCoordinator':
      case 'universityCoordinator':
      case 'housingCoordinator':
      case 'middleSchoolAssistantCoordinator':
      case 'highSchoolAssistantCoordinator':
      case 'universityAssistantCoordinator':
      case 'housingAssistantCoordinator':
      case 'middleSchoolMentor':
      case 'highSchoolMentor':
      case 'houseLeader':
      case 'studentHouseLeader':
      case 'houseMember':
      case 'studentHouseMember':
      case 'accountant':
        return UniversalRoleDashboard(
          currentRole: role,
          allUserRoles: _userRoles,
        );
      default:
        return const UserSpiritualTracking();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF8EC5FC), Color(0xFFE0C3FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 20),
                Text(
                  'Loading user data...',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                Text(
                  'Roles: ${_userRoles.join(", ")}',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // If error occurred, show error state
    if (_error != null) {
      return _buildErrorState();
    }

    // If no roles loaded, show error
    if (_userRoles.isEmpty) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF8EC5FC), Color(0xFFE0C3FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 64),
                const SizedBox(height: 20),
                Text(
                  'No roles found!',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  'Please contact administrator',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () => _loadUserRoles(),
                  child: Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: null,
      );
    }

    return DragLock(
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFF5F7FA), // Slightly cooler light grey
                    Color(0xFFEBF0F5), // Cool light grey
                    Color(0xFFF8FAFC), // Very light blue-grey
                    Color(0xFFF1F5F9), // Subtle blue tint
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.4, 0.7, 1.0],
                ),
              ),
              child: Stack(
                children: [
                  // Page content with safe area for top
                  Padding(
                    padding: const EdgeInsets.only(
                        top: 20), // Consistent minimal padding
                    child: DragLock.listen(
                      context: context,
                      builder: (context, locked) {
                        return PageView.builder(
                          controller: _pageController,
                          physics: locked
                              ? const NeverScrollableScrollPhysics()
                              : const PageScrollPhysics(),
                          onPageChanged: (index) {
                            if (_currentPageIndex != index) {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _currentPageIndex = index;
                              });
                            }
                          },
                          itemCount: _userRoles.length,
                          itemBuilder: (context, index) {
                            return _buildRolePage(_userRoles[index], index);
                          },
                        );
                      },
                    ),
                  ),

                  // Role title removed - now handled by individual dashboard wrappers

                  // Page indicators (dots) positioned above navigation bar
                  // Sadece çoklu role sahip kullanıcılara göster (user + başka rol)
                  if (_userRoles.length > 1)
                    Positioned(
                      bottom:
                          95, // Navigation bar'ın hemen üzerine (+ butonunun üstü)
                      left: 0,
                      right: 0,
                      child: Semantics(
                        label:
                            'Page ${_currentPageIndex + 1} of ${_userRoles.length}',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_userRoles.length, (index) {
                            final isActive = _currentPageIndex == index;
                            return Semantics(
                              label:
                                  '${_userRoles[index]} dashboard, ${isActive ? 'current page' : 'page ${index + 1}'}',
                              button: true,
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  _pageController.animateToPage(
                                    index,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 5),
                                  width: isActive ? 14 : 10,
                                  height: isActive ? 14 : 10,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isActive
                                          ? Colors.white.withOpacity(0.8)
                                          : Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Bottom navigation for all pages
            // Navigation bar now handled by AppShell
          );
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8EC5FC), Color(0xFFE0C3FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 80,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Something went wrong',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error ?? 'An unexpected error occurred',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _loadUserRoles();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
