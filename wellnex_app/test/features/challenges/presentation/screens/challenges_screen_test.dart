import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wellnex_app/features/challenges/presentation/screens/challenges_screen.dart';
import 'package:wellnex_app/features/challenges/presentation/providers/challenges_provider.dart';
import 'package:wellnex_app/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

class MockChallengesNotifier extends StateNotifier<ChallengesState> with Mock implements ChallengesNotifier {
  MockChallengesNotifier(super.state);
}

void main() {
  late MockChallengesNotifier mockNotifier;

  setUp(() {
    mockNotifier = MockChallengesNotifier(ChallengesState());
    when(() => mockNotifier.fetchAllChallenges()).thenAnswer((_) => Future.value());
  });

  Widget createWidgetUnderTest() {
    final router = GoRouter(
      initialLocation: '/challenges',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const Scaffold(body: Text('Home'))),
        GoRoute(path: '/challenges', builder: (context, state) => const ChallengesScreen()),
      ],
    );

    return ProviderScope(
      overrides: [
        challengesProvider.overrideWith((ref) => mockNotifier),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }

  final challenge1 = Challenge(
    id: 'c1', title: 'Morning Walk', description: 'Walk 1000 steps',
    stepTarget: 1000, rewardCoins: 10, rewardXp: 50, durationDays: 1,
    challengeType: 'SOLO', difficulty: 'EASY',
  );
  
  final challenge2 = Challenge(
    id: 'c2', title: 'Marathon prep', description: 'Walk 10000 steps',
    stepTarget: 10000, rewardCoins: 100, rewardXp: 500, durationDays: 7,
    challengeType: 'SOLO', difficulty: 'HARD',
  );

  final userChallenge1 = UserChallenge(
    id: 'uc1', status: 'ONGOING', currentSteps: 500, progress: 50,
    joinedAt: DateTime.now(), challenge: challenge1,
  );

  testWidgets('renders loading state correctly', (WidgetTester tester) async {
    mockNotifier.state = ChallengesState(isLoading: true);
    await tester.pumpWidget(createWidgetUnderTest());
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('renders error state correctly and can retry', (WidgetTester tester) async {
    mockNotifier.state = ChallengesState(error: 'Network Error');
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Network Error'), findsWidgets);
    expect(find.text('Retry'), findsWidgets);

    await tester.tap(find.text('Retry').first);
    verify(() => mockNotifier.fetchAllChallenges()).called(greaterThan(0));
  });

  testWidgets('renders challenges and tabs correctly', (WidgetTester tester) async {
    mockNotifier.state = ChallengesState(
      newChallenges: [challenge1, challenge2],
      ongoingChallenges: [userChallenge1],
      completedChallenges: [],
    );

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Morning Walk'), findsOneWidget);
    expect(find.text('Marathon prep'), findsOneWidget);

    await tester.tap(find.text('Ongoing (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Morning Walk'), findsOneWidget);
    
    await tester.tap(find.text('Completed (0)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No completed challenges'), findsOneWidget);
  });

  testWidgets('filters challenges by search query', (WidgetTester tester) async {
    mockNotifier.state = ChallengesState(
      newChallenges: [challenge1, challenge2],
      ongoingChallenges: [userChallenge1],
    );

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Marathon');
    await tester.pumpAndSettle();

    expect(find.text('Marathon prep'), findsOneWidget);
    expect(find.text('Morning Walk'), findsNothing);
    
    // Test that ongoing is also filtered
    await tester.tap(find.text('Ongoing (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Morning Walk'), findsNothing); // Filtered out
    
    await tester.tap(find.text('New (2)'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    
    expect(find.text('Marathon prep'), findsOneWidget);
    expect(find.text('Morning Walk'), findsOneWidget);
  });

  testWidgets('filters challenges by bottom sheet options', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    when(() => mockNotifier.fetchAllChallenges()).thenAnswer((_) => Future.value());
    mockNotifier.state = ChallengesState(
      newChallenges: [challenge1, challenge2],
    );

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'hard'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Marathon prep'), findsOneWidget);
    expect(find.text('Morning Walk'), findsNothing);
    
    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    
    expect(find.text('Morning Walk'), findsOneWidget);
  });

  testWidgets('joins a challenge via bottom sheet', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    when(() => mockNotifier.joinChallenge('c1')).thenAnswer((_) => Future.value(true));
    
    mockNotifier.state = ChallengesState(
      newChallenges: [challenge1],
    );

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Join Challenge'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Join Now!'));
    await tester.pumpAndSettle();

    verify(() => mockNotifier.joinChallenge('c1')).called(1);
  });

  testWidgets('cancels joining a challenge via bottom sheet', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    mockNotifier.state = ChallengesState(
      newChallenges: [challenge1],
    );

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Join Challenge'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => mockNotifier.joinChallenge(any()));
  });
  
  testWidgets('shows terms and conditions when tapped', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    mockNotifier.state = ChallengesState(
      newChallenges: [challenge1],
    );

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Join Challenge'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Terms & Conditions'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Complete the required steps'), findsOneWidget);
  });
  
}
