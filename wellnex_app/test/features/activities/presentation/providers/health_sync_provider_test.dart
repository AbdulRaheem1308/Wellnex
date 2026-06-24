import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:wellnex_app/features/activities/domain/models/activity_model.dart';
import 'package:wellnex_app/features/activities/presentation/providers/activity_provider.dart';
import 'package:wellnex_app/features/activities/presentation/providers/health_sync_provider.dart';
import 'package:wellnex_app/services/health_service.dart';

class MockHealthService implements HealthService {
  bool requestAuthResult = true;
  List<HealthDataPoint> recentWorkoutsResult = [];
  bool requestAuthCalled = false;
  bool getRecentWorkoutsCalled = false;
  Exception? throwErrorOnWorkouts;

  @override
  Future<bool> requestAuthorization() async {
    requestAuthCalled = true;
    return requestAuthResult;
  }

  @override
  Future<List<HealthDataPoint>> getRecentWorkouts(int days) async {
    getRecentWorkoutsCalled = true;
    if (throwErrorOnWorkouts != null) throw throwErrorOnWorkouts!;
    return recentWorkoutsResult;
  }

  @override
  Future<Map<DateTime, int>> getStepHistory(int days) async => {};

  @override
  Future<int> getTodaySteps() async => 0;

  @override
  Future<bool> isHealthConnectAvailable() async => true;

  @override
  Future<void> installHealthConnect() async {}
}

class MockActivityNotifier extends StateNotifier<ActivityState> implements ActivityNotifier {
  MockActivityNotifier() : super(const ActivityState(recentActivities: []));

  int logActivityCalledCount = 0;

  @override
  Future<String?> logActivity({
    required ActivityType type,
    required Duration duration,
    double? distanceKm,
    String? source,
  }) async {
    logActivityCalledCount++;
    return null;
  }

  @override
  Future<void> fetchActivities() async {}
}

void main() {
  group('HealthSyncNotifier', () {
    late MockHealthService mockHealthService;
    late MockActivityNotifier mockActivityNotifier;
    late HealthSyncNotifier notifier;

    setUp(() {
      mockHealthService = MockHealthService();
      mockActivityNotifier = MockActivityNotifier();
      notifier = HealthSyncNotifier(mockHealthService, mockActivityNotifier);
    });

    test('syncRecentWorkouts stops if requestAuthorization fails', () async {
      mockHealthService.requestAuthResult = false;
      
      await notifier.syncRecentWorkouts();
      
      expect(mockHealthService.requestAuthCalled, isTrue);
      expect(mockHealthService.getRecentWorkoutsCalled, isFalse);
      expect(notifier.debugState, false); // state should be back to false
    });

    test('syncRecentWorkouts handles exceptions gracefully', () async {
      mockHealthService.throwErrorOnWorkouts = Exception('Mock Error');
      
      await notifier.syncRecentWorkouts();
      
      expect(mockHealthService.requestAuthCalled, isTrue);
      expect(mockHealthService.getRecentWorkoutsCalled, isTrue);
      expect(notifier.debugState, false); // state should be back to false
    });

    test('syncRecentWorkouts maps HealthWorkoutActivityType correctly', () async {
      // We will create a dummy workout for each supported type
      final healthTypes = [
        HealthWorkoutActivityType.RUNNING,
        HealthWorkoutActivityType.BIKING,
        HealthWorkoutActivityType.WALKING,
        HealthWorkoutActivityType.SWIMMING,
        HealthWorkoutActivityType.SWIMMING_POOL,
        HealthWorkoutActivityType.SWIMMING_OPEN_WATER,
        HealthWorkoutActivityType.YOGA,
        HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING,
        HealthWorkoutActivityType.HIKING,
      ];
      
      final workouts = healthTypes.map<HealthDataPoint>((type) => HealthDataPoint(
        value: WorkoutHealthValue(
          workoutActivityType: type,
          totalEnergyBurned: 100,
          totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
          totalDistance: 1000,
          totalDistanceUnit: HealthDataUnit.METER,
        ),
        type: HealthDataType.WORKOUT,
        unit: HealthDataUnit.NO_UNIT,
        dateFrom: DateTime.now().subtract(const Duration(hours: 1)),
        dateTo: DateTime.now(),
        uuid: 'dummy-uuid',
        sourcePlatform: HealthPlatformType.appleHealth,
        sourceDeviceId: 'device1',
        sourceId: 'source1',
        sourceName: 'Apple Health',
      )).toList();

      mockHealthService.recentWorkoutsResult = workouts;

      await notifier.syncRecentWorkouts();

      expect(mockActivityNotifier.logActivityCalledCount, equals(healthTypes.length));
    });

    test('syncRecentWorkouts skips unknown workout types', () async {
      final workouts = [
        HealthDataPoint(
          value: WorkoutHealthValue(
            workoutActivityType: HealthWorkoutActivityType.BASEBALL,
            totalEnergyBurned: 100,
            totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
            totalDistance: 1000,
            totalDistanceUnit: HealthDataUnit.METER,
          ),
          type: HealthDataType.WORKOUT,
          unit: HealthDataUnit.NO_UNIT,
          dateFrom: DateTime.now().subtract(const Duration(hours: 1)),
          dateTo: DateTime.now(),
          uuid: 'dummy-uuid',
          sourcePlatform: HealthPlatformType.appleHealth,
          sourceDeviceId: 'device1',
          sourceId: 'source1',
          sourceName: 'Apple Health',
        )
      ];

      mockHealthService.recentWorkoutsResult = workouts;

      await notifier.syncRecentWorkouts();

      expect(mockActivityNotifier.logActivityCalledCount, equals(0));
    });
  });
}
