import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wellnex_app/features/rewards/presentation/screens/rewards_screen.dart';
import 'package:wellnex_app/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Provide a fake mock scope so real APIs aren't called by providers if they load data on init
void main() {
  testWidgets('RewardsScreen shows Coming Soon placeholder on Catalog tab', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('en', '')],
          home: RewardsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Wallet tab is default and renders (we just check the tab is there)
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Catalog'), findsOneWidget);

    // Tap the Catalog tab
    await tester.tap(find.text('Catalog'));
    await tester.pumpAndSettle();

    // Verify the Coming Soon placeholder appears
    expect(find.text('Coming Soon!'), findsOneWidget);
    expect(
      find.text('The Rewards Catalog will be unlocked\nonce we are fully live!'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.card_giftcard), findsNWidgets(2));
  });
}
