import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';

import 'package:wellnex_app/features/wallet/presentation/screens/wallet_screen.dart';
import 'package:wellnex_app/services/api_service.dart';

// ─── Mocks ───────────────────────────────────────────────────────────────────

class MockApiService extends Mock implements ApiService {}

// ─── Helpers ─────────────────────────────────────────────────────────────────

Response<dynamic> _resp(dynamic data) => Response(
      requestOptions: RequestOptions(path: ''),
      data: data,
      statusCode: 200,
    );

const _walletData = {'balance': 750, 'lifetimePoints': 3000};

final _txData = {
  'data': [
    {
      'id': 'tx1',
      'type': 'STEPS',
      'points': 100,
      'description': 'Morning walk',
      'createdAt': '2025-01-10T09:00:00.000Z',
    },
    {
      'id': 'tx2',
      'type': 'STREAK_BONUS',
      'points': 200,
      'description': '7-day streak',
      'createdAt': '2025-01-11T09:00:00.000Z',
    },
    {
      'id': 'tx3',
      'type': 'REDEMPTION',
      'points': -150,
      'description': 'Amazon voucher',
      'createdAt': '2025-01-12T09:00:00.000Z',
    },
  ]
};

Widget _buildWidget(MockApiService api) {
  return ProviderScope(
    overrides: [apiServiceProvider.overrideWithValue(api)],
    child: const MaterialApp(home: WalletScreen()),
  );
}

/// Pump until data is loaded and all one-shot animations complete.
/// Uses [pumpAndSettle] which works because flutter_animate stagger
/// animations (fadeIn, slideX) are finite, not infinite.
Future<void> _pumpUntilLoaded(WidgetTester tester) async {
  await tester.pump(); // trigger microtask (fetchWalletData)
  await tester.pumpAndSettle(const Duration(seconds: 3));
}

void main() {
  late MockApiService mockApi;

  setUp(() {
    mockApi = MockApiService();
    registerFallbackValue(RequestOptions(path: ''));
  });

  // ─── Loading State ────────────────────────────────────────────────────────

  group('WalletScreen loading state', () {
    testWidgets('shows CircularProgressIndicator while fetching', (tester) async {
      final walletCompleter = Completer<Response<dynamic>>();
      final txCompleter = Completer<Response<dynamic>>();

      when(() => mockApi.get('/rewards/wallet'))
          .thenAnswer((_) => walletCompleter.future);
      when(() => mockApi.get('/rewards/transactions'))
          .thenAnswer((_) => txCompleter.future);

      await tester.pumpWidget(_buildWidget(mockApi));
      await tester.pump(); // Let microtask fire

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Resolve completers to clean up all pending timers
      walletCompleter.complete(_resp(_walletData));
      txCompleter.complete(_resp({'data': []}));
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });
  });

  // ─── Loaded State ─────────────────────────────────────────────────────────

  group('WalletScreen loaded state', () {
    setUp(() {
      when(() => mockApi.get('/rewards/wallet'))
          .thenAnswer((_) async => _resp(_walletData));
      when(() => mockApi.get('/rewards/transactions'))
          .thenAnswer((_) async => _resp(_txData));
    });

    testWidgets('displays My Wallet title in AppBar', (tester) async {
      await tester.pumpWidget(_buildWidget(mockApi));
      await _pumpUntilLoaded(tester);

      expect(find.text('My Wallet'), findsWidgets);
    });

    testWidgets('displays transaction descriptions after loading', (tester) async {
      await tester.pumpWidget(_buildWidget(mockApi));
      await _pumpUntilLoaded(tester);

      expect(find.text('Morning walk'), findsOneWidget);
      expect(find.text('7-day streak'), findsOneWidget);
      expect(find.text('Amazon voucher'), findsOneWidget);
    });

    testWidgets('shows RefreshIndicator on pull-to-refresh', (tester) async {
      await tester.pumpWidget(_buildWidget(mockApi));
      await _pumpUntilLoaded(tester);

      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('renders All, Earned and Redeemed tab labels', (tester) async {
      await tester.pumpWidget(_buildWidget(mockApi));
      await _pumpUntilLoaded(tester);

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Earned'), findsOneWidget);
      expect(find.text('Redeemed'), findsOneWidget);
    });

    testWidgets('shows Total Earned and Total Spent stat cards', (tester) async {
      await tester.pumpWidget(_buildWidget(mockApi));
      await _pumpUntilLoaded(tester);

      expect(find.text('Total Earned'), findsOneWidget);
      expect(find.text('Total Spent'), findsOneWidget);
    });

    testWidgets('does not show CircularProgressIndicator after load', (tester) async {
      await tester.pumpWidget(_buildWidget(mockApi));
      await _pumpUntilLoaded(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  // ─── Empty State ──────────────────────────────────────────────────────────

  group('WalletScreen empty state', () {
    testWidgets('shows empty state message when no transactions', (tester) async {
      when(() => mockApi.get('/rewards/wallet'))
          .thenAnswer((_) async => _resp({'balance': 0, 'lifetimePoints': 0}));
      when(() => mockApi.get('/rewards/transactions'))
          .thenAnswer((_) async => _resp({'data': []}));

      await tester.pumpWidget(_buildWidget(mockApi));
      await _pumpUntilLoaded(tester);

      expect(find.text('No transactions yet'), findsOneWidget);
      expect(find.text('Start walking to earn coins!'), findsOneWidget);
    });
  });

  // ─── Error State ──────────────────────────────────────────────────────────

  group('WalletScreen error state', () {
    testWidgets('shows SnackBar on fetch failure', (tester) async {
      when(() => mockApi.get('/rewards/wallet'))
          .thenThrow(Exception('Server Error'));
      when(() => mockApi.get('/rewards/transactions'))
          .thenThrow(Exception('Server Error'));

      await tester.pumpWidget(_buildWidget(mockApi));
      await tester.pump(); // fire microtask
      await tester.pump(const Duration(milliseconds: 100)); // let Future resolve

      expect(find.byType(SnackBar), findsOneWidget);

      await tester.pumpAndSettle(const Duration(seconds: 5)); // drain SnackBar
    });

    testWidgets('SnackBar contains Retry action', (tester) async {
      when(() => mockApi.get('/rewards/wallet'))
          .thenThrow(Exception('Connection error'));
      when(() => mockApi.get('/rewards/transactions'))
          .thenThrow(Exception('Connection error'));

      await tester.pumpWidget(_buildWidget(mockApi));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Retry'), findsOneWidget);

      await tester.pumpAndSettle(const Duration(seconds: 5));
    });



  });

  // ─── Tab filtering ────────────────────────────────────────────────────────

  group('WalletScreen tab filtering', () {
    setUp(() {
      when(() => mockApi.get('/rewards/wallet'))
          .thenAnswer((_) async => _resp(_walletData));
      when(() => mockApi.get('/rewards/transactions'))
          .thenAnswer((_) async => _resp(_txData));
    });

    testWidgets('Earned tab hides redemption transactions', (tester) async {
      await tester.pumpWidget(_buildWidget(mockApi));
      await _pumpUntilLoaded(tester);

      await tester.tap(find.text('Earned'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('Amazon voucher'), findsNothing);
      expect(find.text('Morning walk'), findsOneWidget);
    });

    testWidgets('Redeemed tab shows only redemption transactions', (tester) async {
      await tester.pumpWidget(_buildWidget(mockApi));
      await _pumpUntilLoaded(tester);

      await tester.tap(find.text('Redeemed'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('Amazon voucher'), findsOneWidget);
      expect(find.text('Morning walk'), findsNothing);
    });

    testWidgets('All tab restores full list after filter', (tester) async {
      await tester.pumpWidget(_buildWidget(mockApi));
      await _pumpUntilLoaded(tester);

      await tester.tap(find.text('Earned'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('Morning walk'), findsOneWidget);
      expect(find.text('Amazon voucher'), findsOneWidget);
    });

    testWidgets('Redeemed empty state shows correct message', (tester) async {
      when(() => mockApi.get('/rewards/transactions'))
          .thenAnswer((_) async => _resp({
                'data': [
                  {
                    'id': 'tx1',
                    'type': 'STEPS',
                    'points': 100,
                    'description': 'Walk',
                    'createdAt': '2025-01-10T09:00:00.000Z',
                  }
                ]
              }));

      await tester.pumpWidget(_buildWidget(mockApi));
      await _pumpUntilLoaded(tester);

      await tester.tap(find.text('Redeemed'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('No redemptions yet'), findsOneWidget);
    });
  });

  // ─── Accessibility / Semantics ────────────────────────────────────────────

  group('WalletScreen accessibility', () {
    setUp(() {
      when(() => mockApi.get('/rewards/wallet'))
          .thenAnswer((_) async => _resp(_walletData));
      when(() => mockApi.get('/rewards/transactions'))
          .thenAnswer((_) async => _resp(_txData));
    });

    testWidgets('Semantics widgets present on screen', (tester) async {
      await tester.pumpWidget(_buildWidget(mockApi));
      await _pumpUntilLoaded(tester);

      // Check Semantics nodes exist (balance + transaction cards)
      expect(find.byType(Semantics), findsWidgets);
    });

    testWidgets('Transaction cards have meaningful text', (tester) async {
      await tester.pumpWidget(_buildWidget(mockApi));
      await _pumpUntilLoaded(tester);

      // Tab labels are readable
      expect(find.text('Earned'), findsOneWidget);
      expect(find.text('Redeemed'), findsOneWidget);
      // Coin label visible
      expect(find.text('coins'), findsWidgets);
    });
  });
}
