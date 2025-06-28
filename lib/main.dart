import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:go_router/go_router.dart';

// Auth Screens
import 'screens/auth/splash_screen.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/username_screen.dart';
import 'screens/auth/role_badge.dart';
import 'screens/auth/verify_registration_otp.dart';
import 'screens/auth/forgot_password.dart' show ForgotPassword;
import 'screens/auth/reset_password.dart' show ResetPassword;

// Onboarding
import 'screens/onboarding/onboarding.dart';
import 'screens/onboarding/profile_setup.dart';
import 'screens/home/home_goal_setup.dart';

// Home
import 'screens/home/home_dashboard.dart';
import 'screens/home/home_daily_entry.dart';
import 'screens/home/home_weekly_summary.dart';

// Mentor
import 'screens/mentor/mentor_dashboard.dart';
import 'screens/mentor/mentor_weekend_report.dart';

// Student
import 'screens/student/student_dashboard.dart';

// Admin
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/admin_id_auth_page.dart';
import 'screens/admin/admin_stats.dart';

// Country Coordinator
import 'screens/country_coordinator/country_coordinator_dashboard.dart';
import 'screens/country_coordinator/country_coordinator_id_auth_page.dart';
import 'screens/country_coordinator/country_coordinator_stats.dart';
import 'screens/country_coordinator/country_coordinator_user_tree_page.dart';

// Region Coordinator
import 'screens/region_coordinator/middle_school/middle_school_region_coordinator_dashboard.dart';
import 'screens/region_coordinator/middle_school/middle_school_region_coordinator_id_auth_page.dart';
import 'screens/region_coordinator/middle_school/middle_school_region_coordinator_stats.dart';
import 'screens/region_coordinator/high_school/high_school_region_coordinator_dashboard.dart';
import 'screens/region_coordinator/high_school/high_school_region_coordinator_id_auth_page.dart';
import 'screens/region_coordinator/high_school/high_school_region_coordinator_stats.dart';
import 'screens/region_coordinator/university/university_region_coordinator_dashboard.dart';
import 'screens/region_coordinator/university/university_region_coordinator_id_auth_page.dart';
import 'screens/region_coordinator/university/university_region_coordinator_stats.dart';

// Unit Coordinator
import 'screens/unit_coordinator/middle_school/middle_school_unit_coordinator_dashboard.dart';
import 'screens/unit_coordinator/middle_school/middle_school_unit_coordinator_id_auth_page.dart';
import 'screens/unit_coordinator/middle_school/middle_school_unit_coordinator_edit_mentor_mentee.dart';
import 'screens/unit_coordinator/middle_school/middle_school_unit_coordinator_stats.dart';
import 'screens/unit_coordinator/high_school/high_school_unit_coordinator_dashboard.dart';
import 'screens/unit_coordinator/high_school/high_school_unit_coordinator_id_auth_page.dart';
import 'screens/unit_coordinator/high_school/high_school_unit_coordinator_edit_mentor_mentee.dart' as mentor_mentee_page;
import 'screens/unit_coordinator/high_school/high_school_unit_coordinator_mentors.dart';
import 'screens/unit_coordinator/high_school/high_school_unit_coordinator_mentees.dart';
import 'screens/unit_coordinator/high_school/high_school_unit_coordinator_stats.dart';
import 'screens/unit_coordinator/high_school/high_school_unit_coordinator_stats_active_students.dart';
import 'screens/unit_coordinator/high_school/high_school_unit_coordinator_stats_activities.dart';
import 'screens/unit_coordinator/high_school/high_school_unit_coordinator_stats_activity_counts.dart';
import 'screens/unit_coordinator/high_school/high_school_unit_coordinator_stats_activity_counts_by_mentor.dart';
import 'screens/unit_coordinator/university/university_unit_coordinator_dashboard.dart';
import 'screens/unit_coordinator/university/university_unit_coordinator_id_auth_page.dart';
import 'screens/unit_coordinator/university/university_unit_coordinator_student_stats.dart';
import 'screens/unit_coordinator/high_school/high_school_unit_coordinator_academic_calendar.dart';

// Settings
import 'screens/settings/settings.dart';
import 'screens/settings/profile.dart';
import 'screens/settings/help_center.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    DevicePreview(
      enabled: true,
      builder: (context) => const MentorBridgeApp(),
    ),
  );
}

class MentorBridgeApp extends StatelessWidget {
  const MentorBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      builder: DevicePreview.appBuilder,
      title: 'MentorBridge',
      theme: ThemeData(
        fontFamily: 'NotoSans',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          centerTitle: true,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      routerConfig: GoRouter(
        initialLocation: '/splash',
        routes: [
          GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
          GoRoute(path: '/authGate', builder: (context, state) => const AuthGate()),
          GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
          GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
          GoRoute(
            path: '/register',
            builder: (context, state) {
              final args = state.extra as Map<String, dynamic>? ?? {};
              return RegisterScreen(
                username: args['username'] ?? '',
                firstName: args['firstName'] ?? '',
                lastName: args['lastName'],
                country: args['country'] ?? '',
                province: args['province'] ?? '',
                city: args['city'] ?? '',
                gender: args['gender'] ?? '',
              );
            },
          ),
          GoRoute(path: '/username', builder: (context, state) => const UsernameScreen()),
          GoRoute(
            path: '/roleBadge',
            builder: (context, state) => RoleBadge(role: state.extra as String),
          ),
          GoRoute(
            path: '/verifyRegistrationOtp',
            builder: (context, state) {
              final args = state.extra as Map<String, dynamic>;
              return VerifyRegistrationOtp(
                email: args['email'],
                password: args['password'],
                username: args['username'],
                firstName: args['firstName'],
                lastName: args['lastName'],
                country: args['country'],
                province: args['province'],
                city: args['city'],
                gender: args['gender'],
              );
            },
          ),
          GoRoute(path: '/forgotPassword', builder: (context, state) => const ForgotPassword()),
          GoRoute(
            path: '/resetPassword',
            builder: (context, state) {
              final args = state.extra as Map<String, String>? ?? {};
              return ResetPassword(email: args['email'] ?? '', otp: args['otp'] ?? '');
            },
          ),
          GoRoute(path: '/onboarding', builder: (context, state) => const Onboarding()),
          GoRoute(path: '/profileSetup', builder: (context, state) => const ProfileSetup()),
          GoRoute(path: '/homegoalSetup', builder: (context, state) => const HomeGoalSetup()),
          GoRoute(path: '/homeDashboard', builder: (context, state) => const HomeDashboard()),
          GoRoute(path: '/homeDailyEntry', builder: (context, state) => const HomeDailyEntry()),
          GoRoute(path: '/homeWeeklySummary', builder: (context, state) => const HomeWeeklySummary()),
          GoRoute(path: '/adminDashboard', builder: (context, state) => const AdminDashboard()),
          GoRoute(path: '/countryCoordinatorDashboard', builder: (context, state) => const CountryCoordinatorDashboard()),
          GoRoute(path: '/regionCoordinatorDashboard', builder: (context, state) => const MiddleSchoolRegionCoordinatorDashboard()),
          GoRoute(path: '/unitCoordinatorDashboard', builder: (context, state) => const MiddleSchoolUnitCoordinatorDashboard()),
          GoRoute(path: '/mentorDashboard', builder: (context, state) => const MentorDashboard()),
          GoRoute(path: '/mentorWeekendReport', builder: (context, state) => const MentorWeekendReport()),
          GoRoute(path: '/studentScreen', builder: (context, state) => const Student()),
          GoRoute(path: '/adminIdAuthPage', builder: (context, state) => const AdminIdAuthPage()),
          GoRoute(path: '/adminStats', builder: (context, state) => const AdminStats()),
          GoRoute(path: '/countryCoordinatorIdAuthPage', builder: (context, state) => const CountryCoordinatorIdAuthPage()),
          GoRoute(path: '/countryCoordinatorStats', builder: (context, state) => const CountryCoordinatorStats()),
          GoRoute(path: '/countryCoordinatorUserTree', builder: (context, state) => const CountryCoordinatorUserTreePage()),
          GoRoute(path: '/middleSchoolRegionCoordinatorIdAuthPage', builder: (context, state) => const MiddleSchoolRegionCoordinatorIdAuthPage()),
          GoRoute(path: '/middleSchoolRegionCoordinatorStats', builder: (context, state) => const MiddleSchoolRegionCoordinatorStats()),
          GoRoute(path: '/highSchoolRegionCoordinatorDashboard', builder: (context, state) => const HighSchoolRegionCoordinatorDashboard()),
          GoRoute(path: '/highSchoolRegionCoordinatorIdAuthPage', builder: (context, state) => const HighSchoolRegionCoordinatorIdAuthPage()),
          GoRoute(path: '/highSchoolRegionCoordinatorStats', builder: (context, state) => const HighSchoolRegionCoordinatorStats()),
          GoRoute(path: '/universityRegionCoordinatorDashboard', builder: (context, state) => const UniversityRegionCoordinatorDashboard()),
          GoRoute(path: '/universityRegionCoordinatorIdAuthPage', builder: (context, state) => const UniversityRegionCoordinatorIdAuthPage()),
          GoRoute(path: '/universityRegionCoordinatorStats', builder: (context, state) => const UniversityRegionCoordinatorStats()),
          GoRoute(path: '/middleSchoolUnitCoordinatorIdAuthPage', builder: (context, state) => const MiddleSchoolUnitCoordinatorIdAuthPage()),
          GoRoute(path: '/middleSchoolUnitCoordinatorEditMentorMentee', builder: (context, state) => const MiddleSchoolUnitCoordinatorEditMentorMentee()),
          GoRoute(path: '/middleSchoolUnitCoordinatorStats', builder: (context, state) => const MiddleSchoolUnitCoordinatorStats()),
          GoRoute(path: '/middleSchoolUnitCoordinatorDashboard', builder: (context, state) => const MiddleSchoolUnitCoordinatorDashboard()),
          GoRoute(path: '/highSchoolUnitCoordinatorIdAuthPage', builder: (context, state) => const HighSchoolUnitCoordinatorIdAuthPage()),
          GoRoute(path: '/highSchoolUnitCoordinatorEditMentorMentee', builder: (context, state) => const mentor_mentee_page.HighSchoolUnitCoordinatorEditMentorMentee()),
          GoRoute(path: '/highSchoolUnitCoordinatorMentors', builder: (context, state) => const HighSchoolUnitCoordinatorMentors()),
          GoRoute(path: '/highSchoolUnitCoordinatorMentees', builder: (context, state) => const HighSchoolUnitCoordinatorMentees()),
          GoRoute(path: '/highSchoolUnitCoordinatorStats', builder: (context, state) => const HighSchoolUnitCoordinatorStats()),
          GoRoute(path: '/highSchoolUnitCoordinatorDashboard', builder: (context, state) => const HighSchoolUnitCoordinatorDashboard()),
          GoRoute(path: '/universityUnitCoordinatorIdAuthPage', builder: (context, state) => const UniversityUnitCoordinatorIdAuthPage()),
          GoRoute(path: '/universityUnitCoordinatorStudentStats', builder: (context, state) => const UniversityUnitCoordinatorStudentStats()),
          GoRoute(path: '/universityUnitCoordinatorDashboard', builder: (context, state) => const UniversityUnitCoordinatorDashboard()),
          GoRoute(path: '/settings', builder: (context, state) => const Settings()),
          GoRoute(path: '/profile', builder: (context, state) => const Profile()),
          GoRoute(path: '/help', builder: (context, state) => const HelpCenter()),
          GoRoute(path: '/highSchoolUnitCoordinatorStatsActiveStudents', builder: (context, state) {
            final args = state.extra as Map<String, dynamic>? ?? {};
            return HighSchoolUnitCoordinatorStatsActiveStudentsPage(
              filters: args,
            );
          }),
          GoRoute(path: '/highSchoolUnitCoordinatorStatsActivities', builder: (context, state) {
            final args = state.extra as Map<String, dynamic>? ?? {};
            return HighSchoolUnitCoordinatorStatsActivitiesPage(
              filters: args,
            );
          }),
          GoRoute(path: '/highSchoolUnitCoordinatorStatsActivityCounts', builder: (context, state) {
            final args = state.extra as Map<String, dynamic>? ?? {};
            return HighSchoolUnitCoordinatorStatsActivityCountsPage(
              filters: args,
            );
          }),
          GoRoute(path: '/highSchoolUnitCoordinatorStatsActivityCountsByMentor', builder: (context, state) {
            final args = state.extra as Map<String, dynamic>? ?? {};
            return HighSchoolUnitCoordinatorStatsActivityCountsByMentorPage(
              filters: args,
            );
          }),
          GoRoute(path: '/highSchoolUnitCoordinatorAcademicCalendar', builder: (context, state) => const HighSchoolUnitCoordinatorAcademicCalendar()),
        ],
      ),
    );
  }
}
