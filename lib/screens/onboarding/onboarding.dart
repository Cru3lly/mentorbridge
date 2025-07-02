import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Onboarding extends StatelessWidget {
  const Onboarding({super.key});

  Future<void> _onDone(BuildContext context) async {
    // Onboarding tamamlandığında completedOnboarding alanını true yap
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'completedOnboarding': true,
      });
    }
    context.go('/authGate');
  }

  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      pages: [
        PageViewModel(
          title: 'Track Your Daily Habits',
          body:
          'Log your Quran recitation, prayers, memorization, and other activities each day.',
          image: const Icon(
            Icons.check_circle_outline,
            size: 120,
            color: Colors.green,
          ),
        ),
        PageViewModel(
          title: 'View Weekly Summaries',
          body:
          'See charts of your progress over the last week to stay motivated.',
          image: const Icon(
            Icons.bar_chart,
            size: 120,
            color: Colors.blue,
          ),
        ),
        PageViewModel(
          title: 'Stay Motivated',
          body: 'Set goals, track your progress, and grow spiritually.',
          image: const Icon(
            Icons.emoji_objects,
            size: 120,
            color: Colors.amber,
          ),
        ),
      ],
      onDone: () => _onDone(context),
      showSkipButton: true,
      skip: const Text('Skip'),
      next: const Text('Next'),
      back: const Text('Back'),
      done: const Text(
        'Done',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      dotsDecorator: const DotsDecorator(
        activeColor: Colors.deepPurple,
      ),
    );
  }
}
