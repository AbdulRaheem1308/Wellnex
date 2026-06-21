import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/api_service.dart';
import '../../../../services/health_service.dart';
import '../../../../services/storage_service.dart';
import 'package:flutter/foundation.dart';

enum SyncStatus { connected, syncing, error, disconnected }

class ConnectedDevice {
  final String id;
  final String name;
  final String type; // 'PHONE', 'WATCH_APPLE', 'WATCH_ANDROID', 'FITBIT', 'GARMIN'
  final String? identifier;
  final SyncStatus status;
  final DateTime? lastSyncTime;
  final int syncedSteps;

  ConnectedDevice({
    required this.id,
    required this.name,
    required this.type,
    this.identifier,
    this.status = SyncStatus.disconnected,
    this.lastSyncTime,
    this.syncedSteps = 0,
  });

  factory ConnectedDevice.fromJson(Map<String, dynamic> json) {
    return ConnectedDevice(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown Device',
      type: json['type'] ?? 'OTHER',
      identifier: json['identifier'],
      status: json['lastSyncedAt'] != null ? SyncStatus.connected : SyncStatus.disconnected,
      lastSyncTime: json['lastSyncedAt'] != null ? DateTime.parse(json['lastSyncedAt']) : null,
      syncedSteps: 0, // This would come from steps API
    );
  }

  ConnectedDevice copyWith({SyncStatus? status, DateTime? lastSyncTime, int? syncedSteps}) {
    return ConnectedDevice(
      id: id,
      name: name,
      type: type,
      identifier: identifier,
      status: status ?? this.status,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      syncedSteps: syncedSteps ?? this.syncedSteps,
    );
  }

  String get brand {
    switch (type) {
      case 'WATCH_APPLE': return 'Apple';
      case 'WATCH_ANDROID': return 'Google';
      case 'FITBIT': return 'Fitbit';
      case 'GARMIN': return 'Garmin';
      case 'PHONE': return 'Phone';
      default: return 'Other';
    }
  }
}

class DeviceState {
  final List<ConnectedDevice> devices;
  final bool isScanning;
  final bool isLoading;
  final String? error;

  DeviceState({
    this.devices = const [],
    this.isScanning = false,
    this.isLoading = false,
    this.error,
  });

  DeviceState copyWith({
    List<ConnectedDevice>? devices,
    bool? isScanning,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return DeviceState(
      devices: devices ?? this.devices,
      isScanning: isScanning ?? this.isScanning,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class DeviceNotifier extends StateNotifier<DeviceState> {
  final ApiService _apiService;
  final HealthService _healthService;

  DeviceNotifier(this._apiService, this._healthService) : super(DeviceState()) {
    loadDevices();
  }

  Future<void> loadDevices() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _apiService.get('/devices');
      var devices = (response.data as List)
          .map((json) => ConnectedDevice.fromJson(json))
          .toList();

      final deviceUUID = await StorageService.getOrCreateDeviceUUID();
      // Automatically register the user's physical phone built-in pedometer as a connected device if not already present
      final hasPhone = devices.any((d) => d.type == 'PHONE' && d.identifier == deviceUUID);
      if (!hasPhone) {
        try {
          await _apiService.post('/devices', data: {
            'name': 'Built-in Phone Sensors',
            'type': 'PHONE',
            'identifier': deviceUUID,
          });
          // Reload list to include the newly auto-registered phone device
          final reloadResponse = await _apiService.get('/devices');
          devices = (reloadResponse.data as List)
              .map((json) => ConnectedDevice.fromJson(json))
              .toList();
        } catch (addErr) {
          print('Auto-register phone device error: $addErr');
        }
      }

      state = state.copyWith(devices: devices, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: ApiError.from(e).message);
    }
  }

  /// connect to HealthKit or Google Fit
  Future<void> connectHealthDevice() async {
    // Clear previous errors so they can trigger again if the exact same error happens
    state = state.copyWith(isScanning: true, clearError: true);
    // Workaround for Riverpod state update delay to ensure error: null is registered before the actual error
    await Future.delayed(const Duration(milliseconds: 50));
    try {
      final authorized = await _healthService.requestAuthorization();
      if (authorized) {
        final String type = defaultTargetPlatform == TargetPlatform.iOS ? 'WATCH_APPLE' : 'WATCH_ANDROID';
        final String name = defaultTargetPlatform == TargetPlatform.iOS ? 'Apple Health' : 'Google Fit';
        
        // Add to backend
        await addDevice(name, type);
      } else {
        state = state.copyWith(error: 'Permission denied');
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isScanning: false);
    }
  }

  Future<void> syncDevice(String id) async {
    // 1. Find device
    final device = state.devices.firstWhere((d) => d.id == id);
    if (!['WATCH_APPLE', 'WATCH_ANDROID', 'PHONE'].contains(device.type)) {
       // Only handle local health/google fit/phone sensor sync here for now
       return; 
    }

    // Set status to syncing
    state = state.copyWith(
      devices: state.devices.map((d) => d.id == id ? d.copyWith(status: SyncStatus.syncing) : d).toList(),
    );

    try {
      // 2. Fetch data from HealthKit/Google Fit
      final todaySteps = await _healthService.getTodaySteps();
      final deviceUUID = await StorageService.getOrCreateDeviceUUID();
      
      // 3. Send to backend
      await _apiService.post('/steps/sync', data: {
        'deviceIdentifier': deviceUUID,
        'stepCount': todaySteps,
        'date': DateTime.now().toIso8601String().split('T')[0],
        'source': device.type == 'WATCH_APPLE' ? 'apple_health' : 'google_fit',
      });
      
      // 4. Update device status
      // We also update the device "last synced" timestamp in backend
      await _apiService.post('/devices/$id/sync');

      await loadDevices(); // Reload to get updated status
      
      // Update local state immediately for better UX
      state = state.copyWith(
        devices: state.devices.map((d) => d.id == id ? d.copyWith(
          status: SyncStatus.connected,
          lastSyncTime: DateTime.now(),
          syncedSteps: todaySteps,
        ) : d).toList(),
      );
      
    } catch (e) {
      state = state.copyWith(
        devices: state.devices.map((d) => d.id == id ? d.copyWith(status: SyncStatus.error) : d).toList(),
        error: ApiError.from(e).message,
      );
    }
  }

  Future<void> addDevice(String name, String type) async {
    try {
      // Check if already exists
      final exists = state.devices.any((d) => d.type == type);
      if (exists) {
        state = state.copyWith(error: 'Device is already connected');
        return;
      }

      final deviceUUID = await StorageService.getOrCreateDeviceUUID();
      await _apiService.post('/devices', data: {
        'name': name,
        'type': type,
        'identifier': deviceUUID,
      });
      await loadDevices();
      
      // Since we don't have a dedicated success message field, we can use a special prefix
      // or just show it in the UI directly. Let's add a success field to the state!
    } catch (e) {
      final msg = ApiError.from(e).message;
      state = state.copyWith(error: msg.isNotEmpty ? msg : 'Failed to connect device');
    }
  }

  Future<void> removeDevice(String id) async {
    try {
      await _apiService.delete('/devices/$id');
      await loadDevices();
    } catch (e) {
      state = state.copyWith(error: ApiError.from(e).message);
    }
  }
}

final healthServiceProvider = Provider<HealthService>((ref) => HealthService());

final deviceProvider = StateNotifierProvider.autoDispose<DeviceNotifier, DeviceState>((ref) {
  return DeviceNotifier(
    ref.watch(apiServiceProvider),
    ref.watch(healthServiceProvider),
  );
});
