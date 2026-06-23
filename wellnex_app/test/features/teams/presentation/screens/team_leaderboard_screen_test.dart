import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:wellnex_app/features/teams/data/models/team_model.dart';
import 'package:wellnex_app/features/teams/presentation/screens/team_leaderboard_screen.dart';
import 'package:wellnex_app/services/api_service.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  late MockApiService mockApi;

  Team makeTeam(String id, String name, int weeklySteps, int rank) => Team(
        id: id,
        name: name,
        description: '',
        captainId: 'cap',
        captainName: 'Captain',
        members: const [],
        memberCount: 3,
        totalSteps: weeklySteps * 4,
        weeklySteps: weeklySteps,
        rank: rank,
        createdAt: DateTime.now(),
      );

  setUp(() {
    mockApi = MockApiService();
    registerFallbackValue(RequestOptions(path: ''));
  });

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        apiServiceProvider.overrideWithValue(mockApi),
      ],
      child: const MaterialApp(
        home: TeamLeaderboardScreen(),
      ),
    );
  }

  group('TeamLeaderboardScreen', () {
    testWidgets('shows loading indicator initially', (tester) async {
      // Use Completer so we can control when the future resolves — no pending timers
      final completer = Completer<Response<dynamic>>();

      when(() => mockApi.get('/teams/leaderboard'))
          .thenAnswer((_) => completer.future);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(); // Let the initState microtask run

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Resolve the completer to prevent dangling futures
      completer.complete(Response(
        requestOptions: RequestOptions(path: ''),
        data: [],
        statusCode: 200,
      ));
      await tester.pumpAndSettle();
    });

    testWidgets('shows empty state when leaderboard is empty', (tester) async {
      when(() => mockApi.get('/teams/leaderboard')).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ''),
            data: [],
            statusCode: 200,
          ));

      await tester.pumpWidget(createWidgetUnderTest());
      // Use pump+duration instead of pumpAndSettle to avoid animation timeout
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Leaderboard Empty'), findsOneWidget);
      expect(find.text('Get your team stepping to appear here!'), findsOneWidget);
    });

    testWidgets('renders team names when 3+ teams present', (tester) async {
      final teams = [
        makeTeam('t1', 'Gold Team', 50000, 1),
        makeTeam('t2', 'Silver Team', 40000, 2),
        makeTeam('t3', 'Bronze Team', 30000, 3),
        makeTeam('t4', 'Fourth Team', 20000, 4),
      ];

      when(() => mockApi.get('/teams/leaderboard')).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ''),
            data: teams.map((t) => t.toJson()).toList(),
            statusCode: 200,
          ));

      await tester.pumpWidget(createWidgetUnderTest());
      // Pump twice: once for microtask, once for setState, avoid pumpAndSettle
      // because the shimmer animation on the gold medal repeats forever
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Gold Team'), findsOneWidget);
      expect(find.text('Silver Team'), findsOneWidget);
      expect(find.text('Bronze Team'), findsOneWidget);
    });

    testWidgets('shows error snackbar when fetch fails', (tester) async {
      when(() => mockApi.get('/teams/leaderboard'))
          .thenThrow(Exception('Server Error'));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      // The screen strips the outer 'Exception: ' prefix, leaving the inner message
      expect(
        find.text(
          'Failed to load team leaderboard: Server Error',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
    });
  });
}
