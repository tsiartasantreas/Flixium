import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iflixify/features/epg/epg_screen.dart';

void main() {
  Widget wrapInApp(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('EpgScreen', () {
    testWidgets('renders EpgScreen widget', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const EpgScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(EpgScreen), findsOneWidget);
    });

    testWidgets('shows empty state when no database provided', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const EpgScreen(),
      ));
      await tester.pumpAndSettle();

      // With no database, should show the empty state.
      expect(find.text('No EPG Data'), findsOneWidget);
    });

    testWidgets('shows refresh button in empty state', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const EpgScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Refresh'), findsOneWidget);
    });

    testWidgets('accepts optional database parameter', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const EpgScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(EpgScreen), findsOneWidget);
    });
  });
}
