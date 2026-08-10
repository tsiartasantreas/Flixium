import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iflixify/features/settings/settings_screen.dart';

void main() {
  Widget wrapInApp(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('SettingsScreen', () {
    testWidgets('renders SettingsScreen widget', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const SettingsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('shows Settings title in app bar', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const SettingsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('shows Profile section header', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const SettingsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('PROFILE'), findsOneWidget);
    });

    testWidgets('shows user display name', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const SettingsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('User'), findsOneWidget);
    });

    testWidgets('shows Free tier badge', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const SettingsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Free'), findsOneWidget);
    });

    testWidgets('shows Auto-play toggle', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const SettingsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Auto-play'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('can toggle Auto-play switch', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const SettingsScreen(),
      ));
      await tester.pumpAndSettle();

      final switchWidget = find.byType(Switch);
      expect(switchWidget, findsOneWidget);

      await tester.tap(switchWidget);
      await tester.pumpAndSettle();

      final switchState = tester.widget<Switch>(switchWidget);
      expect(switchState.value, isFalse);
    });

    testWidgets('shows Video Quality option', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const SettingsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Video Quality'), findsOneWidget);
    });

    testWidgets('shows Clear Cache option', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const SettingsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Clear Cache'), findsOneWidget);
    });

    testWidgets('shows Clear EPG Data option', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const SettingsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Clear EPG Data'), findsOneWidget);
    });

    testWidgets('shows edit profile icon', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const SettingsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('shows person icon for profile', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const SettingsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.person), findsOneWidget);
    });
  });
}
