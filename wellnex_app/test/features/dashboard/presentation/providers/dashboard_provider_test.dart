import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wellnex_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:wellnex_app/features/devices/presentation/providers/device_provider.dart' hide SyncStatus;
import 'package:wellnex_app/services/api_service.dart';
import 'package:wellnex_app/services/health_service.dart';
import 'package:wellnex_app/services/storage_service.dart';
import 'package:dio/dio.dart';
import 'package:health/health.dart';

class MockApiService extends ApiService {
  MockApiService() : super();

  bool getCalled = false;
  bool postCalled = false;
  bool putCalled = false;
  String? lastGetPath;
  String? lastPostPath;
  String? lastPutPath;
  dynamic lastPostData;
  dynamic lastPutData;
  bool shouldThrowError = false;

  Map<String, dynamic>? mockWalletResponse;
  Map<String, dynamic>? mockTodayStepsResponse;

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    getCalled = true;
    lastGetPath = path;
    dynamic returnData = {};

    if (shouldThrowError) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 500,
          statusMessage: 'Internal Server Error',
        ),
      );
    }

    if (path == '/steps/today') {
      returnData = mockTodayStepsResponse ?? {
        'stepCount': 4000,
        'caloriesBurned': 180,
        'distanceKm': 3.0,
        'activeMinutes': 40,
        'goal': 10000,
        'progress': 40,
        'goalReached': false,
      };
    } else if (path == '/rewards/streak') {
      returnData = {
        'currentStreak': 5,
        'longestStreak': 10,
        'nextMilestone': 7,
        'daysToMilestone': 2,
      };
    } else if (path == '/rewards/wallet') {
      returnData = mockWalletResponse ?? {
        'balance': 300,
        'lifetimePoints': 6000,
        'monthlyXp': 500,
      };
    } else if (path == '/steps/weekly') {
      returnData = {
        'dailyBreakdown': [
          {'date': '2025-06-01T00:00:00.000Z', 'stepCount': 4000}
        ],
      };
    } else if (path == '/users/me') {
      returnData = {
        'id': 'u1',
        'name': 'Alice',
        'email': 'alice@example.com',
      };
    } else if (path == '/users/me/stats') {
      returnData = {
        'totalDays': 30,
      };
    }

    return Response(
      requestOptions: RequestOptions(path: path),
      data: returnData,
      statusCode: 200,
    );
  }

  @override
  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    postCalled = true;
    lastPostPath = path;
    lastPostData = data;

    if (shouldThrowError) {
      throw DioException(requestOptions: RequestOptions(path: path));
    }

    return Response(
      requestOptions: RequestOptions(path: path),
      data: {},
      statusCode: 200,
    );
  }

  @override
  Future<Response<dynamic>> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    putCalled = true;
    lastPutPath = path;
    lastPutData = data;

    if (shouldThrowError) {
      throw DioException(requestOptions: RequestOptions(path: path));
    }

    return Response(
      requestOptions: RequestOptions(path: path),
      data: {},
      statusCode: 200,
    );
  }
}

class MockHealthService implements HealthService {
  bool requestAuthCalled = false;
  bool getStepHistoryCalled = false;
  bool getTodayStepsCalled = false;
  bool shouldAuthorize = true;
  int mockSteps = 4000;
  Map<DateTime, int> mockStepHistory = {};

  @override
  Future<bool> requestAuthorization() async {
    requestAuthCalled = true;
    return shouldAuthorize;
  }

  @override
  Future<Map<DateTime, int>> getStepHistory(int days) async {
    getStepHistoryCalled = true;
    return mockStepHistory;
  }

  @override
  Future<int> getTodaySteps() async {
    getTodayStepsCalled = true;
    return mockSteps;
  }

  @override
  Future<List<HealthDataPoint>> getRecentWorkouts(int days) async => [];
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Path provider mock returning unique temp directory
    final temp = await Directory.systemTemp.createTemp();
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async => temp.path,
    );

    // Mock SafeDevice MethodChannel
    const safeDeviceChannel = MethodChannel('safe_device');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      safeDeviceChannel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'isJailBroken') return false;
        if (methodCall.method == 'isRealDevice') return true;
        if (methodCall.method == 'isMockLocation') return false;
        return false;
      },
    );

    // Mock permissions MethodChannel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (MethodCall methodCall) async => {19: 1}, // ACTIVITY_RECOGNITION granted
    );

    Hive.init(temp.path);
    if (!Hive.isBoxOpen('wellnex_storage')) {
      await StorageService.init();
    }
  });

  group('DashboardState', () {
    test('initializes with correct defaults', () {
      final state = DashboardState();
      
      expect(state.isLoading, false);
      expect(state.weeklyHistory, isEmpty);
      expect(state.xpLevel, 1);
      expect(state.xpCurrentProgress, 0);
      expect(state.xpToNextLevel, 1000);
      expect(state.sensorStepsToday, 0);
      expect(state.healthAuthorized, false);
    });

    test('copyWith updates fields correctly', () {
      final state = DashboardState().copyWith(
        isLoading: true,
        xpLevel: 5,
        syncStatus: SyncStatus.synced,
        healthAuthorized: true,
      );
      
      expect(state.isLoading, true);
      expect(state.xpLevel, 5);
      expect(state.syncStatus, SyncStatus.synced);
      expect(state.healthAuthorized, true);
      // Ensure others are unchanged
      expect(state.xpCurrentProgress, 0);
    });
  });

  group('TodaySteps', () {
    test('fromJson parses correctly', () {
      final json = {
        'stepCount': 5000,
        'caloriesBurned': 250,
        'distanceKm': 3.5,
        'activeMinutes': 45,
        'goal': 10000,
        'progress': 50,
        'goalReached': false,
      };

      final steps = TodaySteps.fromJson(json);

      expect(steps.stepCount, 5000);
      expect(steps.caloriesBurned, 250);
      expect(steps.distanceKm, 3.5);
      expect(steps.activeMinutes, 45);
      expect(steps.goal, 10000);
      expect(steps.progress, 50);
      expect(steps.goalReached, false);
    });

    test('copyWith updates fields correctly', () {
      final initial = TodaySteps(
        stepCount: 100,
        caloriesBurned: 10,
        distanceKm: 0.1,
        activeMinutes: 1,
        goal: 10000,
        progress: 1,
        goalReached: false,
      );

      final updated = initial.copyWith(stepCount: 200, progress: 2);
      
      expect(updated.stepCount, 200);
      expect(updated.progress, 2);
      expect(updated.goal, 10000); // Unchanged
    });
  });

  group('StreakInfo', () {
    test('fromJson parses correctly', () {
      final json = {
        'currentStreak': 5,
        'longestStreak': 10,
        'nextMilestone': 7,
        'daysToMilestone': 2,
      };

      final streak = StreakInfo.fromJson(json);

      expect(streak.currentStreak, 5);
      expect(streak.longestStreak, 10);
      expect(streak.nextMilestone, 7);
      expect(streak.daysToMilestone, 2);
    });
  });

  group('WalletInfo', () {
    test('fromJson parses correctly', () {
      final json = {
        'balance': 1500,
        'lifetimePoints': 5000,
        'monthlyXp': 1000,
      };

      final wallet = WalletInfo.fromJson(json);

      expect(wallet.balance, 1500);
      expect(wallet.lifetimePoints, 5000);
      expect(wallet.monthlyXp, 1000);
    });
  });

  group('DashboardNotifier Tests', () {
    late MockApiService mockApiService;
    late MockHealthService mockHealthService;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({'device_uuid': 'test-uuid'});
      mockApiService = MockApiService();
      mockHealthService = MockHealthService();
    });

    testWidgets('DashboardNotifier loads user data and fetches stats successfully', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await StorageService.saveUser({'id': 'u1', 'name': 'Alice'});

        final container = ProviderContainer(
          overrides: [
            apiServiceProvider.overrideWithValue(mockApiService),
            healthServiceProvider.overrideWithValue(mockHealthService),
          ],
        );

        final notifier = container.read(dashboardProvider.notifier);
        final subscription = container.listen(dashboardProvider, (_, __) {});

        // Verify initialization calls
        expect(notifier.state.user != null, isTrue);
        expect(notifier.state.user!['name'], equals('Alice'));

        // Run fetchTodayData
        await notifier.fetchTodayData();

        // Verify that all GET APIs were called
        expect(mockApiService.getCalled, isTrue);
        expect(notifier.state.todaySteps != null, isTrue);
        expect(notifier.state.todaySteps!.stepCount, equals(4000));
        expect(notifier.state.streak != null, isTrue);
        expect(notifier.state.streak!.currentStreak, equals(5));
        expect(notifier.state.wallet != null, isTrue);
        expect(notifier.state.wallet!.balance, equals(300));
        expect(notifier.state.weeklyHistory.isNotEmpty, isTrue);

        // Verify XP calculations
        expect(notifier.state.xpLevel, equals(1)); // 500 XP is Level 1

        container.dispose();
      });
    });

    testWidgets('DashboardNotifier syncSteps respects max cap and cadence checks', (WidgetTester tester) async {
      await tester.runAsync(() async {
        final container = ProviderContainer(
          overrides: [
            apiServiceProvider.overrideWithValue(mockApiService),
            healthServiceProvider.overrideWithValue(mockHealthService),
          ],
        );

        final notifier = container.read(dashboardProvider.notifier);
        final subscription = container.listen(dashboardProvider, (_, __) {});
        await notifier.fetchTodayData();

        // 1. Test optimistic UI updates and backend sync
        mockApiService.postCalled = false;
        await notifier.syncSteps(8000);
        expect(notifier.state.todaySteps!.stepCount, equals(8000));
        expect(mockApiService.postCalled, isTrue);
        expect(mockApiService.lastPostPath, equals('/steps/sync'));
        expect(mockApiService.lastPostData['stepCount'], equals(8000));

        // 2. Test clamping stepCount above max cap of 50000
        mockApiService.postCalled = false;
        await notifier.syncSteps(60000);
        expect(notifier.state.todaySteps!.stepCount, equals(50000));
        expect(mockApiService.lastPostData['stepCount'], equals(50000));

        container.dispose();
      });
    });

    testWidgets('DashboardNotifier updateDailyGoal updates goal successfully', (WidgetTester tester) async {
      await tester.runAsync(() async {
        final container = ProviderContainer(
          overrides: [
            apiServiceProvider.overrideWithValue(mockApiService),
            healthServiceProvider.overrideWithValue(mockHealthService),
          ],
        );

        final notifier = container.read(dashboardProvider.notifier);
        final subscription = container.listen(dashboardProvider, (_, __) {});
        await notifier.fetchTodayData();

        mockApiService.putCalled = false;
        await notifier.updateDailyGoal(12000);

        expect(notifier.state.todaySteps!.goal, equals(12000));
        expect(mockApiService.putCalled, isTrue);
        expect(mockApiService.lastPutPath, equals('/users/me'));
        expect(mockApiService.lastPutData['dailyStepGoal'], equals(12000));

        container.dispose();
      });
    });

    testWidgets('DashboardNotifier handles didChangeAppLifecycleState resumed', (WidgetTester tester) async {
      await tester.runAsync(() async {
        final container = ProviderContainer(
          overrides: [
            apiServiceProvider.overrideWithValue(mockApiService),
            healthServiceProvider.overrideWithValue(mockHealthService),
          ],
        );

        final notifier = container.read(dashboardProvider.notifier);
        final subscription = container.listen(dashboardProvider, (_, __) {});
        mockApiService.getCalled = false;

        // Call lifecyle state change
        notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);
        
        // Wait a short time for async tasks to execute on real loop
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify app triggers data sync
        expect(mockApiService.getCalled, isTrue);

        container.dispose();
      });
    });

    testWidgets('DashboardNotifier calculates XP levels correctly', (WidgetTester tester) async {
      await tester.runAsync(() async {
        final container = ProviderContainer(
          overrides: [
            apiServiceProvider.overrideWithValue(mockApiService),
            healthServiceProvider.overrideWithValue(mockHealthService),
          ],
        );

        final notifier = container.read(dashboardProvider.notifier);
        final subscription = container.listen(dashboardProvider, (_, __) {});

        // Mock wallet with 2800 XP to execute deep level calculations
        mockApiService.mockWalletResponse = {
          'balance': 300,
          'lifetimePoints': 6000,
          'monthlyXp': 2800,
        };

        await notifier.fetchTodayData();
        
        // Level 1: 0-999, Level 2: 1000-2499 (1500 XP range), Level 3: 2500+ (2000 XP range)
        // 2800 monthlyXp should place Alice in Level 3
        expect(notifier.state.xpLevel, equals(3));

        container.dispose();
      });
    });

    testWidgets('DashboardNotifier cadence speed check limits step injecting hacks', (WidgetTester tester) async {
      await tester.runAsync(() async {
        final container = ProviderContainer(
          overrides: [
            apiServiceProvider.overrideWithValue(mockApiService),
            healthServiceProvider.overrideWithValue(mockHealthService),
          ],
        );

        final notifier = container.read(dashboardProvider.notifier);
        final subscription = container.listen(dashboardProvider, (_, __) {});
        
        mockApiService.mockTodayStepsResponse = {
          'stepCount': 500,
          'caloriesBurned': 20,
          'distanceKm': 0.3,
          'activeMinutes': 5,
          'goal': 10000,
          'progress': 5,
          'goalReached': false,
        };

        await notifier.fetchTodayData();

        // Sync first time to baseline
        await notifier.syncSteps(1000);
        expect(notifier.state.todaySteps!.stepCount, 1000);

        // Advance time by 2 seconds
        await Future.delayed(const Duration(seconds: 2));

        // Inject a massive step difference (e.g. 50000 steps within 2s => 24500 steps/sec)
        await notifier.syncSteps(50000);

        // Allowed increase is 2s * 50.0 steps/sec = 100 steps. Clamped to 1100.
        expect(notifier.state.todaySteps!.stepCount, 1100);

        container.dispose();
      });
    });

    testWidgets('DashboardNotifier Health API step sync via periodic timer', (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          apiServiceProvider.overrideWithValue(mockApiService),
          healthServiceProvider.overrideWithValue(mockHealthService),
        ],
      );

      final notifier = container.read(dashboardProvider.notifier);
      final subscription = container.listen(dashboardProvider, (_, __) {});

      mockHealthService.mockSteps = 7000;
      mockHealthService.shouldAuthorize = true;
      notifier.state = notifier.state.copyWith(
        healthAuthorized: true,
        todaySteps: TodaySteps(
          stepCount: 100,
          caloriesBurned: 1,
          distanceKm: 0.1,
          activeMinutes: 1,
          goal: 10000,
          progress: 1,
          goalReached: false,
        ),
      );

      // Advance time by 16 seconds to trigger periodic timer (runs every 15s)
      await tester.pump(const Duration(seconds: 16));

      // Verify HealthService was queried and state synchronized
      expect(notifier.state.todaySteps!.stepCount, equals(7000));

      container.dispose();
    });

    testWidgets('DashboardNotifier handles step history auto-sync', (WidgetTester tester) async {
      await tester.runAsync(() async {
        final container = ProviderContainer(
          overrides: [
            apiServiceProvider.overrideWithValue(mockApiService),
            healthServiceProvider.overrideWithValue(mockHealthService),
          ],
        );

        final notifier = container.read(dashboardProvider.notifier);
        final subscription = container.listen(dashboardProvider, (_, __) {});

        // Configure history values
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        mockHealthService.mockStepHistory = {
          yesterday: 8000,
        };
        mockHealthService.shouldAuthorize = true;

        mockApiService.postCalled = false;
        await notifier.fetchTodayData();

        // Verify API was called to sync the historical steps
        expect(mockApiService.postCalled, isTrue);

        container.dispose();
      });
    });

    testWidgets('DashboardNotifier handles API and synchronization errors gracefully', (WidgetTester tester) async {
      await tester.runAsync(() async {
        final container = ProviderContainer(
          overrides: [
            apiServiceProvider.overrideWithValue(mockApiService),
            healthServiceProvider.overrideWithValue(mockHealthService),
          ],
        );

        final notifier = container.read(dashboardProvider.notifier);
        final subscription = container.listen(dashboardProvider, (_, __) {});

        // Force APIs to fail
        mockApiService.shouldThrowError = true;

        await notifier.fetchTodayData();

        // Verify loading state is turned off and error message is populated
        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.syncStatus, SyncStatus.failed);
        expect(notifier.state.error, isNotNull);

        container.dispose();
      });
    });
  });
}
