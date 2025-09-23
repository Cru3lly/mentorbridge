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
      case 'middleSchoolMentor':
        return 'Middle School Mentor';
      case 'highSchoolMentor':
        return 'High School Mentor';
      case 'student':
        return 'Student';
      // Assistant Coordinators (eski Unit Coordinators)
      case 'middleSchoolAssistantCoordinator':
        return 'Middle School Assistant Coordinator';
      case 'highSchoolAssistantCoordinator':
        return 'High School Assistant Coordinator';
      case 'universityAssistantCoordinator':
        return 'University Assistant Coordinator';
      case 'housingAssistantCoordinator':
        return 'Housing Assistant Coordinator';
      // Coordinators (eski Region Coordinators)
      case 'middleSchoolCoordinator':
        return 'Middle School Coordinator';
      case 'highSchoolCoordinator':
        return 'High School Coordinator';
      case 'universityCoordinator':
        return 'University Coordinator';
      case 'housingCoordinator':
        return 'Housing Coordinator';
      // Leadership roles
      case 'director':
        return 'Director';
      case 'admin':
        return 'Admin';
      case 'moderator':
        return 'Moderator';
      case 'accountant':
        return 'Accountant';
      case 'houseLeader':
        return 'House Leader';
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

    // Everyone now goes to the unified dashboard
    // The unified dashboard will handle role-based page switching internally
    context.go('/authGate');
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
