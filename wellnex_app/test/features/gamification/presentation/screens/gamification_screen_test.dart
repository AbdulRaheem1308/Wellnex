import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wellnex_app/features/gamification/presentation/screens/gamification_screen.dart';
import 'package:wellnex_app/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:wellnex_app/services/api_service.dart';
import 'package:wellnex_app/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockApiService extends Mock implements ApiService {}

class StubGamificationNotifier extends GamificationNotifier {
  StubGamificationNotifier(super.apiService, GamificationState initialState) {
    state = initialState;
  }
}

void main() {
  testWidgets('GamificationScreen renders loading state', (WidgetTester tester) async {
    final mockApi = MockApiService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(mockApi),
          gamificationProvider.overrideWith((ref) => StubGamificationNotifier(mockApi, GamificationState(isLoading: true))),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GamificationScreen(),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('GamificationScreen renders empty state when no activity', (WidgetTester tester) async {
    final mockApi = MockApiService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(mockApi),
          gamificationProvider.overrideWith((ref) => StubGamificationNotifier(mockApi, GamificationState(
            isLoading: false,
            level: 5,
            levelTitle: 'Explorer',
            currentXp: 500,
            nextLevelXp: 1000,
            globalRank: 10,
            currentStreak: 5,
            recentActivity: [],
          ))),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GamificationScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    // Test completes rendering
  });
}
