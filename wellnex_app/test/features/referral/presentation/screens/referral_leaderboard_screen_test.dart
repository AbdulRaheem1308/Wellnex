import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wellnex_app/features/referral/presentation/providers/referral_provider.dart';
import 'package:wellnex_app/features/referral/presentation/screens/referral_leaderboard_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:wellnex_app/services/api_service.dart';
import 'package:wellnex_app/services/storage_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'dart:io';

// ─── Mock Classes ──────────────────────────────────────────────────────────

class MockApiService extends Mock implements ApiService {}

/// Mock notifier — fetchReferralData is a no-op so it won't trigger errors.
class MockReferralNotifier extends StateNotifier<ReferralState>
    with Mock
    implements ReferralNotifier {
  MockReferralNotifier(super.state);
}

/// Fake SharePlatform so Share.share() doesn't crash in tests.
class FakeSharePlatform extends Fake
    with MockPlatformInterfaceMixin
    implements SharePlatform {
  @override
  Future<ShareResult> share(
    String text, {
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
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
    return const ShareResult('success', ShareResultStatus.success);
  }
}

// ─── Helpers ───────────────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final temp = await Directory.systemTemp.createTemp();
    Hive.init(temp.path);
    if (!Hive.isBoxOpen('wellnex_storage')) {
      await StorageService.init();
    }
    SharePlatform.instance = FakeSharePlatform();
  });

  Widget createWidget(MockReferralNotifier notifier) {
    return UncontrolledProviderScope(
      container: ProviderContainer(
        overrides: [
          referralProvider.overrideWith((ref) => notifier),
        ],
      ),
      child: const MaterialApp(
        home: ReferralLeaderboardScreen(),
      ),
    );
  }

  MockReferralNotifier buildNotifier(ReferralState state) {
    final notifier = MockReferralNotifier(state);
    when(() => notifier.fetchReferralData()).thenAnswer((_) async {});
    when(() => notifier.clearError()).thenReturn(null);
    return notifier;
  }

  // ─── Loading State ────────────────────────────────────────────────────────

  testWidgets('shows CircularProgressIndicator while loading', (tester) async {
    final notifier = buildNotifier(ReferralState(isLoading: true));
    await tester.pumpWidget(createWidget(notifier));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // ─── AppBar title ─────────────────────────────────────────────────────────

  testWidgets('renders AppBar with "Top Referrers" title', (tester) async {
    final notifier = buildNotifier(ReferralState(isLoading: false));
    await tester.pumpWidget(createWidget(notifier));
    await tester.pumpAndSettle();

    expect(find.text('Top Referrers'), findsOneWidget);
  });

  // ─── Empty State ──────────────────────────────────────────────────────────

  testWidgets('shows empty state when leaderboard is empty', (tester) async {
    final notifier = buildNotifier(
      ReferralState(isLoading: false, leaderboard: []),
    );
    await tester.pumpWidget(createWidget(notifier));
    await tester.pumpAndSettle();

    expect(find.text('No referrers yet'), findsOneWidget);
    expect(find.text('Be the first to join the leaderboard!'), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
  });

  // ─── User Stats Header: rank == 0 shows '-' ───────────────────────────────

  testWidgets('shows dash for rank when rank is 0', (tester) async {
    final stats = const ReferralStats(
      referralCode: 'CODE',
      invitesAccepted: 0,
      coinsEarned: 0,
      rank: 0, // rank == 0 → '-'
    );
    final notifier = buildNotifier(
      ReferralState(isLoading: false, stats: stats, leaderboard: []),
    );
    await tester.pumpWidget(createWidget(notifier));
    await tester.pumpAndSettle();

    expect(find.text('-'), findsOneWidget);
  });

  // ─── User Stats Header: rank > 0 shows '#N' ──────────────────────────────

  testWidgets('shows hash rank when rank > 0', (tester) async {
    final stats = const ReferralStats(
      referralCode: 'CODE',
      invitesAccepted: 3,
      coinsEarned: 150,
      rank: 2,
    );
    final notifier = buildNotifier(
      ReferralState(isLoading: false, stats: stats, leaderboard: []),
    );
    await tester.pumpWidget(createWidget(notifier));
    await tester.pumpAndSettle();

    expect(find.text('#2'), findsOneWidget);
  });

  // ─── Stats header labels ──────────────────────────────────────────────────

  testWidgets('shows Rank, Invites, Earned labels in stats header', (tester) async {
    final stats = const ReferralStats(
      referralCode: 'CODE',
      invitesAccepted: 7,
      coinsEarned: 350,
      rank: 5,
    );
    final notifier = buildNotifier(
      ReferralState(isLoading: false, stats: stats),
    );
    await tester.pumpWidget(createWidget(notifier));
    await tester.pumpAndSettle();

    expect(find.text('Rank'), findsOneWidget);
    expect(find.text('Invites'), findsOneWidget);
    expect(find.text('Earned'), findsOneWidget);
    expect(find.text('#5'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('350'), findsOneWidget);
  });

  // ─── Top 3 get trophy icons; rank 4+ gets text ───────────────────────────

  testWidgets('shows trophy icons for rank 1-3 and text for rank 4+', (tester) async {
    final leaderboard = [
      const TopReferrer(id: '1', name: 'Gold', referrals: 30, rank: 1),
      const TopReferrer(id: '2', name: 'Silver', referrals: 20, rank: 2),
      const TopReferrer(id: '3', name: 'Bronze', referrals: 10, rank: 3),
      const TopReferrer(id: '4', name: 'Fourth', referrals: 5, rank: 4),
    ];
    final notifier = buildNotifier(
      ReferralState(isLoading: false, leaderboard: leaderboard),
    );
    await tester.pumpWidget(createWidget(notifier));
    await tester.pumpAndSettle();

    // 3 trophy icons for top 3 (emoji_events is the trophy)
    expect(find.byIcon(Icons.emoji_events), findsNWidgets(3));
    // Rank text for #4
    expect(find.text('#4'), findsOneWidget);
    // All names
    expect(find.text('Gold'), findsOneWidget);
    expect(find.text('Silver'), findsOneWidget);
    expect(find.text('Bronze'), findsOneWidget);
    expect(find.text('Fourth'), findsOneWidget);
  });

  // ─── isMe: 'You' badge shown when id matches current user ─────────────────

  testWidgets('shows You badge when referrer id matches current user', (tester) async {
    // StorageService.getUser() returns null in test → currentUserId == ''
    // So id == '' triggers isMe = true
    final leaderboard = [
      const TopReferrer(id: '', name: 'Me', referrals: 5, rank: 4),
    ];
    final notifier = buildNotifier(
      ReferralState(isLoading: false, leaderboard: leaderboard),
    );
    await tester.pumpWidget(createWidget(notifier));
    await tester.pumpAndSettle();

    expect(find.text('You'), findsOneWidget);
  });

  // ─── Empty name fallback shows '?' in avatar ─────────────────────────────

  testWidgets('shows ? avatar for empty referrer name', (tester) async {
    final leaderboard = [
      const TopReferrer(id: '99', name: '', referrals: 1, rank: 4),
    ];
    final notifier = buildNotifier(
      ReferralState(isLoading: false, leaderboard: leaderboard),
    );
    await tester.pumpWidget(createWidget(notifier));
    await tester.pumpAndSettle();

    expect(find.text('?'), findsOneWidget);
  });

  // ─── Earned coins = referrals × 50 ───────────────────────────────────────

  testWidgets('shows correct earned coins for referrers (referrals * 50)', (tester) async {
    final leaderboard = [
      const TopReferrer(id: '1', name: 'Alice', referrals: 4, rank: 4),
    ];
    final notifier = buildNotifier(
      ReferralState(isLoading: false, leaderboard: leaderboard),
    );
    await tester.pumpWidget(createWidget(notifier));
    await tester.pumpAndSettle();

    // 4 × 50 = 200
    expect(find.text('200'), findsOneWidget);
    expect(find.text('4 active'), findsOneWidget);
  });

  // ─── Share invite: valid code → no error snackbar ─────────────────────────

  testWidgets('share button with valid code does not show error snackbar', (tester) async {
    final stats = const ReferralStats(referralCode: 'VALIDCODE', rank: 1);
    final notifier = buildNotifier(
      ReferralState(isLoading: false, stats: stats, leaderboard: []),
    );
    await tester.pumpWidget(createWidget(notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Invite Friends & Climb Rank'));
    await tester.pumpAndSettle();

    expect(find.text('Invite code not found. Please try again.'), findsNothing);
  });

  // ─── Share invite: empty code → error snackbar ────────────────────────────

  testWidgets('share button with empty code shows error snackbar', (tester) async {
    final stats = const ReferralStats(referralCode: '', rank: 0);
    final notifier = buildNotifier(
      ReferralState(isLoading: false, stats: stats, leaderboard: []),
    );
    await tester.pumpWidget(createWidget(notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Invite Friends & Climb Rank'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.text('Invite code not found. Please try again.', skipOffstage: false),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 4));
  });

  // ─── Error snackbar from provider ref.listen ──────────────────────────────

  testWidgets('shows error snackbar and calls clearError when provider emits error', (tester) async {
    final notifier = buildNotifier(ReferralState(isLoading: false));
    await tester.pumpWidget(createWidget(notifier));
    await tester.pumpAndSettle();

    // Transition to error state — triggers ref.listen
    notifier.state = ReferralState(
      isLoading: false,
      error: 'Something went wrong',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Something went wrong', skipOffstage: false), findsOneWidget);
    verify(() => notifier.clearError()).called(1);

    await tester.pump(const Duration(seconds: 4));
  });

  // ─── Error snackbar via real API failure path ─────────────────────────────

  testWidgets('shows error snackbar when API throws during fetch', (tester) async {
    final mockApi = MockApiService();
    when(() => mockApi.get(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
      ),
    );

    final container = ProviderContainer(
      overrides: [
        referralProvider.overrideWith((ref) => ReferralNotifier(mockApi)),
      ],
    );

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ReferralLeaderboardScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
