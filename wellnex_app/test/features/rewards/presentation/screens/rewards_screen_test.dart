import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wellnex_app/features/rewards/presentation/screens/rewards_screen.dart';
import 'package:wellnex_app/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:wellnex_app/services/api_service.dart';
import 'package:wellnex_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:wellnex_app/features/rewards/presentation/providers/rewards_catalog_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';

class MockApiService extends Mock implements ApiService {}
class MockWalletNotifier extends StateNotifier<WalletState> implements WalletNotifier {
  MockWalletNotifier(super.state);
  @override
  Future<void> fetchWalletData() async {}
  @override
  void setFilter(String filter) {
    state = state.copyWith(selectedFilter: filter);
  }
  @override
  void clearError() {
    state = state.copyWith(error: null);
  }
}

class MockRewardsCatalogNotifier extends StateNotifier<RewardsCatalogState> implements RewardsCatalogNotifier {
  MockRewardsCatalogNotifier(super.state);
  @override
  Future<void> fetchCatalog({String? category}) async {}
  @override
  Future<void> fetchMyOffers() async {}
  @override
  Future<bool> redeemOffer(String offerId) async { return true; }
  @override
  Future<Map<String, dynamic>?> redeemReward(String rewardId) async { return {}; }
  @override
  Future<bool> cancelRedemption(String redemptionId) async { return true; }
  @override
  void setCategoryFilter(String category) {
    state = state.copyWith(selectedCategory: category);
  }
  @override
  void setCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }
}

void main() {
  late MockApiService mockApiService;

  setUp(() {
    mockApiService = MockApiService();
  });

  Widget createWidget({
    WalletState? walletState,
    RewardsCatalogState? catalogState,
  }) {
    final wState = walletState ?? const WalletState();
    final cState = catalogState ?? RewardsCatalogState();
    return ProviderScope(
      overrides: [
        apiServiceProvider.overrideWithValue(mockApiService),
        walletProvider.overrideWith((ref) => MockWalletNotifier(wState)),
        rewardsCatalogProvider.overrideWith((ref) => MockRewardsCatalogNotifier(cState)),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en', '')],
        home: RewardsScreen(),
      ),
    );
  }

  Future<void> pumpAndWait(WidgetTester tester) async {
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('RewardsScreen loads and displays all tabs, handles API fetch', (tester) async {
    when(() => mockApiService.get('/rewards/achievements')).thenAnswer((_) async => Response(
      requestOptions: RequestOptions(path: ''),
      data: [
        {'id': '1', 'name': 'First Step', 'description': 'Walk 1000 steps', 'code': 'directions_walk', 'unlockedAt': '2023-01-01T00:00:00Z', 'unlocked': true},
        {'id': '2', 'name': 'Marathon', 'description': 'Walk 40km', 'code': 'emoji_events', 'unlocked': false},
      ]
    ));

    await tester.pumpWidget(createWidget(
      walletState: WalletState(
        balance: 100, 
        lifetimePoints: 500,
        transactions: [
          WalletTransaction(id: 't1', type: 'earn', points: 10, description: 'Daily Goal', createdAt: DateTime.parse('2023-01-01T00:00:00Z')),
          WalletTransaction(id: 't2', type: 'spend', points: 50, description: 'Coffee', createdAt: DateTime.parse('2023-01-02T00:00:00Z'))
        ]
      )
    ));
    await pumpAndWait(tester);

    // Verify Wallet tab is default and renders balance
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('100'), findsOneWidget); // Balance
    expect(find.text('Daily Goal'), findsOneWidget);
    
    // Test Wallet filter chip tap
    await tester.tap(find.widgetWithText(FilterChip, 'Earned'));
    await pumpAndWait(tester);
    
    // Tap transaction card (doesn't open a dialog, but tests interaction)
    await tester.tap(find.text('Daily Goal'));
    await pumpAndWait(tester);

    // Test Catalog Tab
    await tester.tap(find.text('Catalog'));
    await pumpAndWait(tester);
    expect(find.text('Coming Soon!'), findsOneWidget);

    // Test Achievements Tab
    await tester.tap(find.text('Badges'));
    await pumpAndWait(tester);
    
    // Should display the achievements from mock API
    expect(find.text('First Step'), findsOneWidget);
    expect(find.text('Marathon'), findsOneWidget);
    
    // Test Badge filter chip
    await tester.tap(find.text('Unlocked'));
    await pumpAndWait(tester);
    
    // Test info dialog for badge
    await tester.tap(find.text('First Step'));
    await pumpAndWait(tester);
    expect(find.text('Unlocked'), findsWidgets);
    await tester.tap(find.text('Share')); // Test share button
    await pumpAndWait(tester);
    await tester.tap(find.text('Close')); // Close dialog
    await pumpAndWait(tester);
    
    // Test locked badge dialog
    await tester.tap(find.text('All'));
    await pumpAndWait(tester);
    await tester.tap(find.text('Marathon'));
    await pumpAndWait(tester);
    expect(find.text('Locked'), findsWidgets);
    await tester.tap(find.text('Close'));
    await pumpAndWait(tester);
  });
    
  testWidgets('RewardsScreen handles API error gracefully', (tester) async {
    when(() => mockApiService.get('/rewards/achievements')).thenThrow(DioException(requestOptions: RequestOptions(path: '')));

    await tester.pumpWidget(createWidget());
    
    // Wait for data to load
    await pumpAndWait(tester);
    
    await tester.tap(find.text('Badges'));
    await pumpAndWait(tester);
    
    // Should show empty state for badges
    expect(find.textContaining('badges found'), findsOneWidget);
  });
  
  testWidgets('Wallet tab empty transactions state', (tester) async {
    when(() => mockApiService.get('/rewards/achievements')).thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: []));
    await tester.pumpWidget(createWidget(walletState: const WalletState(transactions: [])));
    await pumpAndWait(tester);
    
    expect(find.text('No transactions yet'), findsOneWidget);
    
    // Trigger RefreshIndicator on Wallet tab to cover onRefresh
    await tester.fling(find.text('No transactions yet'), const Offset(0.0, 300.0), 1000.0);
    await pumpAndWait(tester);
  });
}
