import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:wellnex_app/core/services/background_service.dart';
import 'package:wellnex_app/services/storage_service.dart';
import 'package:wellnex_app/services/api_service.dart';
import 'package:wellnex_app/services/health_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

class MockApiService implements ApiService {
  final Future<Response> Function(String)? onGet;
  final Future<Response> Function(String, dynamic)? onPost;

  MockApiService({this.onGet, this.onPost});

  @override
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken, void Function(int, int)? onReceiveProgress}) async {
    if (onGet != null) return onGet!(path);
    return Response(requestOptions: RequestOptions(path: path), data: null);
  }

  @override
  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken, void Function(int, int)? onSendProgress, void Function(int, int)? onReceiveProgress}) async {
    if (onPost != null) return onPost!(path, data);
    return Response(requestOptions: RequestOptions(path: path), data: null);
  }
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHealthService implements HealthService {
  final Future<bool> Function()? onRequestAuth;
  final Future<int> Function()? onGetSteps;

  MockHealthService({this.onRequestAuth, this.onGetSteps});

  @override
  Future<bool> requestAuthorization() async {
    if (onRequestAuth != null) return onRequestAuth!();
    return true;
  }

  @override
  Future<int> getTodaySteps() async {
    if (onGetSteps != null) return onGetSteps!();
    return 1000;
  }
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory tempDir;
  bool secureStorageHasToken = true;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('background_service_test_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async => tempDir.path,
    );
    const secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      secureStorageChannel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'read' && methodCall.arguments['key'] == 'access_token') {
          return secureStorageHasToken ? 'fake_token' : null;
        }
        return null;
      },
    );
    
    // Mock SafeDevice MethodChannel
    const safeDeviceChannel = MethodChannel('safe_device');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      safeDeviceChannel,
      (MethodCall methodCall) async {
        return false;
      },
    );

    // Mock Workmanager MethodChannel
    const workmanagerChannel = MethodChannel('be.tramckrijte.workmanager/workmanager');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      workmanagerChannel,
      (MethodCall methodCall) async {
        return true;
      },
    );

    // Mock shared_preferences
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    secureStorageHasToken = true;
    BackgroundService.initialized = false;
    await Hive.initFlutter(tempDir.path);
    await StorageService.init();
  });

  group('BackgroundService', () {
    test('init executes cleanly', () async {
      await expectLater(BackgroundService.init(), completes);
      // Double init returns early
      await expectLater(BackgroundService.init(), completes);
    });

    test('registerPeriodicTask executes cleanly', () async {
      await expectLater(BackgroundService.registerPeriodicTask(), completes);
    });

    test('cancelTask executes cleanly', () async {
      await expectLater(BackgroundService.cancelTask(), completes);
    });

    test('callbackDispatcher executes cleanly', () {
      expect(() => callbackDispatcher(), returnsNormally);
    });

    test('runBackgroundSyncTask - skips if no token', () async {
      secureStorageHasToken = false;
      final res = await BackgroundService.runBackgroundSyncTask(kBackgroundSyncTask);
      expect(res, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('bg_sync_status'), 'Skipped: No access token found');
    });

    test('runBackgroundSyncTask - phone device missing, attempts register', () async {
      final mockApi = MockApiService(
        onGet: (path) async {
          if (path == '/devices') {
            return Response(requestOptions: RequestOptions(path: path), data: [
              {'type': 'OTHER', 'identifier': '123'}
            ]);
          }
          throw Exception('Unexpected get');
        },
        onPost: (path, data) async {
          return Response(requestOptions: RequestOptions(path: path), data: null);
        }
      );
      
      final mockHealth = MockHealthService();
      
      final res = await BackgroundService.runBackgroundSyncTask(
        kBackgroundSyncTask,
        apiServiceOverride: mockApi,
        healthServiceOverride: mockHealth,
      );
      expect(res, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('bg_sync_status'), contains('Success: Synced 1000 steps'));
    });

    test('runBackgroundSyncTask - phone device already registered', () async {
      final deviceUUID = await StorageService.getOrCreateDeviceUUID();
      final mockApi = MockApiService(
        onGet: (path) async {
          if (path == '/devices') {
            return Response(requestOptions: RequestOptions(path: path), data: [
              {'type': 'PHONE', 'identifier': deviceUUID}
            ]);
          }
          throw Exception('Unexpected get');
        },
        onPost: (path, data) async {
          return Response(requestOptions: RequestOptions(path: path), data: null);
        }
      );
      
      final mockHealth = MockHealthService();
      
      final res = await BackgroundService.runBackgroundSyncTask(
        kBackgroundSyncTask,
        apiServiceOverride: mockApi,
        healthServiceOverride: mockHealth,
      );
      expect(res, isTrue);
    });

    test('runBackgroundSyncTask - api get device fails gracefully', () async {
      final mockApi = MockApiService(
        onGet: (path) async => throw Exception('API GET error'),
        onPost: (path, data) async => Response(requestOptions: RequestOptions(path: path)),
      );
      final res = await BackgroundService.runBackgroundSyncTask(
        kBackgroundSyncTask,
        apiServiceOverride: mockApi,
        healthServiceOverride: MockHealthService(),
      );
      expect(res, isTrue);
    });

    test('runBackgroundSyncTask - health api requestAuthorization returns false', () async {
      final mockHealth = MockHealthService(onRequestAuth: () async => false);
      final res = await BackgroundService.runBackgroundSyncTask(
        kBackgroundSyncTask,
        apiServiceOverride: MockApiService(onGet: (path) async => Response(requestOptions: RequestOptions(path: path))),
        healthServiceOverride: mockHealth,
      );
      expect(res, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('bg_sync_status'), 'Skipped: Health API returned 0 (permission may be pending)');
    });

    test('runBackgroundSyncTask - health api throws gracefully', () async {
      final mockHealth = MockHealthService(onRequestAuth: () async => throw Exception('Health auth error'));
      final res = await BackgroundService.runBackgroundSyncTask(
        kBackgroundSyncTask,
        apiServiceOverride: MockApiService(onGet: (path) async => Response(requestOptions: RequestOptions(path: path))),
        healthServiceOverride: mockHealth,
      );
      expect(res, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('bg_sync_status'), 'Skipped: Health API returned 0 (permission may be pending)');
    });

    test('runBackgroundSyncTask - steps sync api throws gracefully', () async {
      final mockApi = MockApiService(
        onGet: (path) async => Response(requestOptions: RequestOptions(path: path), data: []),
        onPost: (path, data) async {
          if (path == '/steps/sync') throw Exception('Sync post error');
          return Response(requestOptions: RequestOptions(path: path));
        }
      );
      final res = await BackgroundService.runBackgroundSyncTask(
        kBackgroundSyncTask,
        apiServiceOverride: mockApi,
        healthServiceOverride: MockHealthService(),
      );
      expect(res, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('bg_sync_status'), contains('API Error: Exception: Sync post error'));
    });

    test('runBackgroundSyncTask - fatal error caught', () async {
      final res = await BackgroundService.runBackgroundSyncTask('force_fatal_error');
      expect(res, isFalse);
    });
    
    test('runBackgroundSyncTask - defaults instantiated if null', () async {
      secureStorageHasToken = true;
      // It will use ApiService() and HealthService() defaults and fail gracefully in GET /devices because no real HTTP mock server
      final res = await BackgroundService.runBackgroundSyncTask(kBackgroundSyncTask);
      expect(res, isTrue);
    });
  });

  tearDownAll(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });
}
