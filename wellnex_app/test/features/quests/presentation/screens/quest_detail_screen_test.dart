import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wellnex_app/features/quests/domain/models/quest_model.dart';
import 'package:wellnex_app/features/quests/presentation/providers/quests_provider.dart';
import 'package:wellnex_app/features/quests/presentation/screens/quest_detail_screen.dart';

class MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return MockHttpClient();
  }
}

class MockHttpClient extends Mock implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return MockHttpClientRequest();
  }
  
  @override
  set badCertificateCallback(bool Function(X509Certificate cert, String host, int port)? callback) {}
}

class MockHttpClientRequest extends Mock implements HttpClientRequest {
  @override
  HttpHeaders get headers => MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async {
    return MockHttpClientResponse();
  }
}

class MockHttpHeaders extends Mock implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class MockHttpClientResponse extends Mock implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  int get contentLength => 0;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final stream = Stream<List<int>>.empty();
    return stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

void main() {
  late Quest mockQuest;

  setUpAll(() {
    HttpOverrides.global = MockHttpOverrides();
  });

  setUp(() {
    mockQuest = Quest(
      id: 'q1',
      title: 'Beginner Walker',
      description: 'Start your walking journey.',
      imageUrl: 'https://example.com/quest.png',
      difficulty: QuestDifficulty.easy,
      rewardCoins: 50,
      rewardXp: 100,
      status: QuestStatus.available,
      stages: [
        QuestStage(
          id: 's1',
          title: 'Stage 1',
          description: 'Walk 1000 steps',
          targetSteps: 1000,
          isCompleted: true,
        ),
        QuestStage(
          id: 's2',
          title: 'Stage 2',
          description: 'Walk 2000 steps',
          targetSteps: 2000,
          isCompleted: false,
        ),
        QuestStage(
          id: 's3',
          title: 'Stage 3',
          description: 'Walk 5000 steps',
          targetSteps: 5000,
          isCompleted: false,
        ),
      ],
      currentStageIndex: 1,
    );
  });

  testWidgets('QuestDetailScreen renders quest details correctly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questsProvider.overrideWith((ref) => MockQuestsNotifier(
                QuestsState(quests: [mockQuest]),
              )),
        ],
        child: MaterialApp(
          home: QuestDetailScreen(questId: 'q1', initialQuest: mockQuest),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Beginner Walker'), findsOneWidget);
    expect(find.text('Start your walking journey.'), findsOneWidget);
    expect(find.text('50 Coins'), findsOneWidget); 
    expect(find.text('100 XP'), findsOneWidget); 
    expect(find.text('Stage 1'), findsOneWidget);
    expect(find.text('Stage 2'), findsOneWidget);
    expect(find.text('Stage 3'), findsOneWidget);
  });

  testWidgets('QuestDetailScreen Start Quest button triggers joinQuest', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;

    final notifier = MockQuestsNotifier(QuestsState(quests: [mockQuest]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questsProvider.overrideWith((ref) => notifier),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: QuestDetailScreen(questId: 'q1', initialQuest: mockQuest),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final startBtn = find.text('Start Quest');
    expect(startBtn, findsOneWidget);

    await tester.tap(startBtn);
    await tester.pump();

    expect(notifier.joinQuestCalled, isTrue);
    expect(notifier.lastJoinedQuestId, equals('q1'));
  });

  testWidgets('QuestDetailScreen shows CircularProgressIndicator when loading', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;

    final notifier = MockQuestsNotifier(QuestsState(quests: [mockQuest], isLoading: true));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questsProvider.overrideWith((ref) => notifier),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: QuestDetailScreen(questId: 'q1', initialQuest: mockQuest),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Start Quest'), findsNothing);
  });

  testWidgets('QuestDetailScreen shows Continue Journey button for inProgress quest', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;

    final inProgressQuest = Quest(
      id: 'q1',
      title: 'Beginner Walker',
      description: 'Start your walking journey.',
      imageUrl: 'https://example.com/quest.png',
      difficulty: QuestDifficulty.easy,
      rewardCoins: 50,
      rewardXp: 100,
      status: QuestStatus.inProgress,
      stages: [
        QuestStage(
          id: 's1',
          title: 'Stage 1',
          description: 'Walk 1000 steps',
          targetSteps: 1000,
          isCompleted: false,
        ),
      ],
      currentStageIndex: 0,
    );

    final notifier = MockQuestsNotifier(QuestsState(quests: [inProgressQuest]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questsProvider.overrideWith((ref) => notifier),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: QuestDetailScreen(questId: 'q1', initialQuest: inProgressQuest),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final continueBtn = find.text('Continue Journey (Go Walk!)');
    expect(continueBtn, findsOneWidget);

    await tester.tap(continueBtn);
    await tester.pumpAndSettle();
  });

  testWidgets('QuestDetailScreen displays SnackBar on provider error', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;

    final notifier = MockQuestsNotifier(QuestsState(quests: [mockQuest]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questsProvider.overrideWith((ref) => notifier),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: QuestDetailScreen(questId: 'q1', initialQuest: mockQuest),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Trigger state change with an error
    notifier.state = QuestsState(quests: [mockQuest], error: 'Failed to join quest');
    await tester.pump(); // Triggers listener check

    expect(find.text('Failed to join quest'), findsOneWidget);
    expect(notifier.clearErrorCalled, isTrue);
  });
}

class MockQuestsNotifier extends StateNotifier<QuestsState> implements QuestsNotifier {
  MockQuestsNotifier(super.state);

  bool joinQuestCalled = false;
  String? lastJoinedQuestId;
  bool clearErrorCalled = false;

  Future<void> fetchQuests() async {}

  @override
  Future<void> joinQuest(String questId) async {
    joinQuestCalled = true;
    lastJoinedQuestId = questId;
  }

  @override
  void clearError() {
    clearErrorCalled = true;
  }
}
