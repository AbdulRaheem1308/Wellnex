import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wellnex_app/core/widgets/empty_state_widget.dart';

void main() {
  Widget buildTestable(Widget child, {Brightness brightness = Brightness.light}) {
    return MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: child),
    );
  }

  group('EmptyStateWidget', () {
    testWidgets('renders title and icon correctly', (tester) async {
      await tester.pumpWidget(buildTestable(
        const EmptyStateWidget(title: 'Custom Title', icon: Icons.star),
      ));

      expect(find.text('Custom Title'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('renders subtitle if provided', (tester) async {
      await tester.pumpWidget(buildTestable(
        const EmptyStateWidget(
          title: 'Title',
          subtitle: 'A helpful subtitle',
        ),
      ));

      expect(find.text('A helpful subtitle'), findsOneWidget);
    });

    testWidgets('renders action button if label and callback provided', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(buildTestable(
        EmptyStateWidget(
          title: 'Title',
          actionLabel: 'Click Me',
          onAction: () => tapped = true,
        ),
      ));

      expect(find.text('Click Me'), findsOneWidget);
      final btn = find.byType(ElevatedButton);
      expect(btn, findsOneWidget);
      
      await tester.tap(btn);
      expect(tapped, isTrue);
    });

    testWidgets('renders Semantics correctly', (tester) async {
      await tester.pumpWidget(buildTestable(
        const EmptyStateWidget(
          title: 'No Data',
          subtitle: 'Check later',
        ),
      ));

      expect(
        tester.getSemantics(find.byType(EmptyStateWidget)),
        matchesSemantics(
          label: 'No Data. Check later',
        ),
      );
    });
    
    testWidgets('adapts to dark mode without exceptions', (tester) async {
      await tester.pumpWidget(buildTestable(
        const EmptyStateWidget(title: 'Dark Mode Test', subtitle: 'subtitle'),
        brightness: Brightness.dark,
      ));

      expect(find.text('Dark Mode Test'), findsOneWidget);
      // Container color changes inside based on theme, we just ensure no exceptions are thrown and layout builds
      expect(find.byType(EmptyStateWidget), findsOneWidget);
    });
  });
}
