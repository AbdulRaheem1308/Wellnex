import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wellnex_app/features/dashboard/presentation/widgets/explainer_bottom_sheet.dart';

void main() {
  testWidgets('ExplainerBottomSheet shows correctly with items', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() => tester.view.reset());
    const items = [
      ExplainerItem(
        title: 'Title 1',
        description: 'Description 1',
        icon: Icons.abc,
      ),
      ExplainerItem(
        title: 'Title 2',
        description: 'Description 2',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  ExplainerBottomSheet.show(
                    context,
                    title: 'Test Title',
                    headerIcon: Icons.info,
                    items: items,
                  );
                },
                child: const Text('Show'),
              );
            },
          ),
        ),
      ),
    );

    // Tap button to show bottom sheet
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    // Verify content
    expect(find.text('Test Title'), findsOneWidget);
    expect(find.text('Title 1'), findsOneWidget);
    expect(find.text('Description 1'), findsOneWidget);
    expect(find.text('Title 2'), findsOneWidget);
    expect(find.text('Description 2'), findsOneWidget);

    // Verify "I got it" button
    expect(find.text('I got it'), findsOneWidget);

    // Tap "I got it"
    await tester.tap(find.text('I got it'));
    await tester.pumpAndSettle();

    // Verify bottom sheet is dismissed
    expect(find.text('Test Title'), findsNothing);
  });
}
