import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:wellnex_app/features/teams/data/models/team_model.dart';
import 'package:wellnex_app/features/teams/presentation/screens/team_detail_screen.dart';
import 'package:wellnex_app/services/api_service.dart';
import 'package:wellnex_app/features/auth/presentation/providers/auth_provider.dart';

class MockApiService extends Mock implements ApiService {}

/// Stub AuthNotifier that sets state directly without calling native services
class FakeAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  FakeAuthNotifier() : super(AuthState(isAuthenticated: true, user: {'id': 'cap1', 'name': 'Bob'}));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockApiService mockApi;

  final now = DateTime.now();

  final testMember = TeamMember(
    id: 'mem1',
    name: 'Alice',
    steps: 8000,
    weeklySteps: 3000,
    isCaptain: false,
    joinedAt: now,
  );

  final captainMember = TeamMember(
    id: 'cap1',
    name: 'Bob (Captain)',
    steps: 15000,
    weeklySteps: 7500,
    isCaptain: true,
    joinedAt: now,
  );

  final testTeam = Team(
    id: 'team1',
    name: 'Alpha Team',
    description: 'The best team',
    captainId: 'cap1',
    captainName: 'Bob',
    members: [captainMember, testMember],
    memberCount: 2,
    maxMembers: 10,
    totalSteps: 23000,
    weeklySteps: 10500,
    inviteCode: 'ALPHA123',
    createdAt: now,
  );

  setUp(() {
    mockApi = MockApiService();
    registerFallbackValue(RequestOptions(path: ''));
  });

  Widget createWidgetUnderTest(String teamId) {
    return ProviderScope(
      overrides: [
        apiServiceProvider.overrideWithValue(mockApi),
        authProvider.overrideWith((_) => FakeAuthNotifier()),
      ],
      child: MaterialApp(
        home: TeamDetailScreen(teamId: teamId),
      ),
    );
  }

  group('TeamDetailScreen', () {
    testWidgets('shows loading indicator while fetching', (tester) async {
      final completer = Completer<Response<dynamic>>();
      when(() => mockApi.get('/teams/team1'))
          .thenAnswer((_) => completer.future);
      when(() => mockApi.get('/teams/team1/challenges')).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: ''),
        data: [],
        statusCode: 200,
      ));

      await tester.pumpWidget(createWidgetUnderTest('team1'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Resolve to clean up
      completer.complete(Response(
        requestOptions: RequestOptions(path: ''),
        data: testTeam.toJson(),
        statusCode: 200,
      ));
      await tester.pumpAndSettle();
    });

    testWidgets('displays team details after loading', (tester) async {
      when(() => mockApi.get('/teams/team1')).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: ''),
        data: testTeam.toJson(),
        statusCode: 200,
      ));
      when(() => mockApi.get('/teams/team1/challenges')).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: ''),
        data: [],
        statusCode: 200,
      ));

      await tester.pumpWidget(createWidgetUnderTest('team1'));
      await tester.pumpAndSettle();

      expect(find.text('Alpha Team'), findsWidgets);
      expect(find.text('Members (2/10)'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob (Captain)'), findsOneWidget);
    });

    testWidgets('displays invite code section when present', (tester) async {
      when(() => mockApi.get('/teams/team1')).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: ''),
        data: testTeam.toJson(),
        statusCode: 200,
      ));
      when(() => mockApi.get('/teams/team1/challenges')).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: ''),
        data: [],
        statusCode: 200,
      ));

      await tester.pumpWidget(createWidgetUnderTest('team1'));
      await tester.pumpAndSettle();

      expect(find.text('Invite Code'), findsOneWidget);
      expect(find.text('ALPHA123'), findsOneWidget);
    });

    testWidgets('shows error snackbar when fetch fails', (tester) async {
      when(() => mockApi.get('/teams/team1')).thenThrow(Exception('Network Error'));
      when(() => mockApi.get('/teams/team1/challenges')).thenThrow(Exception('Network Error'));

      await tester.pumpWidget(createWidgetUnderTest('team1'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text('Exception: Network Error', skipOffstage: false),
        findsOneWidget,
      );
    });
  });
}
