import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HighSchoolUnitCoordinatorDashboard extends StatefulWidget {
  const HighSchoolUnitCoordinatorDashboard({super.key});

  @override
  State<HighSchoolUnitCoordinatorDashboard> createState() =>
      _HighSchoolUnitCoordinatorDashboardState();
}

class _HighSchoolUnitCoordinatorDashboardState
    extends State<HighSchoolUnitCoordinatorDashboard> {

  bool _isMigrated = false;
  bool _checkingMigration = true;

  @override
  void initState() {
    super.initState();
    _checkMigrationStatus();
  }

  Future<void> _checkMigrationStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _checkingMigration = false);
      return;
    }
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (userDoc.exists && userDoc.data()!.containsKey('managesEntity')) {
      setState(() {
        _isMigrated = true;
        _checkingMigration = false;
      });
    } else {
      setState(() => _checkingMigration = false);
    }
  }

  Future<void> _migrateAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to migrate.'))
      );
      return;
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final userDoc = await userRef.get();

    if (!userDoc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User document not found.'))
      );
      return;
    }
    
    final userData = userDoc.data()!;
    if (userData.containsKey('managesEntity')) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your account is already migrated.'))
      );
      setState(() {
        _isMigrated = true;
        _checkingMigration = false;
      });
      return;
    }

    // Extract info from user document
    final String country = userData['country'] ?? 'Unknown Country';
    final String region = userData['city'] ?? 'Unknown Region'; // Using city as region based on discussion
    final String gender = userData['gender'] ?? 'Mixed';
    final String unitName = "$region - High School ($gender)";

    try {
      // 1. Create the new organizational unit
      final newUnitRef = await FirebaseFirestore.instance.collection('organizationalUnits').add({
        'name': unitName,
        'type': 'unit',
        'level': 'highSchool',
        'country': country,
        'region': region,
        'gender': gender,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Update the user document
      await userRef.update({
        'managesEntity': newUnitRef.path,
        'parentId': FieldValue.delete(), // Remove obsolete field
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account successfully migrated to the new system!'), backgroundColor: Colors.green,)
      );

      setState(() {
        _isMigrated = true;
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred during migration: $e'), backgroundColor: Colors.red,)
      );
    }
  }

  static final List<Map<String, dynamic>> items = [
    {
      'label': 'Assign Role',
      'icon': Icons.person_add,
      'route': '/highSchoolUnitCoordinatorIdAuthPage',
      'color': Colors.deepPurple,
    },
    {
      'label': 'Reports',
      'icon': Icons.bar_chart,
      'route': '/highSchoolUnitCoordinatorStats',
      'color': Colors.teal,
    },
    {
      'label': 'Relationship Map',
      'icon': Icons.account_tree,
      'route': '/highSchoolUnitCoordinatorUserTree',
      'color': Colors.orange,
    },
    {
      'label': 'Mentors\nMentees',
      'icon': Icons.group,
      'route': '/highSchoolUnitCoordinatorEditMentorMentee',
      'color': Colors.indigo,
    },
    {
      'label': 'Academic Calendar',
      'icon': Icons.calendar_month,
      'route': '/highSchoolUnitCoordinatorAcademicCalendar',
      'color': Colors.pink,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          centerTitle: true,
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'High School\nUnit Coordinator',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: Colors.white,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.settings,
                size: 30,
                color: Colors.white,
              ),
              tooltip: 'Settings',
              onPressed: () => context.push('/settings'),
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF8EC5FC), Color(0xFFE0C3FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: GlassmorphicContainer(
                width: double.infinity,
                height: 600, // Adjusted height for new button
                borderRadius: 28,
                blur: 18,
                alignment: Alignment.center,
                border: 2,
                linearGradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.25),
                    Colors.white.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderGradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.60),
                    Colors.white.withOpacity(0.10),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    runAlignment: WrapAlignment.center,
                    spacing: 20,
                    runSpacing: 20,
                    children: [
                      if (!_checkingMigration && !_isMigrated)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.sync_alt),
                            label: const Text('Migrate Account to New System'),
                            onPressed: _migrateAccount,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ...items.map((item) {
                      return SizedBox(
                        width: MediaQuery.of(context).size.width * 0.35,
                        height: MediaQuery.of(context).size.width * 0.35,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => context.push(item['route'] as String),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: (item['color'] as Color).withOpacity(0.13),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: (item['color'] as Color)
                                      .withOpacity(0.18),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(item['icon'] as IconData,
                                    size: 38, color: item['color'] as Color),
                                const SizedBox(height: 12),
                                Text(
                                  item['label'] as String,
                                  style: GoogleFonts.inter(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: item['color'] as Color,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ));
  }
} 