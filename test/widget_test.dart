import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_news_assistant/main.dart';

void main() {
  testWidgets('App renders without errors', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(
      const ProviderScope(child: PersonalNewsAssistant()),
    );

    // Verify the app title is shown
    expect(find.text('News Assistant'), findsOneWidget);
  });
}
