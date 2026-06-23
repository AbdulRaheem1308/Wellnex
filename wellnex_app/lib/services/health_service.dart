import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service that bridges HealthKit (iOS) and Google Health Connect (Android).
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

  /// Requests access to health data.
  ///
  /// On Android, also requests the `activityRecognition` permission first.
  /// Returns `true` if authorization was granted.
  Future<bool> requestAuthorization() async {
    await _ensureConfigured();
    if (defaultTargetPlatform == TargetPlatform.android) {
      PermissionStatus status;
      try {
        status = await Permission.activityRecognition.request();
      } catch (_) {
        // Retry once if another concurrent request interfered.
        await Future<void>.delayed(const Duration(seconds: 1));
        try {
          status = await Permission.activityRecognition.request();
        } catch (e) {
          debugPrint('HealthService: Activity recognition permission error: $e');
          return false;
        }
      }
      if (status != PermissionStatus.granted) {
        return false;
      }
    }

    try {
      return await _health.requestAuthorization(_types,
          permissions: _permissions);
    } catch (e) {
      debugPrint('HealthService: Authorization error: $e');
      return false;
    }
  }

  // ── Step Queries ──────────────────────────────────────────────────────────

  /// Returns the total step count for today (midnight → now).
  Future<int> getTodaySteps() async {
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
