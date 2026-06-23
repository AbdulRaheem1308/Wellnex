import 'package:flutter_test/flutter_test.dart';
import 'package:wellnex_app/features/devices/presentation/providers/device_provider.dart';
import 'package:wellnex_app/services/api_service.dart';
import 'package:wellnex_app/services/health_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:dio/dio.dart';
import 'package:health/health.dart';

class MockApiService implements ApiService {
  List<dynamic> mockDevicesResponse = [];
  bool shouldThrowError = false;
  bool shouldThrowOnPost = false;
  Map<String, dynamic> lastPostData = {};
  String lastDeletedId = '';

  @override
  Future<void> Function()? onAuthFailure;

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    if (shouldThrowError) throw Exception('API Error');
    return Response(
      requestOptions: RequestOptions(path: path, queryParameters: queryParameters),
      data: mockDevicesResponse,
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
    if (shouldThrowError || shouldThrowOnPost) throw Exception('API Error');
    lastPostData = data ?? {};
    if (path == '/devices') {
      mockDevicesResponse.add({
        'id': 'new_id',
        'name': data['name'],
        'type': data['type'],
      });
    }
    return Response(
      requestOptions: RequestOptions(path: path, queryParameters: queryParameters, data: data),
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
    return Response(
      requestOptions: RequestOptions(path: path, queryParameters: queryParameters, data: data),
      data: {},
      statusCode: 200,
    );
  }

  @override
  Future<Response<dynamic>> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: path, queryParameters: queryParameters, data: data),
      data: {},
      statusCode: 200,
    );
  }

  @override
  Future<Response<dynamic>> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    if (shouldThrowError) throw Exception('API Error');
    lastDeletedId = path.split('/').last;
    mockDevicesResponse.removeWhere((d) => d['id'] == lastDeletedId);
    return Response(
      requestOptions: RequestOptions(path: path, queryParameters: queryParameters, data: data),
      data: {},
      statusCode: 200,
    );
  }

  @override
  Future<void> testOnRequest(RequestOptions options, RequestInterceptorHandler handler) async {}

  @override
  void testOnResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {}

  @override
  Future<void> testOnError(DioException error, ErrorInterceptorHandler handler) async {}

  @override
  Future<void> testHandleAuthFailure() async {}

  @override
  Future<bool> testRefreshToken() async => true;
}

class MockHealthService implements HealthService {
  bool shouldAuthorize = true;
  bool shouldThrowError = false;
  int mockSteps = 5000;

  @override
  Future<bool> requestAuthorization() async {
    if (shouldThrowError) throw Exception('Health Error');
    return shouldAuthorize;
  }

  @override
  Future<int> getTodaySteps() async {
    if (shouldThrowError) throw Exception('Health Error');
    return mockSteps;
  }

  @override
  Future<Map<DateTime, int>> getStepHistory(int days) async {
    return {};
  }

  @override
  Future<List<HealthDataPoint>> getRecentWorkouts(int days) async {
    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockApiService mockApiService;
  late MockHealthService mockHealthService;
  late DeviceNotifier notifier;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'device_uuid': 'test-uuid'});
    mockApiService = MockApiService();
    mockHealthService = MockHealthService();
  });

  DeviceNotifier createNotifier() {
    return DeviceNotifier(mockApiService, mockHealthService);
  }

  group('ConnectedDevice model', () {
    test('fromJson and copyWith works correctly', () {
      final json = {
        'id': 'd1',
        'name': 'Fitbit Sense',
        'type': 'FITBIT',
        'lastSyncedAt': '2026-05-26T12:00:00Z',
      };

      final device = ConnectedDevice.fromJson(json);
      expect(device.id, 'd1');
      expect(device.name, 'Fitbit Sense');
      expect(device.type, 'FITBIT');
      expect(device.status, SyncStatus.connected);

      final copied = device.copyWith(status: SyncStatus.disconnected);
      expect(copied.status, SyncStatus.disconnected);
      expect(copied.id, 'd1');
    });

    test('brand mappings return correct values', () {
      expect(ConnectedDevice(id: '1', name: 'N', type: 'WATCH_APPLE').brand, 'Apple');
      expect(ConnectedDevice(id: '1', name: 'N', type: 'WATCH_ANDROID').brand, 'Google');
      expect(ConnectedDevice(id: '1', name: 'N', type: 'FITBIT').brand, 'Fitbit');
      expect(ConnectedDevice(id: '1', name: 'N', type: 'GARMIN').brand, 'Garmin');
      expect(ConnectedDevice(id: '1', name: 'N', type: 'PHONE').brand, 'Phone');
      expect(ConnectedDevice(id: '1', name: 'N', type: 'OTHER').brand, 'Other');
    });
  });

  group('DeviceState', () {
    test('copyWith updates state correctly', () {
      final state = DeviceState(isScanning: false, isLoading: false);
      final updated = state.copyWith(isScanning: true, error: 'Scanning failed');
      expect(updated.isScanning, true);
      expect(updated.error, 'Scanning failed');

      final cleared = updated.copyWith(clearError: true);
      expect(cleared.error, isNull);
    });
  });

  group('DeviceNotifier Tests', () {
    test('loadDevices populates devices list', () async {
      mockApiService.mockDevicesResponse = [
        {'id': '1', 'name': 'Test Watch', 'type': 'WATCH_APPLE', 'lastSyncedAt': '2026-05-26T10:00:00Z'}
      ];
      notifier = createNotifier();
      await Future.delayed(Duration.zero); // allow loadDevices to complete

      expect(notifier.state.devices.length, 2); // 1 mock + 1 auto-registered phone
      expect(notifier.state.devices.first.name, 'Test Watch');
      expect(notifier.state.devices.first.status, SyncStatus.connected);
    });

    test('loadDevices handles auto-register failure gracefully', () async {
      mockApiService.mockDevicesResponse = [];
      mockApiService.shouldThrowOnPost = true; // throw on auto-register post

      notifier = createNotifier();
      await Future.delayed(Duration.zero);

      // Verify list only has items fetched successfully (empty since none)
      expect(notifier.state.devices.isEmpty, true);
    });

    test('connectHealthDevice adds a device when authorized', () async {
      notifier = createNotifier();
      await Future.delayed(Duration.zero);
      
      mockHealthService.shouldAuthorize = true;
      await notifier.connectHealthDevice();
      
      expect(notifier.state.devices.any((d) => d.type == 'WATCH_APPLE' || d.type == 'WATCH_ANDROID'), true);
      expect(notifier.state.error, isNull);
    });

    test('connectHealthDevice sets error when not authorized', () async {
      notifier = createNotifier();
      await Future.delayed(Duration.zero);
      
      mockHealthService.shouldAuthorize = false;
      await notifier.connectHealthDevice();
      
      expect(notifier.state.error, 'Permission denied');
    });

    test('connectHealthDevice handles exceptions during authorization', () async {
      notifier = createNotifier();
      await Future.delayed(Duration.zero);
      
      mockHealthService.shouldThrowError = true;
      await notifier.connectHealthDevice();
      
      expect(notifier.state.error, contains('Health Error'));
    });

    test('syncDevice updates device sync status and steps', () async {
      mockApiService.mockDevicesResponse = [
        {'id': '1', 'name': 'Test Watch', 'type': 'WATCH_APPLE'}
      ];
      notifier = createNotifier();
      await Future.delayed(Duration.zero);

      await notifier.syncDevice('1');

      final updatedDevice = notifier.state.devices.firstWhere((d) => d.id == '1');
      expect(updatedDevice.status, SyncStatus.connected);
      expect(updatedDevice.syncedSteps, 5000);
      expect(updatedDevice.lastSyncTime, isNotNull);
    });

    test('syncDevice returns early for unsupported devices', () async {
      mockApiService.mockDevicesResponse = [
        {'id': '1', 'name': 'Fitbit Watch', 'type': 'FITBIT'}
      ];
      notifier = createNotifier();
      await Future.delayed(Duration.zero);

      await notifier.syncDevice('1');

      // Status should remain disconnected since sync returns early
      final device = notifier.state.devices.firstWhere((d) => d.id == '1');
      expect(device.status, SyncStatus.disconnected);
    });

    test('syncDevice handles API/Health errors gracefully', () async {
      mockApiService.mockDevicesResponse = [
        {'id': '1', 'name': 'Test Watch', 'type': 'WATCH_APPLE'}
      ];
      notifier = createNotifier();
      await Future.delayed(Duration.zero);

      mockApiService.shouldThrowError = true;
      await notifier.syncDevice('1');

      final device = notifier.state.devices.firstWhere((d) => d.id == '1');
      expect(device.status, SyncStatus.error);
      expect(notifier.state.error, contains('API Error'));
    });

    test('addDevice sets error if device already exists', () async {
      mockApiService.mockDevicesResponse = [
        {'id': '1', 'name': 'Apple Health', 'type': 'WATCH_APPLE'}
      ];
      notifier = createNotifier();
      await Future.delayed(Duration.zero);

      await notifier.addDevice('Apple Health 2', 'WATCH_APPLE');
      expect(notifier.state.error, 'Device is already connected');
    });

    test('addDevice handles API connection error gracefully', () async {
      notifier = createNotifier();
      await Future.delayed(Duration.zero);

      mockApiService.shouldThrowError = true;
      await notifier.addDevice('Apple Health', 'WATCH_APPLE');
      
      expect(notifier.state.error, contains('API Error'));
    });

    test('removeDevice deletes a device and reloads list', () async {
      mockApiService.mockDevicesResponse = [
        {'id': '1', 'name': 'Test Watch', 'type': 'WATCH_APPLE'}
      ];
      notifier = createNotifier();
      await Future.delayed(Duration.zero);
      
      expect(notifier.state.devices.any((d) => d.id == '1'), true);

      await notifier.removeDevice('1');
      
      expect(notifier.state.devices.any((d) => d.id == '1'), false);
    });

    test('removeDevice handles exceptions gracefully', () async {
      mockApiService.mockDevicesResponse = [
        {'id': '1', 'name': 'Test Watch', 'type': 'WATCH_APPLE'}
      ];
      notifier = createNotifier();
      await Future.delayed(Duration.zero);

      mockApiService.shouldThrowError = true;
      await notifier.removeDevice('1');
      
      expect(notifier.state.error, contains('API Error'));
    });
  });
}
