import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pedometer_2/pedometer_2.dart';
import 'package:permission_handler/permission_handler.dart';
import 'storage_service.dart';

/// Direct hardware pedometer service using the phone's built-in step sensor.
///
/// Tracks cumulative sensor steps since boot, stores a per-day accumulation in
/// [StorageService], and emits the computed "steps today" count to callers.
///
/// Bug fixes implemented:
/// 1. Spike buffer  — suspicious jumps held one cycle before acceptance.
/// 2. Reboot detect — delta<0 means sensor reset; treat new raw as delta.
/// 3. Midnight roll — date-checked on every event via local DateTime.now().
/// 4. Sleep batch   — delta accumulation absorbs batched step dumps.
/// 5. App-kill fall — getCurrentSteps() falls back to saved steps.
///
/// This is a singleton — use the factory constructor `PedometerService()`.
class PedometerService {
  // ── Singleton ─────────────────────────────────────────────────────────────
  static final PedometerService _instance = PedometerService._internal();
  factory PedometerService() => _instance;
  PedometerService._internal();

  final Pedometer _pedometer = Pedometer();
  @visibleForTesting
  Stream<int>? mockStepCountStream;
  StreamSubscription<int>? _subscription;

  void Function(int stepsToday)? _onStepsChanged;
  void Function(String error)? _onErrorOccurred;

  bool _isListening = false;

  /// Whether the pedometer stream is currently active.
  bool get isListening => _isListening;

  // ── Storage keys ──────────────────────────────────────────────────────────
  static const String _savedStepsTodayKey = 'pedometer_saved_steps_today';
  static const String _lastDateKey        = 'pedometer_last_sync_date';
  static const String _lastSensorStepsKey = 'pedometer_last_sensor_steps';

  // ── Spike-buffer state (in-memory only) ───────────────────────────────────
  /// Max plausible steps/minute — covers elite runners (~200 spm) + 25% buffer.
  static const int _maxStepsPerMinute = 250;

  DateTime? _lastEventTime;

  /// Candidate spike total held for one polling cycle before acceptance.
  int? _pendingSpikeSteps;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Starts listening to the hardware step counter.
  ///
  /// [onStepsChanged] receives the computed "steps today" count on every
  /// sensor event.  [onErrorOccurred] is called with a human-readable message
  /// on errors.
  ///
  /// Calling this again while already listening updates the callbacks without
  /// restarting the stream.
  Future<void> startListening({
    required void Function(int stepsToday) onStepsChanged,
    void Function(String error)? onErrorOccurred,
  }) async {
    _onStepsChanged = onStepsChanged;
    _onErrorOccurred = onErrorOccurred;

    if (_isListening) return;

    // Request activity recognition on Android (no-op on iOS).
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _requestActivityPermission();
    }

    try {
      final stream = mockStepCountStream ?? _pedometer.stepCountStream();
      _subscription = stream.listen(
        _onStepCountEvent,
        onError: _onStepCountError,
        cancelOnError: false,
      );
      _isListening = true;
    } catch (e) {
      debugPrint('PedometerService: Failed to start stream: $e');
      _onErrorOccurred?.call('Sensor stream error: $e');
    }
  }

  /// Stops the sensor stream subscription.
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _isListening = false;
  }

  /// Retrieves a single point-in-time "steps today" count. 
  /// Useful for background isolate/WorkManager jobs where we don't want to keep a stream open forever.
  Future<int> getCurrentSteps() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _requestActivityPermission();
    }

    // Await the very first event from the hardware step stream (with timeout)
    try {
      final stream = mockStepCountStream ?? _pedometer.stepCountStream();
      final sensorSteps = await stream.first.timeout(const Duration(seconds: 2));
      
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final lastSyncDate = StorageService.get<String>(_lastDateKey) ?? '';
      
      int savedStepsToday = StorageService.get<int>(_savedStepsTodayKey) ?? 0;
      int lastSensorSteps = StorageService.get<int>(_lastSensorStepsKey) ?? -1;

      if (lastSyncDate != todayStr) {
        savedStepsToday = 0;
        lastSensorSteps = sensorSteps;
        await StorageService.put(_lastDateKey, todayStr);
      }

      if (lastSensorSteps == -1) {
        lastSensorSteps = sensorSteps;
      }

      int delta = sensorSteps - lastSensorSteps;
      if (delta < 0) {
        delta = sensorSteps;
      }

      savedStepsToday += delta;
      lastSensorSteps = sensorSteps;

      await StorageService.put(_savedStepsTodayKey, savedStepsToday);
      await StorageService.put(_lastSensorStepsKey, lastSensorSteps);

      return savedStepsToday;
    } catch (e) {
      debugPrint('PedometerService: Failed to get current steps: $e');
      
      // Fallback: Try to use the last known cumulative sensor steps from today
      try {
        final savedStepsToday = StorageService.get<int>(_savedStepsTodayKey);
        if (savedStepsToday != null && savedStepsToday > 0) {
          final todayStr = DateTime.now().toIso8601String().split('T')[0];
          final lastSyncDate = StorageService.get<String>(_lastDateKey) ?? '';
          
          if (lastSyncDate == todayStr) {
            debugPrint('PedometerService: Using saved steps fallback: $savedStepsToday');
            return savedStepsToday;
          }
        }
      } catch (fallbackErr) {
        debugPrint('PedometerService: Fallback lookup error: $fallbackErr');
      }

      return 0; // Fallback to 0 if sensor fails (e.g. permission denied or no hardware sensor)
    }
  }

  // ── Permission ─────────────────────────────────────────────────────────────

  Future<void> _requestActivityPermission() async {
    try {
      final status = await Permission.activityRecognition.request();
    } catch (_) {
      // Retry once if a concurrent request interfered.
      try {
        await Future<void>.delayed(const Duration(seconds: 1));
        final status = await Permission.activityRecognition.request();
      } catch (retryError) {
        debugPrint('PedometerService: Permission request error: $retryError');
        _onErrorOccurred?.call('Permission error: $retryError');
      }
    }
  }

  // ── Step Processing ────────────────────────────────────────────────────────

  /// Processes a raw cumulative step count from the hardware sensor.
  ///
  /// Computes "steps today" by subtracting a stored daily baseline from the
  /// raw cumulative count.  Resets the baseline at midnight or on device
  /// reboot (when cumulative count drops below the stored baseline).
  Future<void> _onStepCountEvent(int sensorSteps) async {
    final now = DateTime.now();
    final todayStr = now.toIso8601String().split('T')[0];
    final lastSyncDate = StorageService.get<String>(_lastDateKey) ?? '';

    int savedStepsToday = StorageService.get<int>(_savedStepsTodayKey) ?? 0;
    int lastSensorSteps = StorageService.get<int>(_lastSensorStepsKey) ?? -1;

    // ── Bug 3: Midnight rollover ────────────────────────────────────────────
    if (lastSyncDate != todayStr) {
      savedStepsToday = 0;
      lastSensorSteps = sensorSteps;
      _lastEventTime = null;
      _pendingSpikeSteps = null;
      await StorageService.put(_lastDateKey, todayStr);
      debugPrint('PedometerService: New day reset for $todayStr');
    }

    if (lastSensorSteps == -1) lastSensorSteps = sensorSteps;

    int delta = sensorSteps - lastSensorSteps;

    // ── Bug 2: Device reboot ────────────────────────────────────────────────
    if (delta < 0) {
      debugPrint(
          'PedometerService: Reboot detected. Old: $lastSensorSteps, New: $sensorSteps');
      delta = sensorSteps; // treat new raw as delta from 0
    }

    // ── Bug 1: Spike buffer ─────────────────────────────────────────────────
    if (_lastEventTime != null && delta > 0) {
      final elapsedMinutes =
          now.difference(_lastEventTime!).inSeconds / 60.0;
      final maxAllowed =
          (elapsedMinutes.clamp(0.1, 60.0) * _maxStepsPerMinute).ceil();

      if (delta > maxAllowed) {
        if (_pendingSpikeSteps == null) {
          // First spike — buffer it for one cycle.
          _pendingSpikeSteps = savedStepsToday + delta;
          debugPrint(
              'PedometerService: Spike buffered (delta=$delta, max=$maxAllowed). Waiting for confirmation.');
          _lastEventTime = now;
          return; // do NOT emit yet
        } else {
          // Second consecutive event still looks like a spike — accept it
          // (e.g., a legitimate deep-sleep hardware batch).
          debugPrint(
              'PedometerService: Spike confirmed on second event. Accepting (delta=$delta).');
          _pendingSpikeSteps = null;
        }
      } else {
        _pendingSpikeSteps = null; // normal reading — clear buffered spike
      }
    }

    _lastEventTime = now;
    savedStepsToday += delta;
    lastSensorSteps = sensorSteps;

    await StorageService.put(_savedStepsTodayKey, savedStepsToday);
    await StorageService.put(_lastSensorStepsKey, lastSensorSteps);

    _onStepsChanged?.call(savedStepsToday);
  }

  void _onStepCountError(dynamic error) {
    debugPrint('PedometerService: Hardware sensor error: $error');
    _onErrorOccurred?.call('Hardware error: $error');
  }
}
