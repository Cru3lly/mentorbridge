import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Onboarding
import '../onboarding/onboarding.dart';
// Home
import '../home/home_dashboard.dart';
// Mentor
import '../mentor/mentor_dashboard.dart';
// Student
import '../student/student_dashboard.dart';
// Admin
import '../admin/admin_dashboard.dart';
// Country Coordinator
import '../country_coordinator/country_coordinator_dashboard.dart';
// Region Coordinator
import '../region_coordinator/middle_school/middle_school_region_coordinator_dashboard.dart';
import '../region_coordinator/high_school/high_school_region_coordinator_dashboard.dart';
import '../region_coordinator/university/university_region_coordinator_dashboard.dart';
// Unit Coordinator
import '../unit_coordinator/middle_school/middle_school_unit_coordinator_dashboard.dart';
import '../unit_coordinator/high_school/high_school_unit_coordinator_dashboard.dart';
import '../unit_coordinator/university/university_unit_coordinator_dashboard.dart';

// Auth
import 'auth_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const AuthScreen();
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(snapshot.data!.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              // Kullanıcı verisi yoksa veya bir hata oluştuysa, güvenli bir ekrana yönlendir.
              return const AuthScreen();
            }
            final userData = snapshot.data!.data() as Map<String, dynamic>;
            final role = userData['role'] as String?;
            final completedOnboarding =
                userData['completedOnboarding'] as bool? ?? false;

            if (!completedOnboarding) {
              return const Onboarding();
            }

            // Rol bazlı yönlendirme
            switch (role) {
              case 'student':
                return const Student();
              case 'mentor':
                return const MentorDashboard();
              case 'middleSchoolUnitCoordinator':
                return const MiddleSchoolUnitCoordinatorDashboard();
              case 'highSchoolUnitCoordinator':
                return const HighSchoolUnitCoordinatorDashboard();
              case 'universityUnitCoordinator':
                return const UniversityUnitCoordinatorDashboard();
              case 'middleSchoolRegionCoordinator':
                return const MiddleSchoolRegionCoordinatorDashboard();
              case 'highSchoolRegionCoordinator':
                return const HighSchoolRegionCoordinatorDashboard();
              case 'universityRegionCoordinator':
                return const UniversityRegionCoordinatorDashboard();
              case 'countryCoordinator':
                return const CountryCoordinatorDashboard();
              case 'admin':
                return const AdminDashboard();
              default:
                // Herhangi bir role uymuyorsa veya rol null ise HomeDashboard'a yönlendir
                return const HomeDashboard();
            }
          },
        );
      },
    );
  }
}
