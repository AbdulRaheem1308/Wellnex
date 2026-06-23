// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:wellnex_app/features/dashboard/presentation/providers/dashboard_provider.dart';

void main() {
  // ---------------------------------------------------------------------------
  // SyncStatus enum
  // ---------------------------------------------------------------------------
  group('SyncStatus', () {
    test('has exactly 4 values', () {
      expect(SyncStatus.values.length, 4);
    });

    test('contains idle, syncing, synced, failed', () {
      expect(SyncStatus.values, containsAll([
        SyncStatus.idle,
        SyncStatus.syncing,
        SyncStatus.synced,
        SyncStatus.failed,
      ]));
    });

    test('enum names are correct', () {
      expect(SyncStatus.idle.name, 'idle');
      expect(SyncStatus.syncing.name, 'syncing');
      expect(SyncStatus.synced.name, 'synced');
      expect(SyncStatus.failed.name, 'failed');
    });
  });

  // ---------------------------------------------------------------------------
  // TodaySteps.fromJson
  // ---------------------------------------------------------------------------
  group('TodaySteps.fromJson', () {
    test('parses a fully-populated JSON correctly', () {
      final json = {
        'stepCount': 5000,
        'caloriesBurned': 225,
        'distanceKm': 3.81,
        'activeMinutes': 50,
        'goal': 8000,
        'progress': 62,
        'goalReached': false,
      };

      final steps = TodaySteps.fromJson(json);

      expect(steps.stepCount, 5000);
      expect(steps.caloriesBurned, 225);
      expect(steps.distanceKm, closeTo(3.81, 0.001));
      expect(steps.activeMinutes, 50);
      expect(steps.goal, 8000);
      expect(steps.progress, 62);
      expect(steps.goalReached, isFalse);
    });

    test('defaults missing numeric fields to 0', () {
      final steps = TodaySteps.fromJson({});

      expect(steps.stepCount, 0);
      expect(steps.caloriesBurned, 0);
      expect(steps.distanceKm, 0.0);
      expect(steps.activeMinutes, 0);
      expect(steps.progress, 0);
    });

    test('defaults missing goal to 10000', () {
      final steps = TodaySteps.fromJson({});
      expect(steps.goal, 10000);
    });

    test('defaults missing goalReached to false', () {
      final steps = TodaySteps.fromJson({});
      expect(steps.goalReached, isFalse);
    });

    test('parses goalReached = true', () {
      final steps = TodaySteps.fromJson({
        'stepCount': 10001,
        'goal': 10000,
        'goalReached': true,
      });
      expect(steps.goalReached, isTrue);
    });

    test('parses distanceKm from a string value', () {
      final steps = TodaySteps.fromJson({'distanceKm': '4.5'});
      expect(steps.distanceKm, closeTo(4.5, 0.001));
    });

    test('parses distanceKm from a double value', () {
      final steps = TodaySteps.fromJson({'distanceKm': 2.75});
      expect(steps.distanceKm, closeTo(2.75, 0.001));
    });

    test('handles null distanceKm gracefully (defaults to 0.0)', () {
      final steps = TodaySteps.fromJson({'distanceKm': null});
      expect(steps.distanceKm, 0.0);
    });

    test('handles invalid distanceKm string gracefully (defaults to 0.0)', () {
      final steps = TodaySteps.fromJson({'distanceKm': 'not-a-number'});
      expect(steps.distanceKm, 0.0);
    });

    test('explicit null fields fall back to defaults', () {
      final steps = TodaySteps.fromJson({
        'stepCount': null,
        'caloriesBurned': null,
        'activeMinutes': null,
        'goal': null,
        'progress': null,
        'goalReached': null,
      });

      expect(steps.stepCount, 0);
      expect(steps.caloriesBurned, 0);
      expect(steps.activeMinutes, 0);
      expect(steps.goal, 10000);
      expect(steps.progress, 0);
      expect(steps.goalReached, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // TodaySteps.copyWith
  // ---------------------------------------------------------------------------
  group('TodaySteps.copyWith', () {
    late TodaySteps base;

    setUp(() {
      base = TodaySteps(
        stepCount: 3000,
        caloriesBurned: 135,
        distanceKm: 2.286,
        activeMinutes: 30,
        goal: 10000,
        progress: 30,
        goalReached: false,
      );
    });

    test('returns a new instance with no changes when called with no args', () {
      final copy = base.copyWith();

      expect(copy.stepCount, base.stepCount);
      expect(copy.caloriesBurned, base.caloriesBurned);
      expect(copy.distanceKm, base.distanceKm);
      expect(copy.activeMinutes, base.activeMinutes);
      expect(copy.goal, base.goal);
      expect(copy.progress, base.progress);
      expect(copy.goalReached, base.goalReached);
    });

    test('overrides only stepCount', () {
      final copy = base.copyWith(stepCount: 7500);

      expect(copy.stepCount, 7500);
      expect(copy.caloriesBurned, base.caloriesBurned);
      expect(copy.distanceKm, base.distanceKm);
    });

    test('overrides only goalReached to true', () {
      final copy = base.copyWith(goalReached: true);

      expect(copy.goalReached, isTrue);
      expect(copy.stepCount, base.stepCount);
    });

    test('overrides multiple fields at once', () {
      final copy = base.copyWith(
        stepCount: 10500,
        caloriesBurned: 472,
        distanceKm: 8.001,
        progress: 100,
        goalReached: true,
      );

      expect(copy.stepCount, 10500);
      expect(copy.caloriesBurned, 472);
      expect(copy.distanceKm, closeTo(8.001, 0.001));
      expect(copy.progress, 100);
      expect(copy.goalReached, isTrue);
      // Unchanged fields preserved
      expect(copy.activeMinutes, base.activeMinutes);
      expect(copy.goal, base.goal);
    });

    test('does not mutate the original instance', () {
      base.copyWith(stepCount: 99999, goalReached: true);

      expect(base.stepCount, 3000);
      expect(base.goalReached, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // StreakInfo.fromJson
  // ---------------------------------------------------------------------------
  group('StreakInfo.fromJson', () {
    test('parses required fields correctly', () {
      final info = StreakInfo.fromJson({
        'currentStreak': 7,
        'longestStreak': 14,
      });

      expect(info.currentStreak, 7);
      expect(info.longestStreak, 14);
    });

    test('defaults currentStreak and longestStreak to 0 when missing', () {
      final info = StreakInfo.fromJson({});

      expect(info.currentStreak, 0);
      expect(info.longestStreak, 0);
    });

    test('nextMilestone is null when absent', () {
      final info = StreakInfo.fromJson({'currentStreak': 3, 'longestStreak': 10});
      expect(info.nextMilestone, isNull);
    });

    test('parses optional nextMilestone', () {
      final info = StreakInfo.fromJson({
        'currentStreak': 5,
        'longestStreak': 10,
        'nextMilestone': 7,
      });

      expect(info.nextMilestone, 7);
    });

    test('daysToMilestone is null when absent', () {
      final info = StreakInfo.fromJson({'currentStreak': 5, 'longestStreak': 10});
      expect(info.daysToMilestone, isNull);
    });

    test('parses optional daysToMilestone', () {
      final info = StreakInfo.fromJson({
        'currentStreak': 5,
        'longestStreak': 10,
        'daysToMilestone': 2,
      });

      expect(info.daysToMilestone, 2);
    });

    test('parses all four fields together', () {
      final info = StreakInfo.fromJson({
        'currentStreak': 12,
        'longestStreak': 30,
        'nextMilestone': 14,
        'daysToMilestone': 2,
      });

      expect(info.currentStreak, 12);
      expect(info.longestStreak, 30);
      expect(info.nextMilestone, 14);
      expect(info.daysToMilestone, 2);
    });

    test('explicit null optional fields remain null', () {
      final info = StreakInfo.fromJson({
        'currentStreak': 1,
        'longestStreak': 1,
        'nextMilestone': null,
        'daysToMilestone': null,
      });

      expect(info.nextMilestone, isNull);
      expect(info.daysToMilestone, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // WalletInfo.fromJson
  // ---------------------------------------------------------------------------
  group('WalletInfo.fromJson', () {
    test('parses required fields correctly', () {
      final wallet = WalletInfo.fromJson({
        'balance': 500,
        'lifetimePoints': 12000,
      });

      expect(wallet.balance, 500);
      expect(wallet.lifetimePoints, 12000);
    });

    test('defaults balance and lifetimePoints to 0 when missing', () {
      final wallet = WalletInfo.fromJson({});

      expect(wallet.balance, 0);
      expect(wallet.lifetimePoints, 0);
    });

    test('monthlyXp is null when absent', () {
      final wallet = WalletInfo.fromJson({'balance': 100, 'lifetimePoints': 1000});
      expect(wallet.monthlyXp, isNull);
    });

    test('parses optional monthlyXp', () {
      final wallet = WalletInfo.fromJson({
        'balance': 200,
        'lifetimePoints': 5000,
        'monthlyXp': 850,
      });

      expect(wallet.monthlyXp, 850);
    });

    test('monthlyXp = 0 is preserved (not treated as null)', () {
      final wallet = WalletInfo.fromJson({
        'balance': 0,
        'lifetimePoints': 0,
        'monthlyXp': 0,
      });

      expect(wallet.monthlyXp, 0);
    });

    test('explicit null monthlyXp stays null', () {
      final wallet = WalletInfo.fromJson({
        'balance': 100,
        'lifetimePoints': 500,
        'monthlyXp': null,
      });

      expect(wallet.monthlyXp, isNull);
    });

    test('explicit null balance and lifetimePoints default to 0', () {
      final wallet = WalletInfo.fromJson({
        'balance': null,
        'lifetimePoints': null,
      });

      expect(wallet.balance, 0);
      expect(wallet.lifetimePoints, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // DailyStep – constructor
  // ---------------------------------------------------------------------------
  group('DailyStep', () {
    test('stores date and steps correctly', () {
      final date = DateTime(2025, 1, 15);
      final daily = DailyStep(date: date, steps: 8500);

      expect(daily.date, date);
      expect(daily.steps, 8500);
    });

    test('stores zero steps', () {
      final daily = DailyStep(date: DateTime(2025, 6, 1), steps: 0);
      expect(daily.steps, 0);
    });

    test('stores a high step count', () {
      final daily = DailyStep(date: DateTime(2025, 3, 20), steps: 45000);
      expect(daily.steps, 45000);
    });

    test('date is preserved with time component', () {
      final date = DateTime(2025, 11, 5, 14, 30, 0);
      final daily = DailyStep(date: date, steps: 1234);
      expect(daily.date.hour, 14);
      expect(daily.date.minute, 30);
    });
  });

  // ---------------------------------------------------------------------------
  // DashboardState – default values
  // ---------------------------------------------------------------------------
  group('DashboardState default values', () {
    late DashboardState state;

    setUp(() {
      state = DashboardState();
    });

    test('isLoading defaults to false', () {
      expect(state.isLoading, isFalse);
    });

    test('todaySteps defaults to null', () {
      expect(state.todaySteps, isNull);
    });

    test('streak defaults to null', () {
      expect(state.streak, isNull);
    });

    test('wallet defaults to null', () {
      expect(state.wallet, isNull);
    });

    test('user defaults to null', () {
      expect(state.user, isNull);
    });

    test('userStats defaults to null', () {
      expect(state.userStats, isNull);
    });

    test('weeklyHistory defaults to empty list', () {
      expect(state.weeklyHistory, isEmpty);
    });

    test('error defaults to null', () {
      expect(state.error, isNull);
    });

    test('xpLevel defaults to 1', () {
      expect(state.xpLevel, 1);
    });

    test('xpCurrentProgress defaults to 0', () {
      expect(state.xpCurrentProgress, 0);
    });

    test('xpToNextLevel defaults to 1000', () {
      expect(state.xpToNextLevel, 1000);
    });

    test('syncStatus defaults to SyncStatus.idle', () {
      expect(state.syncStatus, SyncStatus.idle);
    });

    test('lastSyncTime defaults to null', () {
      expect(state.lastSyncTime, isNull);
    });

    test('sensorStepsToday defaults to 0', () {
      expect(state.sensorStepsToday, 0);
    });

    test('healthAuthorized defaults to false', () {
      expect(state.healthAuthorized, isFalse);
    });

    test('sensorErrorMessage defaults to null', () {
      expect(state.sensorErrorMessage, isNull);
    });

    test('firstTrackingTime defaults to null', () {
      expect(state.firstTrackingTime, isNull);
    });

    test('lastTrackingTime defaults to null', () {
      expect(state.lastTrackingTime, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // DashboardState.copyWith – field preservation and override
  // ---------------------------------------------------------------------------
  group('DashboardState.copyWith', () {
    late DashboardState base;
    final now = DateTime(2025, 6, 1, 12, 0, 0);

    setUp(() {
      base = DashboardState(
        isLoading: false,
        todaySteps: TodaySteps(
          stepCount: 4000,
          caloriesBurned: 180,
          distanceKm: 3.0,
          activeMinutes: 40,
          goal: 10000,
          progress: 40,
          goalReached: false,
        ),
        streak: StreakInfo(currentStreak: 5, longestStreak: 10),
        wallet: WalletInfo(balance: 300, lifetimePoints: 6000, monthlyXp: 500),
        user: {'id': 'u1', 'name': 'Alice'},
        userStats: {'totalDays': 30},
        weeklyHistory: [DailyStep(date: now, steps: 4000)],
        error: null,
        xpLevel: 2,
        xpCurrentProgress: 45,
        xpToNextLevel: 550,
        syncStatus: SyncStatus.synced,
        lastSyncTime: now,
        sensorStepsToday: 3500,
        healthAuthorized: true,
        sensorErrorMessage: null,
        firstTrackingTime: now,
        lastTrackingTime: now,
      );
    });

    test('no-arg copyWith preserves all fields', () {
      final copy = base.copyWith();

      expect(copy.isLoading, base.isLoading);
      expect(copy.todaySteps, base.todaySteps);
      expect(copy.streak, base.streak);
      expect(copy.wallet, base.wallet);
      expect(copy.user, base.user);
      expect(copy.userStats, base.userStats);
      expect(copy.weeklyHistory, base.weeklyHistory);
      expect(copy.xpLevel, base.xpLevel);
      expect(copy.xpCurrentProgress, base.xpCurrentProgress);
      expect(copy.xpToNextLevel, base.xpToNextLevel);
      expect(copy.syncStatus, base.syncStatus);
      expect(copy.lastSyncTime, base.lastSyncTime);
      expect(copy.sensorStepsToday, base.sensorStepsToday);
      expect(copy.healthAuthorized, base.healthAuthorized);
      expect(copy.firstTrackingTime, base.firstTrackingTime);
      expect(copy.lastTrackingTime, base.lastTrackingTime);
    });

    test('overrides isLoading', () {
      final copy = base.copyWith(isLoading: true);
      expect(copy.isLoading, isTrue);
      expect(copy.xpLevel, base.xpLevel); // other fields unchanged
    });

    test('overrides syncStatus to syncing', () {
      final copy = base.copyWith(syncStatus: SyncStatus.syncing);
      expect(copy.syncStatus, SyncStatus.syncing);
    });

    test('overrides syncStatus to failed', () {
      final copy = base.copyWith(syncStatus: SyncStatus.failed);
      expect(copy.syncStatus, SyncStatus.failed);
    });

    test('overrides xpLevel and xpCurrentProgress independently', () {
      final copy = base.copyWith(xpLevel: 5, xpCurrentProgress: 80);
      expect(copy.xpLevel, 5);
      expect(copy.xpCurrentProgress, 80);
      expect(copy.xpToNextLevel, base.xpToNextLevel);
    });

    test('overrides sensorStepsToday', () {
      final copy = base.copyWith(sensorStepsToday: 6000);
      expect(copy.sensorStepsToday, 6000);
    });

    test('overrides healthAuthorized', () {
      final copy = base.copyWith(healthAuthorized: false);
      expect(copy.healthAuthorized, isFalse);
    });

    test('overrides lastSyncTime', () {
      final newTime = DateTime(2025, 7, 4);
      final copy = base.copyWith(lastSyncTime: newTime);
      expect(copy.lastSyncTime, newTime);
    });

    test('overrides firstTrackingTime and lastTrackingTime', () {
      final t1 = DateTime(2025, 6, 2, 8, 0);
      final t2 = DateTime(2025, 6, 2, 18, 0);
      final copy = base.copyWith(firstTrackingTime: t1, lastTrackingTime: t2);
      expect(copy.firstTrackingTime, t1);
      expect(copy.lastTrackingTime, t2);
    });

    test('error field: passing a value via copyWith sets it', () {
      // Note: copyWith always uses the provided `error` value (even null),
      // since the implementation does `error: error` (not `error ?? this.error`).
      final copy = base.copyWith(error: 'Something went wrong');
      expect(copy.error, 'Something went wrong');
    });

    test('error field: not passing error sets it to null (pass-through behaviour)', () {
      // Base has no error; calling copyWith without error keeps it null.
      final withError = base.copyWith(error: 'Oops');
      final cleared = withError.copyWith(); // no error arg → error: null in impl
      expect(cleared.error, isNull);
    });

    test('overrides weeklyHistory', () {
      final newHistory = [
        DailyStep(date: DateTime(2025, 6, 5), steps: 9000),
        DailyStep(date: DateTime(2025, 6, 6), steps: 11000),
      ];
      final copy = base.copyWith(weeklyHistory: newHistory);
      expect(copy.weeklyHistory.length, 2);
      expect(copy.weeklyHistory.first.steps, 9000);
    });

    test('overrides user map', () {
      final newUser = {'id': 'u2', 'name': 'Bob'};
      final copy = base.copyWith(user: newUser);
      expect(copy.user!['name'], 'Bob');
    });

    test('overrides todaySteps', () {
      final newSteps = TodaySteps(
        stepCount: 12000,
        caloriesBurned: 540,
        distanceKm: 9.144,
        activeMinutes: 120,
        goal: 10000,
        progress: 100,
        goalReached: true,
      );
      final copy = base.copyWith(todaySteps: newSteps);
      expect(copy.todaySteps!.stepCount, 12000);
      expect(copy.todaySteps!.goalReached, isTrue);
    });

    test('overrides streak', () {
      final newStreak = StreakInfo(
        currentStreak: 20,
        longestStreak: 20,
        nextMilestone: 30,
        daysToMilestone: 10,
      );
      final copy = base.copyWith(streak: newStreak);
      expect(copy.streak!.currentStreak, 20);
      expect(copy.streak!.nextMilestone, 30);
    });

    test('overrides wallet', () {
      final newWallet = WalletInfo(
        balance: 9999,
        lifetimePoints: 50000,
        monthlyXp: 2500,
      );
      final copy = base.copyWith(wallet: newWallet);
      expect(copy.wallet!.balance, 9999);
      expect(copy.wallet!.monthlyXp, 2500);
    });

    test('overrides sensorErrorMessage', () {
      final copy = base.copyWith(sensorErrorMessage: 'Sensor unavailable');
      expect(copy.sensorErrorMessage, 'Sensor unavailable');
    });

    test('does not mutate original state', () {
      base.copyWith(
        isLoading: true,
        xpLevel: 99,
        syncStatus: SyncStatus.failed,
      );

      expect(base.isLoading, isFalse);
      expect(base.xpLevel, 2);
      expect(base.syncStatus, SyncStatus.synced);
    });
  });
}
