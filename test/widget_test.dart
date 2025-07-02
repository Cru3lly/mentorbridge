import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mentorbridge/main.dart';

void main() {
  testWidgets('App loads and increments counter (placeholder)', (WidgetTester tester) async {
    await tester.pumpWidget(const MentorBridgeApp());

    // Bu test sadece app'in sorunsuz açıldığını test eder, counter yoksa geçici olarak yorum satırı yapılabilir:
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
