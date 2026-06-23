import 'package:workmanager/workmanager.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../../services/health_service.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import 'package:uuid/uuid.dart';
import 'package:safe_device/safe_device.dart';

const String kBackgroundSyncTask = "wellnex.backgroundSync";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    return await BackgroundService.runBackgroundSyncTask(task);
  });
}

class BackgroundService {

  @visibleForTesting
  static Future<bool> runBackgroundSyncTask(String task) async {
    try {
      if (task == kBackgroundSyncTask) {
        // 0. Initialize Hive and StorageService inside the isolate environment
        await Hive.initFlutter();
        await StorageService.init();

        final prefs = await SharedPreferences.getInstance();
        final nowStr = DateTime.now().toIso8601String();
        await prefs.setString('bg_sync_last_run', nowStr);
        await prefs.setString('bg_sync_status', 'Running...');

        // 1. Get Token (Secure Storage works without init)
        final token = await StorageService.getAccessToken();
        
        if (token == null) {
          await prefs.setString('bg_sync_status', 'Skipped: No access token found');
          return true;
        }

        // 2. Initialize Services
        final apiService = ApiService(); 
        final healthService = HealthService();
        final deviceUUID = await StorageService.getOrCreateDeviceUUID();

        // 2.5 Ensure the physical phone device is registered in the backend
        try {
          final devicesResponse = await apiService.get('/devices');
          final devicesData = devicesResponse.data;
          if (devicesData is List) {
            final hasPhone = devicesData.any((d) => d is Map && d['type'] == 'PHONE' && d['identifier'] == deviceUUID);
            if (!hasPhone) {
              await apiService.post('/devices', data: {
                'name': 'Built-in Phone Sensors',
                'type': 'PHONE',
                'identifier': deviceUUID,
              });
              await prefs.setString('bg_sync_status', 'Registered phone device: $deviceUUID');
            }
          }
        } catch (deviceRegErr) {
          debugPrint("Background Sync Device Reg Error: $deviceRegErr");
        }

        // 3. Fetch Steps — Health API only (OS-managed, no baseline issues).
        // Health API reads the phone's built-in step counter chip via Google
        // Health Connect (Android) or Apple HealthKit (iOS). No external
        // device is required. External wearables (Fitbit, Apple Watch, etc.)
        // contribute additional data automatically if connected.
        int steps = 0;
        String source = 'BACKGROUND_HEALTH_API';

        try {
          final authorized = await healthService.requestAuthorization();
          if (authorized) {
            steps = await healthService.getTodaySteps();
          }
        } catch (e) {
          debugPrint("Background Sync Health API Error: $e");
        }

        if (steps == 0) {
          // Health API unavailable (permission not granted yet).
          // Skip sync — do not fall back to raw pedometer sensor to avoid
          // the cumulative-baseline bug that inflated step counts.
          await prefs.setString('bg_sync_status', 'Skipped: Health API returned 0 (permission may be pending)');
          return true;
        }

        // 4. Send to Backend
        try {
          final isJailBroken = await SafeDevice.isJailBroken;
          final isRealDevice = await SafeDevice.isRealDevice;
          final isMockLocation = await SafeDevice.isMockLocation;
          
          await apiService.post('/steps/sync', data: {
            'deviceIdentifier': deviceUUID,
            'stepCount': steps,
            'date': DateTime.now().toIso8601String().split('T')[0],
            'source': source,
            'nonce': const Uuid().v4(),
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'integrity': {
              'isJailBroken': isJailBroken,
              'isRealDevice': isRealDevice,
              'isMockLocation': isMockLocation,
            }
          });
          await prefs.setString('bg_sync_status', 'Success: Synced $steps steps via Health API');
        } catch (e) {
          debugPrint("Background Sync API Error: $e");
          await prefs.setString('bg_sync_status', 'API Error: $e');
        }
      }
    } catch (e) {
      debugPrint("Background Task Error: $e");
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('bg_sync_status', 'Fatal Error: $e');
      } catch (_) {}
      return false; // Task failed
    }

    return true;
  }

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) {
      _initialized = true;
      return;
    }
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
    _initialized = true;
  }

  static Future<void> registerPeriodicTask() async {
    await init();
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) return;
    
    await Workmanager().registerPeriodicTask(
      "wellnex_sync_job",
      kBackgroundSyncTask,
      frequency: const Duration(minutes: 15), // Android minimum
      constraints: Constraints(
        networkType: NetworkType.connected, 
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  static Future<void> cancelTask() async {
    await init();
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) return;
    
    await Workmanager().cancelAll();
  }
}
