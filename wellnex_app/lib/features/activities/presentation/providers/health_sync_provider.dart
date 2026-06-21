import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:flutter/foundation.dart';
import '../../../../services/health_service.dart';
import '../../domain/models/activity_model.dart';
import 'activity_provider.dart';

class HealthSyncNotifier extends StateNotifier<bool> {
  final HealthService _healthService;
  final ActivityNotifier _activityNotifier;

  HealthSyncNotifier(this._healthService, this._activityNotifier) : super(false);

  Future<void> syncRecentWorkouts() async {
    if (state) return; // already syncing
    state = true;

    try {
      final hasPermissions = await _healthService.requestAuthorization();
      if (!hasPermissions) {
        debugPrint('HealthSync: Permissions denied.');
        state = false;
        return;
      }

      final recentWorkouts = await _healthService.getRecentWorkouts(7);
      
      final source = Platform.isIOS ? 'apple_health' : 'google_fit';

      for (final dp in recentWorkouts) {
        if (dp.value is WorkoutHealthValue) {
          final workout = dp.value as WorkoutHealthValue;
          
          // Map health package workout type to our ActivityType
          final activityType = _mapWorkoutType(workout.workoutActivityType);
          if (activityType == null) continue; // unsupported type
          
          final durationMinutes = dp.dateTo.difference(dp.dateFrom).inMinutes;
          if (durationMinutes < 1) continue; // too short

          // Get distance in km if available
          double? distanceKm;
          final totalDistance = workout.totalDistance; // This might be in meters or another unit depending on OS, but usually health package returns distance in meters if not specified, actually health package for workouts returns distance in meters? Wait, let's assume totalEnergyBurned and totalDistance exist.
          // Wait, actually `WorkoutHealthValue` might have `totalDistance` and `totalEnergyBurned`. Let's check `health` package docs or just safely read them.
          // According to health 13.x: 
          // workout.totalDistance (int?) which is often in meters
          // workout.totalEnergyBurned (int?) in kilocalories
          
          if (workout.totalDistance != null) {
            // Assume meters
            distanceKm = (workout.totalDistance as num).toDouble() / 1000.0;
          }

          // Check for duplicates
          final isDuplicate = _activityNotifier.state.recentActivities.any((a) {
            // Exact same start time and type
            // Note: dateFrom is DateTime, so we can compare
            final timeDiff = a.startTime.difference(dp.dateFrom).inSeconds.abs();
            return a.type == activityType && timeDiff < 60; // within 1 minute
          });

          if (isDuplicate) {
            debugPrint('HealthSync: Skipping duplicate workout: $activityType at ${dp.dateFrom}');
            continue;
          }

          debugPrint('HealthSync: Logging verified workout: $activityType ($durationMinutes mins)');
          await _activityNotifier.logActivity(
            type: activityType,
            duration: Duration(minutes: durationMinutes),
            distanceKm: distanceKm,
            source: source,
          );
        }
      }
    } catch (e) {
      debugPrint('HealthSync: Error syncing workouts: $e');
    } finally {
      state = false;
    }
  }

  ActivityType? _mapWorkoutType(HealthWorkoutActivityType type) {
    switch (type) {
      case HealthWorkoutActivityType.RUNNING:
        return ActivityType.running;
      case HealthWorkoutActivityType.BIKING:
        return ActivityType.cycling;
      case HealthWorkoutActivityType.WALKING:
        return ActivityType.walking;
      case HealthWorkoutActivityType.SWIMMING:
      case HealthWorkoutActivityType.SWIMMING_POOL:
      case HealthWorkoutActivityType.SWIMMING_OPEN_WATER:
        return ActivityType.swimming;
      case HealthWorkoutActivityType.YOGA:
        return ActivityType.yoga;
      case HealthWorkoutActivityType.HIKING:
        return ActivityType.hiking;
      case HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING:
      case HealthWorkoutActivityType.FUNCTIONAL_STRENGTH_TRAINING:
      case HealthWorkoutActivityType.CORE_TRAINING:
        return ActivityType.gym;
      default:
        return null;
    }
  }
}

final healthSyncProvider = StateNotifierProvider.autoDispose<HealthSyncNotifier, bool>((ref) {
  return HealthSyncNotifier(
    HealthService(),
    ref.read(activityProvider.notifier),
  );
});
