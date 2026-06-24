import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'pedometer_service.dart';

/// Service that bridges the hardware pedometer (Android) and Apple HealthKit (iOS).
///
/// On Android, step data is read directly from the phone's built-in
/// TYPE_STEP_COUNTER sensor via [PedometerService] — no third-party app
/// installation required.
///
/// On iOS, steps are read from Apple HealthKit which is always available
/// natively without any extra installations.
///
/// Use [requestAuthorization] before any data-fetch calls.
class HealthService {
  // ── Singleton ─────────────────────────────────────────────────────────────
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  final Health _health = Health();
  bool _isConfigured = false;

  Future<void> _ensureConfigured() async {
    if (!_isConfigured) {
      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        await _health.configure();
      }
      _isConfigured = true;
    }
  }

  /// Data types we request read access for.
  static const List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.WORKOUT,
  ];

  /// Matching read-only permissions for each type above.
  static const List<HealthDataAccess> _permissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  // ── Authorization ─────────────────────────────────────────────────────────

  /// Checks if Google Health Connect is available (Android only).
  /// Always returns true on iOS.
  Future<bool> isHealthConnectAvailable() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    await _ensureConfigured();
    try {
      return await _health.isHealthConnectAvailable();
    } catch (_) {
      return false;
    }
  }

  /// Prompts the user to install Google Health Connect (Android only).
  Future<void> installHealthConnect() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await _ensureConfigured();
    try {
      await _health.installHealthConnect();
    } catch (_) {}
  }


  /// Requests access to health data.
  ///
  /// On Android, requests the `activityRecognition` permission via
  /// [PedometerService]. On iOS, requests HealthKit authorisation.
  /// Returns `true` if authorisation was granted.
  Future<bool> requestAuthorization() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Pedometer only needs ACTIVITY_RECOGNITION — handled inside PedometerService.
      try {
        final status = await Permission.activityRecognition.request();
        return status == PermissionStatus.granted;
      } catch (e) {
        debugPrint('HealthService: Activity recognition permission error: $e');
        return false;
      }
    }
    // iOS — request HealthKit authorisation.
    await _ensureConfigured();
    try {
      return await _health.requestAuthorization(_types, permissions: _permissions);
    } catch (e) {
      debugPrint('HealthService: Authorization error: $e');
      return false;
    }
  }

  // ── Step Queries ──────────────────────────────────────────────────────────

  /// Returns the total step count for today (midnight → now).
  ///
  /// On Android, delegates to [PedometerService] which reads the hardware
  /// step counter directly — no Health Connect required.
  /// On iOS, reads from Apple HealthKit.
  Future<int> getTodaySteps() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return PedometerService().getCurrentSteps();
    }
    // iOS — HealthKit
    await _ensureConfigured();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    try {
      return await _health.getTotalStepsInInterval(midnight, now) ?? 0;
    } catch (e) {
      debugPrint('HealthService: Error fetching today\'s steps: $e');
      return 0;
    }
  }

  /// Returns a map of {startOfDay → stepCount} for each of the past [days].
  ///
  /// Uses [Future.wait] to parallelise day queries for better performance.
  Future<Map<DateTime, int>> getStepHistory(int days) async {
    await _ensureConfigured();
    assert(days > 0, 'days must be positive');
    final now = DateTime.now();

    final futures = List<Future<MapEntry<DateTime, int>>>.generate(days, (i) {
      final date = now.subtract(Duration(days: i));
      final startOfDay = DateTime(date.year, date.month, date.day);
      // Use exclusive end-of-day: start of next day avoids the 23:59:59 gap.
      final endOfDay =
          DateTime(date.year, date.month, date.day + 1);

      return _health
          .getTotalStepsInInterval(startOfDay, endOfDay)
          .then<MapEntry<DateTime, int>>(
            (steps) => MapEntry(startOfDay, steps ?? 0),
            onError: (Object e) {
              debugPrint(
                  'HealthService: Error fetching steps for $startOfDay: $e');
              return MapEntry(startOfDay, 0);
            },
          );
    });

    final entries = await Future.wait(futures);
    return Map.fromEntries(entries);
  }

  // ── Workout Queries ───────────────────────────────────────────────────────

  /// Fetches workouts from the past [days].
  Future<List<HealthDataPoint>> getRecentWorkouts(int days) async {
    await _ensureConfigured();
    assert(days > 0, 'days must be positive');
    final now = DateTime.now();
    final startTime = now.subtract(Duration(days: days));

    try {
      final workouts = await _health.getHealthDataFromTypes(
        startTime: startTime,
        endTime: now,
        types: [HealthDataType.WORKOUT],
      );
      // Sort by start time descending (newest first)
      workouts.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
      return workouts;
    } catch (e) {
      debugPrint('HealthService: Error fetching workouts: $e');
      return [];
    }
  }
}
