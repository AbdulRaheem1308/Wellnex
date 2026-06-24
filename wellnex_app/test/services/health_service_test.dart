import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wellnex_app/services/health_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  setUpAll(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  tearDownAll(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('HealthService', () {
    late HealthService healthService;
    
    setUp(() {
      healthService = HealthService();
      
      // Mock the method channel for flutter_health
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_health'), (MethodCall methodCall) async {
        if (methodCall.method == 'requestAuthorization') {
          return true;
        } else if (methodCall.method == 'getTotalStepsInInterval') {
          return 5000;
        } else if (methodCall.method == 'getHealthDataFromTypes') {
          return [];
        } else if (methodCall.method == 'getHealthConnectSdkStatus') {
          return 3; // sdkAvailable
        } else if (methodCall.method == 'hasPermissions') {
          return true;
        }
        return null;
      });

      // Mock device_info_plus channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/device_info'), (MethodCall methodCall) async {
        if (methodCall.method == 'getDeviceInfo') {
          return {
            'id': 'test_device_id', // For Android
            // For iOS
            'name': 'Test Device',
            'systemName': 'iOS',
            'systemVersion': '15.0',
            'model': 'iPhone',
            'modelName': 'iPhone 13',
            'localizedModel': 'iPhone',
            'identifierForVendor': 'test_vendor_id',
            'isPhysicalDevice': true,
            'freeDiskSize': 10000000,
            'totalDiskSize': 20000000,
            'physicalRamSize': 4000000,
            'availableRamSize': 2000000,
            'isiOSAppOnMac': false,
            'isiOSAppOnVision': false,
            'utsname': {
              'sysname': 'Darwin',
              'nodename': 'test',
              'release': '20.0.0',
              'version': '1',
              'machine': 'iPhone10,1'
            }
          };
        }
        return null;
      });
      
      // Mock permission_handler channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter.baseflow.com/permissions/methods'), (MethodCall methodCall) async {
        if (methodCall.method == 'requestPermissions') {
          final List<dynamic> args = methodCall.arguments as List<dynamic>;
          final Map<int, int> result = {};
          for (var item in args) {
            result[item as int] = 1; // 1 means granted
          }
          return result;
        } else if (methodCall.method == 'checkPermissionStatus') {
          return 1; // granted
        }
        return null;
      });
    });
    
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_health'), null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter.baseflow.com/permissions/methods'), null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/device_info'), null);
    });

    test('requestAuthorization succeeds', () async {
      final result = await healthService.requestAuthorization();
      expect(result, isTrue);
    });

    test('getTodaySteps returns mocked steps', () async {
      final steps = await healthService.getTodaySteps();
      expect(steps, 5000);
    });

    test('getStepHistory returns map of mocked steps', () async {
      final history = await healthService.getStepHistory(3);
      expect(history.length, 3);
      expect(history.values.first, 5000);
    });

    test('getRecentWorkouts returns mocked workouts', () async {
      final workouts = await healthService.getRecentWorkouts(3);
      expect(workouts, isEmpty);
    });
    
    test('requestAuthorization handles exceptions gracefully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_health'), (MethodCall methodCall) async {
        throw Exception('Mock Error');
      });
      final result = await healthService.requestAuthorization();
      expect(result, isFalse);
    });

    test('getTodaySteps handles exceptions gracefully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_health'), (MethodCall methodCall) async {
        throw Exception('Mock Error');
      });
      final steps = await healthService.getTodaySteps();
      expect(steps, 0);
    });

    test('getRecentWorkouts handles exceptions gracefully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_health'), (MethodCall methodCall) async {
        throw Exception('Mock Error');
      });
      final workouts = await healthService.getRecentWorkouts(3);
      expect(workouts, isEmpty);
    });
  });
}
