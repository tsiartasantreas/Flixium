import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iflixify/core/theme/app_colors.dart';
import 'package:iflixify/core/widgets/netflix_billboard.dart';

void main() {
  Widget wrapInApp(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('NetflixBillboard', () {
    testWidgets('renders empty when items list is empty', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const NetflixBillboard(items: []),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(SizedBox), findsWidgets);
      // No title, no buttons
      expect(find.text('Play'), findsNothing);
    });

    testWidgets('renders title of first item', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const NetflixBillboard(
          items: [
            NetflixBillboardItem(title: 'Stranger Things'),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Stranger Things'), findsOneWidget);
    });

    testWidgets('renders synopsis text', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const NetflixBillboard(
          items: [
            NetflixBillboardItem(
              title: 'Show',
              synopsis: 'A thrilling sci-fi adventure',
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('A thrilling sci-fi adventure'), findsOneWidget);
    });

    testWidgets('renders Play button', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const NetflixBillboard(
          items: [
            NetflixBillboardItem(title: 'Show'),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Play'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('renders My List button', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const NetflixBillboard(
          items: [
            NetflixBillboardItem(title: 'Show'),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('My List'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('Play button calls onPlay callback', (tester) async {
      var playTapped = false;

      await tester.pumpWidget(wrapInApp(
        NetflixBillboard(
          items: [
            NetflixBillboardItem(
              title: 'Show',
              onPlay: () => playTapped = true,
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Play'));
      expect(playTapped, isTrue);
    });

    testWidgets('My List button calls onMyList callback', (tester) async {
      var myListTapped = false;

      await tester.pumpWidget(wrapInApp(
        NetflixBillboard(
          items: [
            NetflixBillboardItem(
              title: 'Show',
              onMyList: () => myListTapped = true,
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('My List'));
      expect(myListTapped, isTrue);
    });

    testWidgets('title has bold font weight', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const NetflixBillboard(
          items: [
            NetflixBillboardItem(title: 'Bold Title'),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(find.text('Bold Title'));
      expect(
        textWidget.style!.fontWeight,
        anyOf(equals(FontWeight.w700), equals(FontWeight.w800)),
      );
    });

    testWidgets('title has primary text color', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const NetflixBillboard(
          items: [
            NetflixBillboardItem(title: 'White Title'),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(find.text('White Title'));
      expect(textWidget.style!.color, AppColors.textPrimary);
    });

    testWidgets('synopsis has secondary text color', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const NetflixBillboard(
          items: [
            NetflixBillboardItem(
              title: 'Show',
              synopsis: 'Secondary text',
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(find.text('Secondary text'));
      expect(textWidget.style!.color, AppColors.textSecondary);
    });

    testWidgets('shows placeholder gradient when no image', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const NetflixBillboard(
          items: [
            NetflixBillboardItem(title: 'No Image'),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.movie_filter), findsOneWidget);
    });

    testWidgets('multiple items show indicator dots', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const NetflixBillboard(
          items: [
            NetflixBillboardItem(title: 'Item 1'),
            NetflixBillboardItem(title: 'Item 2'),
            NetflixBillboardItem(title: 'Item 3'),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      // First dot should be active (white), others dimmed
      final animatedContainers = find.byType(AnimatedContainer);
      expect(animatedContainers, findsNWidgets(3));
    });

    testWidgets('single item does not show indicator dots', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const NetflixBillboard(
          items: [
            NetflixBillboardItem(title: 'Solo'),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedContainer), findsNothing);
    });

    testWidgets('title maxLines is 2', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const NetflixBillboard(
          items: [
            NetflixBillboardItem(
              title:
                  'This is a very long title that should be truncated after two lines',
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(
        find.text(
          'This is a very long title that should be truncated after two lines',
        ),
      );
      expect(textWidget.maxLines, 2);
    });

    testWidgets('title uses ellipsis overflow', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const NetflixBillboard(
          items: [
            NetflixBillboardItem(
              title:
                  'This is a very long title that should be truncated after two lines',
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(
        find.text(
          'This is a very long title that should be truncated after two lines',
        ),
      );
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });

    testWidgets('synopsis maxLines is 2 on mobile', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const NetflixBillboard(
          items: [
            NetflixBillboardItem(
              title: 'Show',
              synopsis:
                  'A very long synopsis that should be truncated after two lines of text on mobile devices',
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(
        find.text(
          'A very long synopsis that should be truncated after two lines of text on mobile devices',
        ),
      );
      expect(textWidget.maxLines, 2);
    });
  });
}
