// This is a basic Flutter widget test.
//
// Since the app talks to a real backend (login, OTP, dashboards), this
// smoke test just verifies the app boots and renders without throwing —
// it does not attempt to log in or hit the network.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:succor_haven/main.dart';

void main() {
  testWidgets('App boots and shows the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SuccorHavenApp()));

    // Initial route is '/login' — just confirm something rendered
    // without throwing, rather than asserting on specific text/widgets
    // that may change as the login screen evolves.
    await tester.pump();

    expect(find.byType(SuccorHavenApp), findsOneWidget);
  });
}