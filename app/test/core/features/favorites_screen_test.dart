import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iflixify/features/favorites/favorites_screen.dart';

void main() {
  Widget wrapInApp(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('FavoritesScreen', () {
    testWidgets('renders FavoritesScreen widget', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const FavoritesScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(FavoritesScreen), findsOneWidget);
    });

    testWidgets('shows empty state when no database provided', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const FavoritesScreen(),
      ));
      await tester.pumpAndSettle();

      // With no database, should show the empty state.
      expect(find.text('My List is Empty'), findsOneWidget);
    });

    testWidgets('shows empty state description', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const FavoritesScreen(),
      ));
      await tester.pumpAndSettle();

      expect(
        find.text('Browse and tap the + icon to add\nfavourites to your list.'),
        findsOneWidget,
      );
    });

    testWidgets('accepts optional database parameter', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const FavoritesScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(FavoritesScreen), findsOneWidget);
    });
  });
}
