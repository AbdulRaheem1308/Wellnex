import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wellnex_app/features/gamification/presentation/screens/streak_screen.dart';
import 'package:wellnex_app/features/gamification/presentation/providers/streak_provider.dart';
import 'package:wellnex_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:wellnex_app/services/api_service.dart';
import 'package:wellnex_app/services/health_service.dart';
import 'package:wellnex_app/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';

class MockApiService extends Mock implements ApiService {}
class MockHealthService extends Mock implements HealthService {}

class StubStreakNotifier extends StreakNotifier {
  StubStreakNotifier(super.apiService, StreakState initialState) {
    state = initialState;
  }

  @override
  Future<void> loadStreak() async {}
}

class StubDashboardNotifier extends DashboardNotifier {
  StubDashboardNotifier(super.apiService, super.healthService, DashboardState initialState) {
    state = initialState;
  }
}

void main() {
  testWidgets('StreakScreen renders loading state', (WidgetTester tester) async {
    final mockApi = MockApiService();
    final mockHealth = MockHealthService();
    when(() => mockApi.get(any())).thenAnswer((_) async => Response(
      requestOptions: RequestOptions(path: ''),
      data: [],
      statusCode: 200,
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(mockApi),
          streakProvider.overrideWith((ref) => StubStreakNotifier(mockApi, StreakState(isLoading: true))),
          dashboardProvider.overrideWith((ref) => StubDashboardNotifier(mockApi, mockHealth, DashboardState(
            isLoading: true,
            xpLevel: 1,
            xpCurrentProgress: 0,
            xpToNextLevel: 100,
            syncStatus: SyncStatus.synced,
            sensorStepsToday: 0,
            healthAuthorized: true,
            weeklyHistory: [],
          ))),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StreakScreen(),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('StreakScreen renders streak data', (WidgetTester tester) async {
    final mockApi = MockApiService();
    final mockHealth = MockHealthService();
    when(() => mockApi.get(any())).thenAnswer((_) async => Response(
      requestOptions: RequestOptions(path: ''),
      data: [],
      statusCode: 200,
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(mockApi),
          streakProvider.overrideWith((ref) => StubStreakNotifier(mockApi, StreakState(
            isLoading: false,
            currentStreak: 5,
            longestStreak: 10,
            activeDates: [],
          ))),
          dashboardProvider.overrideWith((ref) => StubDashboardNotifier(mockApi, mockHealth, DashboardState(
            isLoading: false,
            streak: StreakInfo(currentStreak: 5, longestStreak: 10),
            xpLevel: 1,
            xpCurrentProgress: 0,
            xpToNextLevel: 100,
            syncStatus: SyncStatus.synced,
            sensorStepsToday: 0,
            healthAuthorized: true,
            weeklyHistory: [],
          ))),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StreakScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    // Test completes rendering
  });
}
