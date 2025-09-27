import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:go_router/go_router.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

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

// Mentor
import 'screens/mentor/middle_school_mentor_weekend_report.dart';
import 'screens/mentor/high_school_mentor_weekend_report.dart';
import 'screens/mentor/middle_school_mentor_academic_calendar.dart';
import 'screens/mentor/high_school_mentor_academic_calendar.dart';

// Universal
import 'screens/universal/universal_role_assignment_page.dart';
import 'screens/universal/universal_role_dashboard.dart';
import 'screens/universal/universal_orphaned_groups.dart';
import 'screens/universal/universal_user_tree_page.dart';
import 'screens/universal/universal_edit_mentor_mentee_page.dart';
import 'screens/universal/universal_mentors_page.dart';
import 'screens/universal/universal_mentees_page.dart';
import 'screens/universal/universal_mentor_weekend_report.dart';

// Admin
import 'screens/user/add_habit_page.dart';

// Assistant Coordinator
import 'screens/assistant_coordinator/high_school/high_school_assistant_coordinator_stats.dart';
import 'screens/assistant_coordinator/high_school/high_school_assistant_coordinator_stats_active_students.dart';
import 'screens/assistant_coordinator/high_school/high_school_assistant_coordinator_stats_activities.dart';
import 'screens/assistant_coordinator/high_school/high_school_assistant_coordinator_stats_activity_counts.dart';
import 'screens/assistant_coordinator/high_school/high_school_assistant_coordinator_stats_activity_counts_by_mentor.dart';

// Settings
import 'screens/settings/settings.dart';
import 'screens/settings/profile.dart';
import 'screens/settings/help_center.dart';
import 'screens/settings/theme_color_settings.dart';

// Unified Dashboard
import 'screens/unified_dashboard.dart';

// App Shell
import 'widgets/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with error handling
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    // Firebase already initialized, continue
    print('Firebase already initialized: $e');
  }

  // Initialize Notification Service
  await NotificationService.initialize();

  // Setup FCM handlers
  NotificationService.setupFCMHandlers();

  runApp(const MentorBridgeApp());
}

class MentorBridgeApp extends StatelessWidget {
  const MentorBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'MentorBridge',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: GoRouter(
        initialLocation: '/splash',
        routes: [
          // Shell route - wraps main app pages with navigation
          ShellRoute(
            builder: (context, state, child) => AppShell(child: child),
            routes: [
              GoRoute(
                  path: '/unifiedDashboard',
                  builder: (context, state) => const UnifiedDashboard()),
              GoRoute(
                  path: '/addHabit',
                  builder: (context, state) => const AddHabitPage()),
              GoRoute(
                  path: '/settings',
                  builder: (context, state) => const Settings()),
              GoRoute(
                  path: '/profile',
                  builder: (context, state) => const Profile()),
              GoRoute(
                  path: '/help',
                  builder: (context, state) => const HelpCenter()),
              GoRoute(
                  path: '/settings/theme-color',
                  builder: (context, state) => const ThemeColorSettings()),
            ],
          ),
          // Non-shell routes - no navigation bar
          GoRoute(
              path: '/splash',
              builder: (context, state) => const SplashScreen()),
          GoRoute(
              path: '/authGate', builder: (context, state) => const AuthGate()),
          GoRoute(
              path: '/auth', builder: (context, state) => const AuthScreen()),
          GoRoute(
              path: '/login', builder: (context, state) => const LoginScreen()),
          GoRoute(
            path: '/register',
            builder: (context, state) {
              final args = state.extra as Map<String, dynamic>? ?? {};
              return RegisterScreen(
                username: args['username'] ?? '',
                firstName: args['firstName'] ?? '',
                lastName: args['lastName'] ?? '',
                country: args['country'] ?? '',
                province: args['province'] ?? '',
                city: args['city'] ?? '',
                gender: args['gender'] ?? '',
              );
            },
          ),
          GoRoute(
              path: '/username',
              builder: (context, state) => const UsernameScreen()),
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
                lastName: args['lastName'] ?? '',
                country: args['country'],
                province: args['province'],
                city: args['city'],
                gender: args['gender'],
              );
            },
          ),
          GoRoute(
              path: '/forgotPassword',
              builder: (context, state) => const ForgotPassword()),
          GoRoute(
            path: '/resetPassword',
            builder: (context, state) {
              final args = state.extra as Map<String, String>? ?? {};
              return ResetPassword(
                  email: args['email'] ?? '', otp: args['otp'] ?? '');
            },
          ),
          GoRoute(
              path: '/onboarding',
              builder: (context, state) => const Onboarding()),
          GoRoute(
              path: '/profileSetup',
              builder: (context, state) => const ProfileSetup()),

          // Assistant Coordinators
          GoRoute(
              path: '/highSchoolAssistantCoordinatorStats',
              builder: (context, state) =>
                  const HighSchoolAssistantCoordinatorStats()),

          // Mentors
          GoRoute(
              path: '/middleSchoolMentorWeekendReport',
              builder: (context, state) =>
                  const MiddleSchoolMentorWeekendReport()),
          GoRoute(
              path: '/highSchoolMentorWeekendReport',
              builder: (context, state) =>
                  const HighSchoolMentorWeekendReport()),
          GoRoute(
              path: '/middleSchoolMentorAcademicCalendar',
              builder: (context, state) =>
                  const MiddleSchoolMentorAcademicCalendarPage()),
          GoRoute(
              path: '/highSchoolMentorAcademicCalendar',
              builder: (context, state) =>
                  const HighSchoolMentorAcademicCalendarPage()),

          // Universal
          GoRoute(
              path: '/universalRoleAssignmentPage',
              builder: (context, state) => const UniversalRoleAssignmentPage()),
          GoRoute(
              path: '/universalRoleDashboard',
              builder: (context, state) => const UniversalRoleDashboard(
                  currentRole: 'user', allUserRoles: ['user'])),
          GoRoute(
            path: '/universalOrphanedGroups',
            builder: (context, state) {
              final contextRole = state.uri.queryParameters['contextRole'];
              return UniversalOrphanedGroups(contextRole: contextRole);
            },
          ),
          GoRoute(
            path: '/universalRoleAssignment',
            builder: (context, state) {
              final contextRole = state.uri.queryParameters['contextRole'];
              return UniversalRoleAssignmentPage(contextRole: contextRole);
            },
          ),
          GoRoute(
            path: '/universalUserTree',
            builder: (context, state) {
              final currentRole =
                  state.uri.queryParameters['currentRole'] ?? 'user';
              final userId = state.uri.queryParameters['userId'] ?? '';
              return UniversalUserTreePage(
                  currentRole: currentRole, userId: userId);
            },
          ),
          GoRoute(
              path: '/universalEditMentorMentee',
              builder: (context, state) =>
                  const UniversalEditMentorMenteePage()),
          GoRoute(
              path: '/universalMentors',
              builder: (context, state) => const UniversalMentorsPage()),
          GoRoute(
              path: '/universalMentees',
              builder: (context, state) => const UniversalMenteesPage()),
          GoRoute(
              path: '/universalMentorWeekendReport',
              builder: (context, state) =>
                  const UniversalMentorWeekendReport()),
          GoRoute(
              path: '/settings', builder: (context, state) => const Settings()),
          GoRoute(
              path: '/profile', builder: (context, state) => const Profile()),
          GoRoute(
              path: '/help', builder: (context, state) => const HelpCenter()),

          // Advanced Assistant Coordinator Stats (eski Unit Coordinator stats)
          GoRoute(
              path: '/highSchoolAssistantCoordinatorStatsActiveStudents',
              builder: (context, state) {
                final args = state.extra as Map<String, dynamic>? ?? {};
                return HighSchoolAssistantCoordinatorStatsActiveStudentsPage(
                  filters: args,
                );
              }),
          GoRoute(
              path: '/highSchoolAssistantCoordinatorStatsActivities',
              builder: (context, state) {
                final args = state.extra as Map<String, dynamic>? ?? {};
                return HighSchoolAssistantCoordinatorStatsActivitiesPage(
                  filters: args,
                );
              }),
          GoRoute(
              path: '/highSchoolAssistantCoordinatorStatsActivityCounts',
              builder: (context, state) {
                final args = state.extra as Map<String, dynamic>? ?? {};
                return HighSchoolAssistantCoordinatorStatsActivityCountsPage(
                  filters: args,
                );
              }),
          GoRoute(
              path:
                  '/highSchoolAssistantCoordinatorStatsActivityCountsByMentor',
              builder: (context, state) {
                final args = state.extra as Map<String, dynamic>? ?? {};
                return HighSchoolAssistantCoordinatorStatsActivityCountsByMentorPage(
                  filters: args,
                );
              }),
          // This route moved above to highSchoolAssistantCoordinatorAcademicCalendar
          GoRoute(
              path: '/middleSchoolMentorAcademicCalendar',
              builder: (context, state) =>
                  const MiddleSchoolMentorAcademicCalendarPage()),
          GoRoute(
              path: '/highSchoolMentorAcademicCalendar',
              builder: (context, state) =>
                  const HighSchoolMentorAcademicCalendarPage()),
        ],
      ),
    );
  }
}
