import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:ui';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  String _appVersion = '';
  String _appName = '';

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = info.version;
      _appName = info.appName;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List<_SettingsSection> topSections = [
      _SettingsSection(icon: Icons.person_outline, label: 'Profile', route: '/profile', color: theme.colorScheme.primary),
      _SettingsSection(icon: Icons.notifications_none, label: 'Notifications', route: '/settings/notifications', color: Colors.pink),
      _SettingsSection(icon: Icons.security_outlined, label: 'Privacy', route: '/settings/privacy', color: Colors.green),
    ];
    final List<_SettingsSection> bottomSections = [
      _SettingsSection(icon: Icons.settings, label: 'App Settings', route: '/settings/app', color: Colors.blueGrey),
      _SettingsSection(icon: Icons.info_outline, label: 'About', route: '/settings/about', color: Colors.amber),
      _SettingsSection(icon: Icons.help_outline, label: 'Help Center', route: '/help', color: Colors.orange),
    ];
    final allSections = [...topSections, ...bottomSections];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                        colors: [Colors.white.withOpacity(0.4), Colors.white.withOpacity(0.2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(width: 1.5, color: Colors.white.withOpacity(0.2)),
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
                                      applicationLegalese: 'Developed by MentorBridge Team\nAll rights reserved.',
                                    );
                                  } else {
                                    context.push(section.route);
                                  }
                                },
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: section.color.withOpacity(0.13),
                                    child: Icon(section.icon, color: section.color, size: 26),
                                  ),
                                  title: Text(
                                    section.label,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                                  ),
                                  trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 22),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                ),
                              ),
                            ),
                            if (!isLast)
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: isEndOfTopSection ? 0 : 16.0),
                                child: Divider(
                                  height: 1,
                                  thickness: isEndOfTopSection ? 2 : 1,
                                  color: Colors.white.withOpacity(isEndOfTopSection ? 0.4 : 0.2),
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
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  child: const Text('Log Out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper model
class _SettingsSection {
  final IconData icon;
  final String label;
  final String route;
  final Color color;
  const _SettingsSection({required this.icon, required this.label, required this.route, required this.color});
}
