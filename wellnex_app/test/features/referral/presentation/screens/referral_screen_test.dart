import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:go_router/go_router.dart';
import 'package:wellnex_app/features/referral/presentation/screens/referral_screen.dart';
import 'package:wellnex_app/features/referral/presentation/providers/referral_provider.dart';
import 'package:wellnex_app/l10n/app_localizations.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'dart:io';
import 'dart:async';

import 'package:screenshot/screenshot.dart';

class MockReferralNotifier extends StateNotifier<ReferralState> with Mock implements ReferralNotifier {
  MockReferralNotifier(super.state);
}

class FakeScreenshotController extends ScreenshotController {
  final Future<Uint8List?> Function()? captureMock;
  FakeScreenshotController({this.captureMock});

  @override
  Future<Uint8List?> capture({
    double? pixelRatio,
    Duration delay = const Duration(milliseconds: 20),
  }) async {
    if (captureMock != null) {
      return captureMock!();
    }
    return super.capture(pixelRatio: pixelRatio, delay: delay);
  }
}

class FakePathProviderPlatform extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async {
    final dir = Directory.systemTemp.createTempSync('wellnex_test_');
    return dir.path;
  }
}

class FakeSharePlatform extends Fake with MockPlatformInterfaceMixin implements SharePlatform {
  Completer<void> shareCompleter = Completer<void>();

  @override
  Future<ShareResult> share(
    String text, {
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    if (!shareCompleter.isCompleted) shareCompleter.complete();
    return const ShareResult('success', ShareResultStatus.success);
  }

  @override
  Future<ShareResult> shareXFiles(
    List<XFile> files, {
    String? subject,
    String? text,
    Rect? sharePositionOrigin,
    List<String>? fileNameOverrides,
  }) async {
    if (!shareCompleter.isCompleted) shareCompleter.complete();
    return const ShareResult('success', ShareResultStatus.success);
  }
}

void main() {
  late MockReferralNotifier mockNotifier;
  late FakeSharePlatform fakeSharePlatform;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    PathProviderPlatform.instance = FakePathProviderPlatform();
  });

  setUp(() {
    fakeSharePlatform = FakeSharePlatform();
    SharePlatform.instance = fakeSharePlatform;
    mockNotifier = MockReferralNotifier(ReferralState(isLoading: true));
    when(() => mockNotifier.fetchReferralData()).thenAnswer((_) => Future.value());
    when(() => mockNotifier.clearError()).thenReturn(null);
  });

  Widget createWidgetUnderTest({ScreenshotController? screenshotController}) {
    final router = GoRouter(
      initialLocation: '/referral',
      routes: [
        GoRoute(
          path: '/referral',
          builder: (context, state) => ReferralScreen(screenshotController: screenshotController),
        ),
        GoRoute(
          path: '/referral-leaderboard',
          builder: (context, state) => const Scaffold(body: Text('Leaderboard Page')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        referralProvider.overrideWith((ref) => mockNotifier),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }

  testWidgets('renders loading state', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows error snackbar when state has error', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    
    mockNotifier.state = ReferralState(
      isLoading: false,
      error: 'Test Error',
    );
    await tester.pump(); // Trigger listener
    
    expect(find.text('Test Error'), findsOneWidget);
    verify(() => mockNotifier.clearError()).called(1);
    
    await tester.pumpAndSettle(); // Allow snackbar to disappear
  });

  testWidgets('renders stats and empty leaderboard', (WidgetTester tester) async {
    mockNotifier.state = ReferralState(
      isLoading: false,
      stats: const ReferralStats(
        referralCode: 'TESTCODE',
        invitesSent: 5,
        invitesAccepted: 2,
        coinsEarned: 100,
        milestones: [
          ReferralMilestone(target: 1, reward: 50, isUnlocked: true),
          ReferralMilestone(target: 3, reward: 100, isUnlocked: false),
        ],
      ),
      leaderboard: [],
    );

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('TESTCODE'), findsWidgets);
    expect(find.text('2'), findsWidgets); // Used in accepted and progress
    expect(find.text('100'), findsOneWidget); // Coins earned
    
    // Empty leaderboard text
    expect(find.text('No top referrers yet'), findsOneWidget);
  });

  testWidgets('renders leaderboard with multiple ranks and view all nav', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    mockNotifier.state = ReferralState(
      isLoading: false,
      stats: const ReferralStats(referralCode: 'CODE', milestones: []),
      leaderboard: [
        TopReferrer(id: '1', name: 'User 1', referrals: 10, rank: 1),
        TopReferrer(id: '2', name: 'User 2', referrals: 8, rank: 2),
        TopReferrer(id: '3', name: 'User 3', referrals: 5, rank: 3),
        TopReferrer(id: '4', name: 'User 4', referrals: 2, rank: 4),
        TopReferrer(id: '5', name: '', referrals: 1, rank: 5), // empty name edge case
      ],
    );

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('User 1'), findsOneWidget);
    expect(find.text('User 2'), findsOneWidget);
    expect(find.text('User 3'), findsOneWidget);
    expect(find.text('User 4'), findsOneWidget);
    expect(find.text('?'), findsOneWidget); // Empty name fallback
    expect(find.text('#4'), findsOneWidget);

    // Tap View All
    await tester.tap(find.text('View All'));
    await tester.pumpAndSettle();
    expect(find.text('Leaderboard Page'), findsOneWidget);
  });

  testWidgets('pull to refresh calls fetchReferralData', (WidgetTester tester) async {
    mockNotifier.state = ReferralState(
      isLoading: false,
      stats: const ReferralStats(referralCode: 'CODE', milestones: []),
    );

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.drag(find.text('CODE').first, const Offset(0, 500));
    await tester.pumpAndSettle();

    verify(() => mockNotifier.fetchReferralData()).called(greaterThanOrEqualTo(1));
  });

  testWidgets('copy code puts code in clipboard and shows snackbar', (WidgetTester tester) async {
    mockNotifier.state = ReferralState(
      isLoading: false,
      stats: const ReferralStats(referralCode: 'CODE123', milestones: []),
    );

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump();
    
    await tester.pump();
    expect(find.text('Code "CODE123" copied!'), findsOneWidget);
    
    // Clear snackbar to avoid pending timers
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('share invite captures screenshot and shares successfully', (WidgetTester tester) async {
    mockNotifier.state = ReferralState(
      isLoading: false,
      stats: const ReferralStats(referralCode: 'CODE123', milestones: []),
    );
    
    bool captureCalled = false;
    final fakeController = FakeScreenshotController(
      captureMock: () async {
        captureCalled = true;
        return Uint8List.fromList([1, 2, 3]);
      },
    );

    await tester.pumpWidget(createWidgetUnderTest(screenshotController: fakeController));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.text('Invite Friends'));
      await fakeSharePlatform.shareCompleter.future.timeout(const Duration(seconds: 2));
    });
    
    await tester.pumpAndSettle();
    
    expect(captureCalled, true);
  });

  testWidgets('share invite falls back to text when capture returns null', (WidgetTester tester) async {
    mockNotifier.state = ReferralState(
      isLoading: false,
      stats: const ReferralStats(referralCode: 'CODE123', milestones: []),
    );
    
    bool captureCalled = false;
    final fakeController = FakeScreenshotController(
      captureMock: () async {
        captureCalled = true;
        return null;
      },
    );

    await tester.pumpWidget(createWidgetUnderTest(screenshotController: fakeController));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Invite Friends'));
    await tester.pump();
    expect(find.text('Generating invite card...'), findsOneWidget);
    
    await tester.pumpAndSettle();
    
    expect(captureCalled, true);
  });

  testWidgets('share invite falls back to text on exception', (WidgetTester tester) async {
    mockNotifier.state = ReferralState(
      isLoading: false,
      stats: const ReferralStats(referralCode: 'CODE123', milestones: []),
    );
    
    bool captureCalled = false;
    final fakeController = FakeScreenshotController(
      captureMock: () async {
        captureCalled = true;
        throw Exception('Capture failed');
      },
    );

    await tester.pumpWidget(createWidgetUnderTest(screenshotController: fakeController));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Invite Friends'));
    await tester.pump();
    expect(find.text('Generating invite card...'), findsOneWidget);
    
    await tester.pumpAndSettle();
    
    expect(captureCalled, true);
  });
}
