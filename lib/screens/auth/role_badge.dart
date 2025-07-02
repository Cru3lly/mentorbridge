import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';


class RoleBadge extends StatelessWidget {
  final String role;
  final String subRole;
  const RoleBadge({super.key, required this.role, this.subRole = ''});

  String _getRoleTitle() {
    switch (role) {
      case 'mentor':
        return 'Mentor';
      case 'student':
        return 'Student';
      case 'unitCoordinator':
        switch (subRole) {
          case 'middle_school':
            return 'Middle School Unit Coordinator';
          case 'high_school':
            return 'High School Unit Coordinator';
          case 'university':
            return 'University Unit Coordinator';
          default:
            return 'Unit Coordinator';
        }
      case 'regionCoordinator':
        switch (subRole) {
          case 'middle_school':
            return 'Middle School Regional Coordinator';
          case 'high_school':
            return 'High School Regional Coordinator';
          case 'university':
            return 'University Regional Coordinator';
          default:
            return 'Regional Coordinator';
        }
      case 'countryCoordinator':
        return 'Country Coordinator';
      case 'admin':
        return 'Admin';
      default:
        return 'User';
    }
  }

  Future<void> _markBadgeSeen() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'badgeShown': true,
        });
      } catch (e) {
        debugPrint('Error marking badge as seen: $e');
      }
    }
  }

  void _continue(BuildContext context) async {
    await _markBadgeSeen();

    if (role == 'admin') {
      context.go('/adminDashboard');
    } else if (role == 'countryCoordinator') {
      context.go('/countryCoordinatorDashboard');
    } else if (role == 'regionCoordinator') {
      switch (subRole) {
        case 'middle_school':
          context.go('/middleSchoolRegionCoordinatorDashboard');
          break;
        case 'high_school':
          context.go('/highSchoolRegionCoordinatorDashboard');
          break;
        case 'university':
          context.go('/universityRegionCoordinatorDashboard');
          break;
        default:
          context.go('/homeDashboard');
          break;
      }
    } else if (role == 'unitCoordinator') {
      switch (subRole) {
        case 'middle_school':
          context.go('/middleSchoolUnitCoordinatorDashboard');
          break;
        case 'high_school':
          context.go('/highSchoolUnitCoordinatorDashboard');
          break;
        case 'university':
          context.go('/universityUnitCoordinatorDashboard');
          break;
        default:
          context.go('/homeDashboard');
          break;
      }
    } else if (role == 'mentor') {
      context.go('/mentorDashboard');
    } else if (role == 'student') {
      context.go('/studentScreen');
    } else {
      context.go('/homeDashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _getRoleTitle();

    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.emoji_events,
                size: 100,
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 32),
              Text(
                'Congratulations!\nYou are now a\n$title!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _continue(context),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
