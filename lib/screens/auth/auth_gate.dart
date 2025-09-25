import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
// Onboarding
import '../onboarding/onboarding.dart';
// Unified Dashboard
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
            // Note: Role is now handled in UnifiedDashboard
            final completedOnboarding =
                userData['completedOnboarding'] as bool? ?? false;

            if (!completedOnboarding) {
              return const Onboarding();
            }

            // Redirect to unified dashboard route (with AppShell)
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/unifiedDashboard');
            });
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          },
        );
      },
    );
  }
}
