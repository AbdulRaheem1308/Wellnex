import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wellnex_app/features/gamification/presentation/screens/leaderboard_screen.dart';
import 'package:wellnex_app/features/gamification/presentation/providers/leaderboard_provider.dart';
import 'package:wellnex_app/services/api_service.dart';
import 'package:wellnex_app/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockApiService extends Mock implements ApiService {}

class StubLeaderboardNotifier extends LeaderboardNotifier {
  StubLeaderboardNotifier(super.apiService, LeaderboardState initialState) {
    state = initialState;
  }

  @override
  Future<void> fetchLeaderboard() async {}
}

void main() {
  testWidgets('LeaderboardScreen renders loading state', (WidgetTester tester) async {
    final mockApi = MockApiService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(mockApi),
          leaderboardProvider.overrideWith((ref) => StubLeaderboardNotifier(mockApi, LeaderboardState(isLoading: true))),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LeaderboardScreen(),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('LeaderboardScreen renders data and tabs correctly', (WidgetTester tester) async {
    final mockApi = MockApiService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(mockApi),
          leaderboardProvider.overrideWith((ref) => StubLeaderboardNotifier(mockApi, LeaderboardState(
            isLoading: false,
            type: LeaderboardType.global,
            timeFrame: TimeFrame.weekly,
            entries: [
              LeaderboardEntry(userId: 'u1', username: 'Alice', rank: 1, xp: 1000, isCurrentUser: true),
              LeaderboardEntry(userId: 'u2', username: 'Bob', rank: 2, xp: 900, isCurrentUser: false),
            ],
            currentUserEntry: LeaderboardEntry(userId: 'u1', username: 'Alice', rank: 1, xp: 1000, isCurrentUser: true),
          ))),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LeaderboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    
    // Verify the tabs
    expect(find.byType(TabBar), findsOneWidget);
    
    // Verify data entries
    expect(find.text('Alice'), findsWidgets);
    expect(find.text('Bob'), findsOneWidget);
  });
}
