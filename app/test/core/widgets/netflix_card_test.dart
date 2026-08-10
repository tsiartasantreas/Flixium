import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iflixify/core/theme/app_colors.dart';
import 'package:iflixify/core/theme/app_theme.dart';
import 'package:iflixify/core/widgets/netflix_card.dart';

void main() {
  Widget wrapInApp(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('NetflixCard', () {
    testWidgets('renders title text', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const NetflixCard(title: 'Breaking Bad'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Breaking Bad'), findsOneWidget);
    });

    testWidgets('renders with no image (placeholder)', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const NetflixCard(title: 'Test Card'),
      ));
      await tester.pumpAndSettle();

      // Should show placeholder icon
      expect(find.byIcon(Icons.movie), findsOneWidget);
    });

    testWidgets('renders with imageUrl', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const NetflixCard(
          title: 'Test',
          imageUrl: 'https://example.com/image.jpg',
        ),
      ));
      await tester.pumpAndSettle();

      // Should render without error (image may not load in test)
      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrapInApp(
        NetflixCard(
          title: 'Tappable',
          onTap: () => tapped = true,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tappable'));
      expect(tapped, isTrue);
    });

    testWidgets('card has correct width for mobile', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(wrapInApp(
        const NetflixCard(title: 'Width Test'),
      ));
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.ancestor(
          of: find.text('Width Test'),
          matching: find.byType(Container),
        ).first,
      );

      expect(container.constraints?.maxWidth, AppTheme.cardWidth);
    });

    testWidgets('title has correct font size', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const NetflixCard(title: 'Font Size Test'),
      ));
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(find.text('Font Size Test'));
      expect(textWidget.style!.fontSize, AppTheme.cardTitleSize);
    });

    testWidgets('title has primary text color', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const NetflixCard(title: 'Color Test'),
      ));
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(find.text('Color Test'));
      expect(textWidget.style!.color, AppColors.textPrimary);
    });

    testWidgets('title has maxLines of 2', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const NetflixCard(
          title:
              'This is a very long title that should be ellipsized after two lines of text',
        ),
      ));
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(
        find.text(
          'This is a very long title that should be ellipsized after two lines of text',
        ),
      );
      expect(textWidget.maxLines, 2);
    });

    testWidgets('title uses ellipsis overflow', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const NetflixCard(
          title:
              'This is a very long title that should be ellipsized after two lines of text',
        ),
      ));
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(
        find.text(
          'This is a very long title that should be ellipsized after two lines of text',
        ),
      );
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });

    testWidgets('live contentType shows landscape icon', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const NetflixCard(
          title: 'Live Channel',
          contentType: 'live',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.live_tv), findsOneWidget);
    });

    testWidgets('radio contentType shows landscape icon', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const NetflixCard(
          title: 'Radio Station',
          contentType: 'radio',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.live_tv), findsOneWidget);
    });

    testWidgets('vod contentType shows movie icon', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const NetflixCard(
          title: 'Movie',
          contentType: 'vod',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.movie), findsOneWidget);
    });

    testWidgets('onTap is null does not crash on tap', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const NetflixCard(title: 'No Tap'),
      ));
      await tester.pumpAndSettle();

      // Should not throw
      await tester.tap(find.text('No Tap'));
      await tester.pumpAndSettle();
    });
  });
}
