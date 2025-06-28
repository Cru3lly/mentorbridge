// lib/utils/username_generator.dart

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

final List<String> _adjectives = [
  'swift', 'silent', 'clever', 'happy', 'brave', 'bright',
  'cool', 'quick', 'gentle', 'bold', 'sunny', 'zany',
];

final List<String> _nouns = [
  'tiger', 'eagle', 'panda', 'lion', 'rabbit', 'fox',
  'wolf', 'otter', 'whale', 'owl', 'bear', 'monkey',
];

final Random _random = Random();

String _generateCandidate() {
  final adjective = _adjectives[_random.nextInt(_adjectives.length)];
  final noun = _nouns[_random.nextInt(_nouns.length)];
  final number = _random.nextInt(1000);
  return '$adjective$noun$number';
}

Future<String> generateUsername() async {
  for (int i = 0; i < 30; i++) {
    final candidate = _generateCandidate();
    final doc = await FirebaseFirestore.instance
        .collection('usernames')
        .doc(candidate)
        .get();
    if (!doc.exists) return candidate;
  }
  return 'user${_random.nextInt(100000)}';
}
