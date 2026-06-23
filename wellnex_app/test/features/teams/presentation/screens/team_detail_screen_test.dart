import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';

import 'package:wellnex_app/features/teams/presentation/screens/team_detail_screen.dart';
import 'package:wellnex_app/features/teams/presentation/providers/teams_provider.dart';
import 'package:wellnex_app/features/teams/data/models/team_model.dart';
import 'package:wellnex_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:wellnex_app/services/api_service.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'dart:io';
import 'dart:async';

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _FakeHttpClient();
  }
}

class _FakeHttpClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpClientRequest();
}

class _FakeHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse();
}

class _FakeHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  int get contentLength => _transparentImage.length;
  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.value(_transparentImage).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}

final List<int> _transparentImage = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

class FakeSharePlatform extends Fake with MockPlatformInterfaceMixin implements SharePlatform {
  String? sharedText;
  
  @override
  Future<ShareResult> share(
    String text, {
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    sharedText = text;
    return const ShareResult('success', ShareResultStatus.success);
  }
}

class MockApiService extends Mock implements ApiService {}

class MockAuthNotifier extends StateNotifier<AuthState> with Mock implements AuthNotifier {
  MockAuthNotifier() : super(AuthState(user: {'id': 'user-123'}));
}

class FakeTeamsNotifier extends StateNotifier<TeamsState> implements TeamsNotifier {
  FakeTeamsNotifier([TeamsState? state]) : super(state ?? TeamsState());
  
  @override Future<void> fetchTeamDetails(String teamId) async {}
  @override Future<Team?> createTeam({required String name, required String description, int? maxMembers, bool isPublic = false}) async => null;
  @override Future<void> fetchTeams() async {}
  @override Future<void> fetchMyTeams() async {}
  @override Future<void> fetchPublicTeams() async {}
  @override Future<List<Team>> fetchTeamLeaderboard() async => [];
  @override Future<void> fetchTeamChallenges(String teamId) async {}
  @override Future<bool> joinTeam(String teamId, {String? inviteCode}) async => true;
  @override Future<bool> leaveTeam(String teamId) async => true;
  @override Future<bool> deleteTeam(String teamId) async => true;
  @override void clearError() {}
  @override void clearCurrentTeam() {}
}

void main() {
  late MockApiService mockApiService;
  late MockAuthNotifier mockAuthNotifier;

  final testTeam = Team(
    id: 'team-1',
    name: 'Awesome Team',
    description: 'We are awesome',
    captainId: 'user-123',
    captainName: 'Test Captain',
    members: [
      TeamMember(
        id: 'user-123',
        name: 'Test Captain',
        steps: 10000,
        weeklySteps: 5000,
        isCaptain: true,
        joinedAt: DateTime(2023),
      ),
      TeamMember(
        id: 'user-456',
        name: 'Another Member',
        steps: 800,
        weeklySteps: 400,
        isCaptain: false,
        joinedAt: DateTime(2023),
      ),
    ],
    memberCount: 2,
    maxMembers: 10,
    totalSteps: 18000,
    weeklySteps: 9000,
    rank: 1,
    inviteCode: 'INVITE123',
    createdAt: DateTime(2023),
  );

  final testChallenge = TeamChallenge(
    id: 'challenge-1',
    title: 'Walk 1M Steps',
    description: 'Walk together',
    teamId: 'team-1',
    targetSteps: 1000000,
    currentSteps: 18000,
    startDate: DateTime(2023),
    endDate: DateTime(2024),
    status: 'active',
    rewardCoins: 100,
    rewardXp: 500,
  );

  late FakeSharePlatform fakeSharePlatform;

  setUp(() {
    mockApiService = MockApiService();
    mockAuthNotifier = MockAuthNotifier();
    fakeSharePlatform = FakeSharePlatform();
    SharePlatform.instance = fakeSharePlatform;
    HttpOverrides.global = _FakeHttpOverrides();
    
    // Register fallbacks
    registerFallbackValue(RequestOptions(path: ''));
  });

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => mockAuthNotifier),
        apiServiceProvider.overrideWithValue(mockApiService),
      ],
      child: const MaterialApp(
        home: TeamDetailScreen(teamId: 'team-1'),
      ),
    );
  }

  // Removed flaky loading test

  testWidgets('renders loading state when team is null and loading', (tester) async {
    // We override teamsProvider to force isLoading = true and currentTeam = null
    final loadingNotifier = FakeTeamsNotifier(TeamsState(isLoading: true, currentTeam: null));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => mockAuthNotifier),
        apiServiceProvider.overrideWithValue(mockApiService),
        teamsProvider.overrideWith((ref) => loadingNotifier),
      ],
      child: const MaterialApp(
        home: TeamDetailScreen(teamId: 'team-1'),
      ),
    ));
    
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders team not found if null', (tester) async {
    when(() => mockApiService.get('/teams/team-1'))
        .thenThrow(Exception('Not found'));
    when(() => mockApiService.get('/teams/team-1/challenges'))
        .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: [], statusCode: 200));

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Team not found'), findsOneWidget);
  });

  testWidgets('renders team details, members, challenges and stats', (tester) async {
    when(() => mockApiService.get('/teams/team-1'))
        .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: testTeam.toJson(), statusCode: 200));
    when(() => mockApiService.get('/teams/team-1/challenges'))
        .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: [testChallenge.toJson()], statusCode: 200));

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Awesome Team'), findsOneWidget);
    expect(find.text('Members (2/10)'), findsOneWidget);
    expect(find.text('Team Challenges'), findsOneWidget);
    
    // Stats
    expect(find.text('18.0K'), findsOneWidget); // Total steps
    expect(find.text('9.0K'), findsOneWidget); // Weekly steps
    expect(find.text('#1'), findsOneWidget); // Rank
    
    // Members
    expect(find.text('Test Captain'), findsOneWidget);
    expect(find.text('Another Member'), findsOneWidget);
    
    // Challenge might be off-screen
    await tester.dragUntilVisible(
      find.text('Walk 1M Steps'), 
      find.byType(CustomScrollView), 
      const Offset(0, -500)
    );
    await tester.pumpAndSettle();
    
    expect(find.text('Walk 1M Steps'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
    
    // Invite code might be further down
    await tester.dragUntilVisible(
      find.text('Invite Code'), 
      find.byType(CustomScrollView), 
      const Offset(0, -500)
    );
    await tester.pumpAndSettle();
    expect(find.text('Invite Code'), findsOneWidget);
    expect(find.text('INVITE123'), findsOneWidget);
  });

  testWidgets('copy invite code works', (tester) async {
    when(() => mockApiService.get('/teams/team-1'))
        .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: testTeam.toJson(), statusCode: 200));
    when(() => mockApiService.get('/teams/team-1/challenges'))
        .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: [], statusCode: 200));

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Tap copy icon
    await tester.dragUntilVisible(find.byIcon(Icons.copy), find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    
    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump();

    // Verify snackbar
    expect(find.text('Invite code copied!'), findsOneWidget);
  });

  testWidgets('captain can delete team', (tester) async {
    when(() => mockApiService.get('/teams/team-1'))
        .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: testTeam.toJson(), statusCode: 200));
    when(() => mockApiService.get('/teams/team-1/challenges'))
        .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: [], statusCode: 200));
    when(() => mockApiService.delete('/teams/team-1'))
        .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: {}, statusCode: 200));

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Open popup menu
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    // Verify delete option is available for captain
    expect(find.text('Delete Team'), findsOneWidget);
    
    // Tap delete
    await tester.tap(find.text('Delete Team'));
    await tester.pumpAndSettle();

    // Dialog appears
    expect(find.text('Delete Team?'), findsOneWidget);
    
    // Confirm delete
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    verify(() => mockApiService.delete('/teams/team-1')).called(1);
    // Snackbar verification requires checking for it (though it navigates pop so it might be tricky)
  });

  testWidgets('non-captain can leave team', (tester) async {
    // Current user is user-456 (not captain)
    final nonCaptainAuthNotifier = MockAuthNotifier();
    nonCaptainAuthNotifier.state = AuthState(user: {'id': 'user-456'});

    when(() => mockApiService.get('/teams/team-1'))
        .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: testTeam.toJson(), statusCode: 200));
    when(() => mockApiService.get('/teams/team-1/challenges'))
        .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: [], statusCode: 200));
    when(() => mockApiService.post('/teams/team-1/leave'))
        .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: {}, statusCode: 200));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => nonCaptainAuthNotifier),
        apiServiceProvider.overrideWithValue(mockApiService),
      ],
      child: const MaterialApp(
        home: TeamDetailScreen(teamId: 'team-1'),
      ),
    ));
    await tester.pumpAndSettle();

    // Open popup menu
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    // Verify leave option is available
    expect(find.text('Leave Team'), findsOneWidget);
    expect(find.text('Delete Team'), findsNothing);
    
    // Tap leave
    await tester.tap(find.text('Leave Team'));
    await tester.pumpAndSettle();

    // Dialog appears
    expect(find.text('Leave Team?'), findsOneWidget);
    
    // Confirm leave
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();

    verify(() => mockApiService.post('/teams/team-1/leave')).called(1);
  });

  testWidgets('captain can share invite code', (tester) async {
    when(() => mockApiService.get('/teams/team-1'))
        .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: testTeam.toJson(), statusCode: 200));
    when(() => mockApiService.get('/teams/team-1/challenges'))
        .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: [], statusCode: 200));

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Share Team'));
    await tester.pumpAndSettle();

    expect(fakeSharePlatform.sharedText, contains('INVITE123'));
  });

  testWidgets('captain can cancel delete team', (tester) async {
    when(() => mockApiService.get('/teams/team-1'))
        .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: testTeam.toJson(), statusCode: 200));
    when(() => mockApiService.get('/teams/team-1/challenges'))
        .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: [], statusCode: 200));

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete Team'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Team?'), findsNothing);
  });

  testWidgets('failed to delete team shows error', (tester) async {
    when(() => mockApiService.get('/teams/team-1'))
        .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: testTeam.toJson(), statusCode: 200));
    when(() => mockApiService.get('/teams/team-1/challenges'))
        .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: [], statusCode: 200));
    when(() => mockApiService.delete('/teams/team-1'))
        .thenThrow(Exception('Delete failed'));

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete Team'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Exception: Delete failed'), findsOneWidget);
  });

  testWidgets('non-captain can cancel leave team', (tester) async {
    final nonCaptainAuthNotifier = MockAuthNotifier();
    nonCaptainAuthNotifier.state = AuthState(user: {'id': 'user-456'});

    when(() => mockApiService.get('/teams/team-1'))
        .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: testTeam.toJson(), statusCode: 200));
    when(() => mockApiService.get('/teams/team-1/challenges'))
        .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: [], statusCode: 200));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => nonCaptainAuthNotifier),
        apiServiceProvider.overrideWithValue(mockApiService),
      ],
      child: const MaterialApp(
        home: TeamDetailScreen(teamId: 'team-1'),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    
    await tester.tap(find.text('Leave Team'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Leave Team?'), findsNothing);
  });
}
