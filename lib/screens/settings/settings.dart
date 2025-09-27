import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import '../../theme/app_theme.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  String _appVersion = '';
  String _appName = '';
  bool _hasMultipleRoles = false;
  bool _isLoadingRoles = true;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
    _checkUserRoles();
  }

  Future<void> _loadAppInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = info.version;
      _appName = info.appName;
    });
  }

  Future<void> _checkUserRoles() async {
    final roles = await _getUserRoles();
    setState(() {
      _hasMultipleRoles = roles.length > 1;
      _isLoadingRoles = false;
    });
  }

  Future<List<String>> _getUserRoles() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return ['user'];

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;

        // Everyone has 'user' role by default
        List<String> roles = ['user'];

        // Add additional role if exists
        final additionalRole = userData['role'] as String?;
        if (additionalRole != null &&
            additionalRole != 'user' &&
            additionalRole.isNotEmpty) {
          roles.add(additionalRole);
        }

        return roles;
      }

      return ['user'];
    } catch (e) {
      debugPrint('Error loading user roles: $e');
      return ['user'];
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'user':
        return 'Spiritual Tracking';
      case 'admin':
        return 'Admin';
      case 'director':
        return 'Director';
      case 'highSchoolCoordinator':
        return 'HS Coordinator';
      case 'middleSchoolCoordinator':
        return 'MS Coordinator';
      case 'universityCoordinator':
        return 'University Coordinator';
      case 'housingCoordinator':
        return 'Housing Coordinator';
      case 'highSchoolAssistantCoordinator':
        return 'HS Assistant';
      case 'middleSchoolAssistantCoordinator':
        return 'MS Assistant';
      case 'universityAssistantCoordinator':
        return 'University Assistant';
      case 'housingAssistantCoordinator':
        return 'Housing Assistant';
      case 'highSchoolMentor':
        return 'HS Mentor';
      case 'middleSchoolMentor':
        return 'MS Mentor';
      case 'moderator':
        return 'Moderator';
      case 'accountant':
        return 'Accountant';
      case 'houseLeader':
        return 'House Leader';
      case 'student':
        return 'Student';
      default:
        return 'Dashboard';
    }
  }

  Future<void> _showPageOrderDialog(BuildContext context) async {
    final roles = await _getUserRoles();

    if (roles.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You only have one page, no need to reorder.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(
            bottom: 100, // Navigation bar'ın üstünde kalması için
            left: 16,
            right: 16,
          ),
        ),
      );
      return;
    }

    // Load current order from preferences
    final prefs = await SharedPreferences.getInstance();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final savedOrder = prefs.getStringList('page_order_${currentUser.uid}');
    List<String> orderedRoles = List.from(roles);

    // Apply saved order if exists
    if (savedOrder != null && savedOrder.isNotEmpty) {
      List<String> reorderedRoles = [];
      // Add roles in saved order
      for (String role in savedOrder) {
        if (roles.contains(role)) {
          reorderedRoles.add(role);
        }
      }
      // Add any new roles not in saved order
      for (String role in roles) {
        if (!reorderedRoles.contains(role)) {
          reorderedRoles.add(role);
        }
      }
      orderedRoles = reorderedRoles;
    }

    showDialog(
      context: context,
      builder: (context) => _PageOrderDialog(
        roles: orderedRoles,
        getRoleDisplayName: _getRoleDisplayName,
        onSave: (newOrder) async {
          await prefs.setStringList('page_order_${currentUser.uid}', newOrder);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Page order saved!'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.only(
                  bottom: 100, // Navigation bar'ın üstünde kalması için
                  left: 16,
                  right: 16,
                ),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Dinamik olarak top sections oluştur
    final List<_SettingsSection> topSections = [
      _SettingsSection(
          icon: Icons.person_outline,
          label: 'Profile',
          route: '/profile',
          color: theme.colorScheme.primary),
      // Page Order butonunu sadece birden fazla rolü olanlara göster
      if (_hasMultipleRoles && !_isLoadingRoles)
        _SettingsSection(
            icon: Icons.reorder,
            label: 'Page Order',
            route: '/settings/page-order',
            color: Colors.purple,
            isSpecial: true),
      _SettingsSection(
          icon: Icons.palette_outlined,
          label: 'Theme Color',
          route: '/settings/theme-color',
          color: AppColors.primary,
          isSpecial: true),
      _SettingsSection(
          icon: Icons.notifications_none,
          label: 'Notifications',
          route: '/settings/notifications',
          color: Colors.pink),
      _SettingsSection(
          icon: Icons.security_outlined,
          label: 'Privacy',
          route: '/settings/privacy',
          color: Colors.green),
    ];
    final List<_SettingsSection> bottomSections = [
      _SettingsSection(
          icon: Icons.settings,
          label: 'App Settings',
          route: '/settings/app',
          color: Colors.blueGrey),
      _SettingsSection(
          icon: Icons.info_outline,
          label: 'About',
          route: '/settings/about',
          color: Colors.amber),
      _SettingsSection(
          icon: Icons.help_outline,
          label: 'Help Center',
          route: '/help',
          color: Colors.orange),
    ];
    final allSections = [...topSections, ...bottomSections];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (Navigator.canPop(context)) {
              context.pop();
            } else {
              context.go('/unifiedDashboard');
            }
          },
        ),
        title: const Text('Settings',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.black.withOpacity(0.2),
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(color: Colors.black),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF3F2F8), Color(0xFFE5DFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(18.0),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.4),
                          Colors.white.withOpacity(0.2)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          width: 1.5, color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(allSections.length, (i) {
                        final section = allSections[i];
                        final isLast = i == allSections.length - 1;
                        final isEndOfTopSection = i == topSections.length - 1;

                        return Column(
                          children: [
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  if (section.label == 'About') {
                                    showAboutDialog(
                                      context: context,
                                      applicationName: _appName,
                                      applicationVersion: _appVersion,
                                      applicationLegalese:
                                          'Developed by MentorBridge Team\nAll rights reserved.',
                                    );
                                  } else if (section.label == 'Page Order') {
                                    _showPageOrderDialog(context);
                                  } else {
                                    context.push(section.route);
                                  }
                                },
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        section.color.withOpacity(0.13),
                                    child: Icon(section.icon,
                                        color: section.color, size: 26),
                                  ),
                                  title: Text(
                                    section.label,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87),
                                  ),
                                  trailing: const Icon(Icons.chevron_right,
                                      color: Colors.grey, size: 22),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 6),
                                ),
                              ),
                            ),
                            if (!isLast)
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: isEndOfTopSection ? 0 : 16.0),
                                child: Divider(
                                  height: 1,
                                  thickness: isEndOfTopSection ? 2 : 1,
                                  color: Colors.white.withOpacity(
                                      isEndOfTopSection ? 0.4 : 0.2),
                                ),
                              ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    context.go('/login');
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  child: const Text('Log Out'),
                ),
              ),
            ],
          ),
        ),
      ),
      // Navigation bar now handled by AppShell
    );
  }
}

// Helper model
class _SettingsSection {
  final IconData icon;
  final String label;
  final String route;
  final Color color;
  final bool isSpecial;
  const _SettingsSection(
      {required this.icon,
      required this.label,
      required this.route,
      required this.color,
      this.isSpecial = false});
}

// Page Order Dialog Widget
class _PageOrderDialog extends StatefulWidget {
  final List<String> roles;
  final String Function(String) getRoleDisplayName;
  final Function(List<String>) onSave;

  const _PageOrderDialog({
    required this.roles,
    required this.getRoleDisplayName,
    required this.onSave,
  });

  @override
  State<_PageOrderDialog> createState() => _PageOrderDialogState();
}

class _PageOrderDialogState extends State<_PageOrderDialog> {
  late List<String> _orderedRoles;

  @override
  void initState() {
    super.initState();
    _orderedRoles = List.from(widget.roles);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.8)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(width: 1.5, color: Colors.white.withOpacity(0.3)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.reorder, color: Colors.purple, size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'Page Order',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.grey),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Drag to reorder your pages. Changes will apply on next app restart.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),

                // Reorderable List
                Container(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    itemCount: _orderedRoles.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) {
                          newIndex -= 1;
                        }
                        final String role = _orderedRoles.removeAt(oldIndex);
                        _orderedRoles.insert(newIndex, role);
                      });
                    },
                    itemBuilder: (context, index) {
                      final role = _orderedRoles[index];
                      return Container(
                        key: ValueKey(role),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.grey.withOpacity(0.3)),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.purple.withOpacity(0.1),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.purple,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            widget.getRoleDisplayName(role),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            'Page ${index + 1}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.drag_handle,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        widget.onSave(_orderedRoles);
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Save Order'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
