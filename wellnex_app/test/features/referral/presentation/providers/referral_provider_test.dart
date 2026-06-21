import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:wellnex_app/features/referral/presentation/providers/referral_provider.dart';
import 'package:wellnex_app/services/api_service.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  late MockApiService mockApiService;

  setUp(() {
    mockApiService = MockApiService();
  });

  group('Referral Models & State Tests', () {
    test('ReferralStats equality and copyWith work', () {
      final stat1 = const ReferralStats(referralCode: 'CODE1', invitesAccepted: 5);
      final stat2 = const ReferralStats(referralCode: 'CODE1', invitesAccepted: 5);
      final stat3 = stat1.copyWith(referralCode: 'CODE2');

      expect(stat1, equals(stat2));
      expect(stat1.hashCode, equals(stat2.hashCode));
      expect(stat1, isNot(equals(stat3)));
      expect(stat3.referralCode, 'CODE2');
    });

    test('ReferralStats progress calculates correctly', () {
      final stat = const ReferralStats(referralCode: 'CODE', invitesAccepted: 2, milestones: [
        ReferralMilestone(target: 1, reward: 50, isUnlocked: true),
        ReferralMilestone(target: 3, reward: 100, isUnlocked: false),
      ]);

      expect(stat.nextMilestoneTarget, 3);
      // (2 - 1) / (3 - 1) = 1/2 = 0.5
      expect(stat.progressToNextMilestone, 0.5);
    });
  });

  group('ReferralNotifier Tests', () {
    test('fetchReferralData success updates state correctly', () async {
      when(() => mockApiService.get('/friends/invitations')).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/friends/invitations'),
            data: [
              {'status': 'ACCEPTED'},
              {'status': 'PENDING'},
            ],
            statusCode: 200,
          ));
      when(() => mockApiService.get('/users/me')).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/users/me'),
            data: {'id': 'USER123', 'name': 'Raheem'},
            statusCode: 200,
          ));
      when(() => mockApiService.get('/users/referral-leaderboard')).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/users/referral-leaderboard'),
            data: [
              {'id': 'USER123', 'name': 'Raheem', 'referralCount': 5},
              {'id': 'USER456', 'name': 'Bob', 'referralCount': 2},
            ],
            statusCode: 200,
          ));

      final notifier = ReferralNotifier(mockApiService);

      expect(notifier.state.isLoading, false);

      final future = notifier.fetchReferralData();
      expect(notifier.state.isLoading, true);

      await future;

      expect(notifier.state.isLoading, false);
      expect(notifier.state.error, isNull);
      expect(notifier.state.stats.referralCode, 'STEPUSER12');
      expect(notifier.state.stats.invitesSent, 2);
      expect(notifier.state.stats.invitesAccepted, 1);
      expect(notifier.state.stats.coinsEarned, 50); // 1 * 50
      
      expect(notifier.state.leaderboard.length, 2);
      expect(notifier.state.leaderboard[0].rank, 1);
      expect(notifier.state.leaderboard[1].rank, 2);
    });

    test('fetchReferralData handles API error', () async {
      when(() => mockApiService.get(any())).thenThrow(Exception('API Error'));

      final notifier = ReferralNotifier(mockApiService);
      await notifier.fetchReferralData();

      expect(notifier.state.isLoading, false);
      expect(notifier.state.error, contains('API Error'));
    });

    test('clearError clears error from state', () async {
      when(() => mockApiService.get(any())).thenThrow(Exception('API Error'));

      final notifier = ReferralNotifier(mockApiService);
      await notifier.fetchReferralData();

      expect(notifier.state.error, isNotNull);

      notifier.clearError();

      expect(notifier.state.error, isNull);
    });
  });
}
