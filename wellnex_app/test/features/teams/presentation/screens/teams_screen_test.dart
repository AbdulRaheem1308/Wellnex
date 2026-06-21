import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:wellnex_app/features/teams/data/models/team_model.dart';
import 'package:wellnex_app/features/teams/presentation/screens/teams_screen.dart';
import 'package:wellnex_app/services/api_service.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  late MockApiService mockApi;

  final testTeam = Team(
    id: 'team1',
    name: 'Alpha Team',
    description: 'The best team',
    captainId: 'cap1',
    captainName: 'Captain America',
    members: [],
    memberCount: 2,
    maxMembers: 10,
    totalSteps: 10000,
    weeklySteps: 5000,
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
        home: TeamsScreen(),
      ),
    );
  }

  group('TeamsScreen', () {
    testWidgets('displays loading state initially', (tester) async {
      final myTeamsCompleter = Completer<Response<dynamic>>();
      final publicTeamsCompleter = Completer<Response<dynamic>>();

      when(() => mockApi.get('/teams/my-teams'))
          .thenAnswer((_) => myTeamsCompleter.future);
      when(() => mockApi.get('/teams/public'))
          .thenAnswer((_) => publicTeamsCompleter.future);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(); // Allow microtask to fire

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Resolve completers to clean up
      final emptyResp = Response<dynamic>(
        requestOptions: RequestOptions(path: ''),
        data: [],
        statusCode: 200,
      );
      myTeamsCompleter.complete(emptyResp);
      publicTeamsCompleter.complete(emptyResp);
      await tester.pumpAndSettle();
    });

    testWidgets('displays empty state when no teams', (tester) async {
      when(() => mockApi.get('/teams/my-teams')).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: ''),
        data: [],
        statusCode: 200,
      ));
      when(() => mockApi.get('/teams/public')).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: ''),
        data: [],
        statusCode: 200,
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('No Teams Yet'), findsOneWidget);
    });

    testWidgets('displays teams list when loaded', (tester) async {
      when(() => mockApi.get('/teams/my-teams')).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: ''),
        data: [testTeam.toJson()],
        statusCode: 200,
      ));
      when(() => mockApi.get('/teams/public')).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: ''),
        data: [],
        statusCode: 200,
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Alpha Team'), findsOneWidget);
      expect(find.text('2/10 members'), findsOneWidget);
    });

    testWidgets('shows error snackbar on fetch failure', (tester) async {
      when(() => mockApi.get('/teams/my-teams')).thenThrow(Exception('Network Error'));
      when(() => mockApi.get('/teams/public')).thenThrow(Exception('Network Error'));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(const Duration(milliseconds: 100)); // allow microtask
      await tester.pump(const Duration(milliseconds: 500)); // allow snackbar slide in

      expect(find.text('Exception: Network Error', skipOffstage: false), findsOneWidget);
    });

    testWidgets('opens create team dialog', (tester) async {
      tester.view.physicalSize = const Size(1440, 2560);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      when(() => mockApi.get('/teams/my-teams')).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: ''),
        data: [],
        statusCode: 200,
      ));
      when(() => mockApi.get('/teams/public')).thenAnswer((_) async => Response(
        requestOptions: RequestOptions(path: ''),
        data: [],
        statusCode: 200,
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Create Team'), findsWidgets); // Title and Button
      expect(find.byType(TextField), findsNWidgets(2)); // Name and Desc
    });
  });
}
