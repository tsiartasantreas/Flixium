import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iflixify/core/theme/app_colors.dart';
import 'package:iflixify/core/theme/app_theme.dart';
import 'package:iflixify/core/widgets/netflix_row.dart';

void main() {
  Widget wrapInApp(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  List<NetflixRowItem> generateItems(int count) {
    return List.generate(
      count,
      (i) => NetflixRowItem(
        title: 'Item $i',
        onTap: () {},
      ),
    );
  }

  group('NetflixRow', () {
    testWidgets('renders section label', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const NetflixRow(
          label: 'Live TV',
          items: [],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Live TV'), findsOneWidget);
    });

    testWidgets('renders all card titles', (tester) async {
      final items = generateItems(5);

      await tester.pumpWidget(wrapInApp(
        NetflixRow(
          label: 'Movies',
          items: items,
        ),
      ));
      await tester.pumpAndSettle();

      for (var i = 0; i < 5; i++) {
        expect(find.text('Item $i'), findsOneWidget);
      }
    });

    testWidgets('renders empty row without crash', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const NetflixRow(
          label: 'Empty Row',
          items: [],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Empty Row'), findsOneWidget);
    });

    testWidgets('section label has bold font', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const NetflixRow(
          label: 'Bold Label',
          items: [],
        ),
      ));
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(find.text('Bold Label'));
      expect(textWidget.style!.fontWeight, FontWeight.bold);
    });

    testWidgets('section label has primary text color', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const NetflixRow(
          label: 'White Label',
          items: [],
        ),
      ));
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(find.text('White Label'));
      expect(textWidget.style!.color, AppColors.textPrimary);
    });

    testWidgets('See All is visible on mobile', (tester) async {
      await tester.pumpWidget(wrapInApp(
        NetflixRow(
          label: 'Shows',
          items: generateItems(3),
          onSeeAll: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('See All'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('See All is not shown when onSeeAll is null', (tester) async {
      await tester.pumpWidget(wrapInApp(
        NetflixRow(
          label: 'No See All',
          items: generateItems(3),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('See All'), findsNothing);
    });

    testWidgets('onSeeAll callback fires when tapped', (tester) async {
      var seeAllTapped = false;

      await tester.pumpWidget(wrapInApp(
        NetflixRow(
          label: 'Tappable See All',
          items: generateItems(3),
          onSeeAll: () => seeAllTapped = true,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('See All'));
      expect(seeAllTapped, isTrue);
    });

    testWidgets('contains a horizontal ListView', (tester) async {
      await tester.pumpWidget(wrapInApp(
        NetflixRow(
          label: 'Scrollable Row',
          items: generateItems(10),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('cards are rendered in the row', (tester) async {
      await tester.pumpWidget(wrapInApp(
        NetflixRow(
          label: 'Cards Row',
          items: generateItems(3),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
    });

    testWidgets('row height accommodates cards', (tester) async {
      await tester.pumpWidget(wrapInApp(
        NetflixRow(
          label: 'Height Test',
          items: generateItems(3),
        ),
      ));
      await tester.pumpAndSettle();

      final sizedBox = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byType(ListView),
          matching: find.byType(SizedBox),
        ),
      );

      expect(sizedBox.height, AppTheme.cardHeight + 40);
    });
  });
}
