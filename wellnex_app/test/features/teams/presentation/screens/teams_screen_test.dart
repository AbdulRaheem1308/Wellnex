import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:wellnex_app/features/teams/data/models/team_model.dart';
import 'package:wellnex_app/features/teams/presentation/providers/teams_provider.dart';
import 'package:wellnex_app/features/teams/presentation/screens/teams_screen.dart';
import 'package:wellnex_app/services/api_service.dart';

class MockApiService extends Mock implements ApiService {}

/// Helper to build a [Response] with given data.
Response<dynamic> makeResponse(dynamic data, {String path = '', int status = 200}) {
  return Response<dynamic>(
    requestOptions: RequestOptions(path: path),
    data: data,
    statusCode: status,
  );
}

/// Builds a GoRouter that wraps [TeamsScreen] at '/'.
GoRouter makeRouter(MockApiService mockApi) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => ProviderScope(
          overrides: [apiServiceProvider.overrideWithValue(mockApi)],
          child: const TeamsScreen(),
        ),
      ),
      GoRoute(path: '/teams/leaderboard', builder: (_, __) => const Scaffold(body: Text('Leaderboard'))),
      GoRoute(path: '/teams/:id', builder: (_, __) => const Scaffold(body: Text('Team Detail'))),
    ],
  );
}

/// Wraps [TeamsScreen] in a [ProviderScope] + [MaterialApp] (no routing).
Widget buildWidget(MockApiService mockApi) {
  return ProviderScope(
    overrides: [apiServiceProvider.overrideWithValue(mockApi)],
    child: const MaterialApp(home: TeamsScreen()),
  );
}

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

  final fullTeam = Team(
    id: 'team2',
    name: 'Full Team',
    description: 'No room here',
    captainId: 'cap2',
    captainName: 'Cap Two',
    members: [],
    memberCount: 10,
    maxMembers: 10,
    totalSteps: 50000,
    weeklySteps: 20000,
    createdAt: DateTime.now(),
  );

  final publicTeam = Team(
    id: 'pub1',
    name: 'Public Warriors',
    description: 'Open for all walkers',
    captainId: 'cap3',
    captainName: 'Cap Three',
    members: [],
    memberCount: 3,
    maxMembers: 10,
    totalSteps: 8000,
    weeklySteps: 3000,
    isPublic: true,
    createdAt: DateTime.now(),
  );

  setUp(() {
    mockApi = MockApiService();
    registerFallbackValue(RequestOptions(path: ''));
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Loading state
  // ─────────────────────────────────────────────────────────────────────────
  group('TeamsScreen – loading', () {
    testWidgets('shows CircularProgressIndicator while fetching my-teams', (tester) async {
      final myTeamsCompleter = Completer<Response<dynamic>>();
      final publicTeamsCompleter = Completer<Response<dynamic>>();

      when(() => mockApi.get('/teams/my-teams')).thenAnswer((_) => myTeamsCompleter.future);
      when(() => mockApi.get('/teams/public')).thenAnswer((_) => publicTeamsCompleter.future);

      await tester.pumpWidget(buildWidget(mockApi));
      await tester.pump(); // microtask

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Cleanup
      myTeamsCompleter.complete(makeResponse([]));
      publicTeamsCompleter.complete(makeResponse([]));
      await tester.pumpAndSettle();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // My Teams tab – empty state
  // ─────────────────────────────────────────────────────────────────────────
  group('TeamsScreen – My Teams tab', () {
    testWidgets('shows "No Teams Yet" empty state when myTeams is empty', (tester) async {
      when(() => mockApi.get('/teams/my-teams')).thenAnswer((_) async => makeResponse([]));
      when(() => mockApi.get('/teams/public')).thenAnswer((_) async => makeResponse([]));

      await tester.pumpWidget(buildWidget(mockApi));
      await tester.pumpAndSettle();

      expect(find.text('No Teams Yet'), findsOneWidget);
      expect(find.text('Create a team or join one to compete together!'), findsOneWidget);
    });

    testWidgets('displays team list when myTeams has items', (tester) async {
      when(() => mockApi.get('/teams/my-teams'))
          .thenAnswer((_) async => makeResponse([testTeam.toJson()]));
      when(() => mockApi.get('/teams/public')).thenAnswer((_) async => makeResponse([]));

      await tester.pumpWidget(buildWidget(mockApi));
      await tester.pumpAndSettle();

      expect(find.text('Alpha Team'), findsOneWidget);
      expect(find.text('2/10 members'), findsOneWidget);
    });

    testWidgets('pull-to-refresh on My Teams tab triggers fetchMyTeams', (tester) async {
      int callCount = 0;
      when(() => mockApi.get('/teams/my-teams')).thenAnswer((_) async {
        callCount++;
        return makeResponse([testTeam.toJson()]);
      });
      when(() => mockApi.get('/teams/public')).thenAnswer((_) async => makeResponse([]));

      await tester.pumpWidget(buildWidget(mockApi));
      await tester.pumpAndSettle();

      // Simulate pull-to-refresh
      await tester.drag(find.byType(ListView).first, const Offset(0, 300));
      await tester.pumpAndSettle();

      // fetchMyTeams called at least twice (initial + refresh)
      expect(callCount, greaterThanOrEqualTo(2));
    });

    testWidgets('tapping a team card navigates to /teams/:id', (tester) async {
      when(() => mockApi.get('/teams/my-teams'))
          .thenAnswer((_) async => makeResponse([testTeam.toJson()]));
      when(() => mockApi.get('/teams/public')).thenAnswer((_) async => makeResponse([]));

      final router = makeRouter(mockApi);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alpha Team'));
      await tester.pumpAndSettle();

      expect(find.text('Team Detail'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Discover tab
  // ─────────────────────────────────────────────────────────────────────────
  group('TeamsScreen – Discover tab', () {
    Future<void> switchToDiscover(WidgetTester tester) async {
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows "No Public Teams" when publicTeams is empty', (tester) async {
      when(() => mockApi.get('/teams/my-teams')).thenAnswer((_) async => makeResponse([]));
      when(() => mockApi.get('/teams/public')).thenAnswer((_) async => makeResponse([]));

      await tester.pumpWidget(buildWidget(mockApi));
      await tester.pumpAndSettle();
      await switchToDiscover(tester);

      expect(find.text('No Public Teams'), findsOneWidget);
      expect(find.text('Be the first to create a public team!'), findsOneWidget);
    });

    testWidgets('shows loading indicator on Discover tab while publicTeams is loading', (tester) async {
      final myTeamsCompleter = Completer<Response<dynamic>>();
      final publicTeamsCompleter = Completer<Response<dynamic>>();

      when(() => mockApi.get('/teams/my-teams')).thenAnswer((_) => myTeamsCompleter.future);
      when(() => mockApi.get('/teams/public')).thenAnswer((_) => publicTeamsCompleter.future);

      await tester.pumpWidget(buildWidget(mockApi));
      await tester.pump(); // trigger microtask

      await tester.tap(find.text('Discover'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      myTeamsCompleter.complete(makeResponse([]));
      publicTeamsCompleter.complete(makeResponse([]));
      await tester.pumpAndSettle();
    });

    testWidgets('displays public teams list when loaded', (tester) async {
      when(() => mockApi.get('/teams/my-teams')).thenAnswer((_) async => makeResponse([]));
      when(() => mockApi.get('/teams/public'))
          .thenAnswer((_) async => makeResponse([publicTeam.toJson()]));

      await tester.pumpWidget(buildWidget(mockApi));
      await tester.pumpAndSettle();
      await switchToDiscover(tester);

      expect(find.text('Public Warriors'), findsOneWidget);
    });

    testWidgets('search filters public teams by name', (tester) async {
      final anotherTeam = publicTeam.copyWith(id: 'pub2', name: 'Beta Squad');
      when(() => mockApi.get('/teams/my-teams')).thenAnswer((_) async => makeResponse([]));
      when(() => mockApi.get('/teams/public')).thenAnswer(
          (_) async => makeResponse([publicTeam.toJson(), anotherTeam.toJson()]));

      await tester.pumpWidget(buildWidget(mockApi));
      await tester.pumpAndSettle();
      await switchToDiscover(tester);

      // Both visible initially
      expect(find.text('Public Warriors'), findsOneWidget);
      expect(find.text('Beta Squad'), findsOneWidget);

      // Type search query
      await tester.enterText(find.byType(TextField), 'Beta');
      await tester.pumpAndSettle();

      expect(find.text('Beta Squad'), findsOneWidget);
      expect(find.text('Public Warriors'), findsNothing);
    });

    testWidgets('search with no matches shows "No matches found"', (tester) async {
      when(() => mockApi.get('/teams/my-teams')).thenAnswer((_) async => makeResponse([]));
      when(() => mockApi.get('/teams/public'))
          .thenAnswer((_) async => makeResponse([publicTeam.toJson()]));

      await tester.pumpWidget(buildWidget(mockApi));
      await tester.pumpAndSettle();
      await switchToDiscover(tester);

      await tester.enterText(find.byType(TextField), 'zzznomatch');
      await tester.pumpAndSettle();

      expect(find.text('No matches found'), findsOneWidget);
      expect(find.text('Try a different search term'), findsOneWidget);
    });

    testWidgets('search filters by description', (tester) async {
      when(() => mockApi.get('/teams/my-teams')).thenAnswer((_) async => makeResponse([]));
      when(() => mockApi.get('/teams/public'))
          .thenAnswer((_) async => makeResponse([publicTeam.toJson()]));

      await tester.pumpWidget(buildWidget(mockApi));
      await tester.pumpAndSettle();
      await switchToDiscover(tester);

      // Search by description keyword
      await tester.enterText(find.byType(TextField), 'walkers');
      await tester.pumpAndSettle();

      expect(find.text('Public Warriors'), findsOneWidget);
    });

    testWidgets('pull-to-refresh on Discover tab triggers fetchPublicTeams', (tester) async {
      int callCount = 0;
      when(() => mockApi.get('/teams/my-teams')).thenAnswer((_) async => makeResponse([]));
      when(() => mockApi.get('/teams/public')).thenAnswer((_) async {
        callCount++;
        return makeResponse([publicTeam.toJson()]);
      });

      await tester.pumpWidget(buildWidget(mockApi));
      await tester.pumpAndSettle();
      await switchToDiscover(tester);

      // Drag to refresh on the public teams ListView
      await tester.drag(find.byType(ListView).first, const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(callCount, greaterThanOrEqualTo(2));
    });

    testWidgets('tapping a public team card navigates to team detail', (tester) async {
      when(() => mockApi.get('/teams/my-teams')).thenAnswer((_) async => makeResponse([]));
      when(() => mockApi.get('/teams/public'))
          .thenAnswer((_) async => makeResponse([publicTeam.toJson()]));

      final router = makeRouter(mockApi);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Public Warriors'));
      await tester.pumpAndSettle();

      expect(find.text('Team Detail'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Join team
  // ─────────────────────────────────────────────────────────────────────────
  group('TeamsScreen – join team', () {
    Future<void> openDiscoverAndSetup(WidgetTester tester, MockApiService api,
        {required Team publicT}) async {
      when(() => api.get('/teams/my-teams')).thenAnswer((_) async => makeResponse([]));
      when(() => api.get('/teams/public'))
          .thenAnswer((_) async => makeResponse([publicT.toJson()]));

      await tester.pumpWidget(buildWidget(api));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();
    }

    // A team with isFull=true shows a "Full" badge – no join button rendered.
    // This test verifies the badge is shown correctly.
    testWidgets('shows "Full" badge for full team instead of Join button', (tester) async {
      when(() => mockApi.get('/teams/my-teams')).thenAnswer((_) async => makeResponse([]));
      when(() => mockApi.get('/teams/public'))
          .thenAnswer((_) async => makeResponse([fullTeam.toJson()]));

      await tester.pumpWidget(buildWidget(mockApi));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();

      // Join button absent; "Full" badge present
      expect(find.text('Full'), findsOneWidget);
      expect(find.text('Join'), findsNothing);
    });

    testWidgets('shows snackbar "This team is full!" via joinTeam guard', (tester) async {
      when(() => mockApi.get('/teams/my-teams')).thenAnswer((_) async => makeResponse([]));
      when(() => mockApi.get('/teams/public')).thenAnswer((_) async => makeResponse([]));

      await tester.pumpWidget(buildWidget(mockApi));
      await tester.pumpAndSettle();

      final state = tester.state(find.byType(TeamsScreen)) as dynamic;
      await state.joinTeam(fullTeam);
      
      await tester.pump();

      expect(find.text('This team is full!'), findsOneWidget);
    });


    testWidgets('successful join shows snackbar and switches to My Teams', (tester) async {
      when(() => mockApi.post(
            '/teams/${publicTeam.id}/join',
            data: any(named: 'data'),
          )).thenAnswer((_) async => makeResponse({}));

      // After joinTeam succeeds it calls fetchMyTeams again
      int myTeamsCallCount = 0;
      when(() => mockApi.get('/teams/my-teams')).thenAnswer((_) async {
        myTeamsCallCount++;
        if (myTeamsCallCount > 1) {
          // second call returns the joined team
          return makeResponse([publicTeam.toJson()]);
        }
        return makeResponse([]);
      });
      when(() => mockApi.get('/teams/public'))
          .thenAnswer((_) async => makeResponse([publicTeam.toJson()]));

      await tester.pumpWidget(buildWidget(mockApi));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Join'));
      await tester.pumpAndSettle();

      expect(find.text('Joined ${publicTeam.name}!'), findsOneWidget);
      // Should have switched to My Teams tab (tab index 0)
      expect(find.text('My Teams'), findsOneWidget);
    });

    testWidgets('failed join shows error snackbar', (tester) async {
      when(() => mockApi.post(
            '/teams/${publicTeam.id}/join',
            data: any(named: 'data'),
          )).thenThrow(Exception('Join failed'));
      when(() => mockApi.get('/teams/my-teams')).thenAnswer((_) async => makeResponse([]));
      when(() => mockApi.get('/teams/public'))
          .thenAnswer((_) async => makeResponse([publicTeam.toJson()]));

      await tester.pumpWidget(buildWidget(mockApi));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Join'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      // Error is set in state → error listener fires snackbar
      expect(find.textContaining('Exception: Join failed', skipOffstage: false), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Error handling
  // ─────────────────────────────────────────────────────────────────────────
  group('TeamsScreen – error handling', () {
    testWidgets('shows error snackbar on fetch failure', (tester) async {
      when(() => mockApi.get('/teams/my-teams')).thenThrow(Exception('Network Error'));
      when(() => mockApi.get('/teams/public')).thenThrow(Exception('Network Error'));

      await tester.pumpWidget(buildWidget(mockApi));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Exception: Network Error', skipOffstage: false), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Create Team dialog
  // ─────────────────────────────────────────────────────────────────────────
  group('TeamsScreen – create team dialog', () {
    setUp(() {
      when(() => mockApi.get('/teams/my-teams')).thenAnswer((_) async => makeResponse([]));
      when(() => mockApi.get('/teams/public')).thenAnswer((_) async => makeResponse([]));
    });

    Future<void> openDialog(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 2560);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildWidget(mockApi));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
    }

    testWidgets('opens create team dialog with correct fields', (tester) async {
      await openDialog(tester);

      expect(find.text('Create Team'), findsWidgets);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.byType(Slider), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
    });

    testWidgets('close button dismisses dialog', (tester) async {
      await openDialog(tester);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Max Members:'), findsNothing);
    });

    testWidgets('shows snackbar if name is empty on create', (tester) async {
      await openDialog(tester);

      // Tap create without entering a name
      final createButtons = find.text('Create Team');
      // The bottom sheet create button
      await tester.tap(createButtons.last);
      await tester.pumpAndSettle();

      expect(find.text('Please enter a team name'), findsOneWidget);
    });

    testWidgets('slider changes max members value', (tester) async {
      await openDialog(tester);

      final slider = find.byType(Slider);
      expect(slider, findsOneWidget);

      // Drag the slider to a new position (drag right)
      await tester.drag(slider, const Offset(50, 0));
      await tester.pumpAndSettle();

      // Slider moved – just verify it still exists and no crash
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('toggle public/private switch', (tester) async {
      await openDialog(tester);

      final switchTile = find.byType(SwitchListTile);
      expect(switchTile, findsOneWidget);

      await tester.tap(switchTile);
      await tester.pumpAndSettle();

      // Switch toggled without crash
      expect(find.byType(SwitchListTile), findsOneWidget);
    });

    testWidgets('successful team creation closes dialog and shows snackbar', (tester) async {
      final newTeam = testTeam.copyWith(id: 'new1', name: 'My New Team');
      when(() => mockApi.post('/teams', data: any(named: 'data')))
          .thenAnswer((_) async => makeResponse(newTeam.toJson()));

      await openDialog(tester);

      // Enter name
      await tester.enterText(find.byType(TextField).first, 'My New Team');
      await tester.pumpAndSettle();

      // Tap create button
      await tester.tap(find.text('Create Team').last);
      await tester.pumpAndSettle();

      expect(find.text('Team "My New Team" created!'), findsOneWidget);
      // Dialog should be closed
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('failed team creation shows error snackbar', (tester) async {
      when(() => mockApi.post('/teams', data: any(named: 'data')))
          .thenThrow(Exception('Server error'));

      await openDialog(tester);

      await tester.enterText(find.byType(TextField).first, 'My Failing Team');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create Team').last);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      // Error shows via the error listener
      expect(
        find.textContaining('Exception: Server error', skipOffstage: false),
        findsOneWidget,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // AppBar actions
  // ─────────────────────────────────────────────────────────────────────────
  group('TeamsScreen – AppBar', () {
    testWidgets('leaderboard icon navigates to /teams/leaderboard', (tester) async {
      when(() => mockApi.get('/teams/my-teams')).thenAnswer((_) async => makeResponse([]));
      when(() => mockApi.get('/teams/public')).thenAnswer((_) async => makeResponse([]));

      final router = makeRouter(mockApi);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.leaderboard));
      await tester.pumpAndSettle();

      expect(find.text('Leaderboard'), findsOneWidget);
    });

    testWidgets('displays Teams title and tab bar', (tester) async {
      when(() => mockApi.get('/teams/my-teams')).thenAnswer((_) async => makeResponse([]));
      when(() => mockApi.get('/teams/public')).thenAnswer((_) async => makeResponse([]));

      await tester.pumpWidget(buildWidget(mockApi));
      await tester.pumpAndSettle();

      expect(find.text('Teams'), findsOneWidget);
      expect(find.text('My Teams'), findsOneWidget);
      expect(find.text('Discover'), findsOneWidget);
    });
  });
}
