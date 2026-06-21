import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:safe_device/safe_device.dart';
import 'dart:math';

import '../../../../services/api_service.dart';
import '../../../../services/storage_service.dart';
import 'package:wellnex_app/services/health_service.dart';
import 'package:wellnex_app/services/pedometer_service.dart';
import 'package:wellnex_app/features/devices/presentation/providers/device_provider.dart';

/// Dashboard state model
class DashboardState {
  final bool isLoading;
  final TodaySteps? todaySteps;
  final StreakInfo? streak;
  final WalletInfo? wallet;
  final Map<String, dynamic>? user;
  final Map<String, dynamic>? userStats;
  final List<DailyStep> weeklyHistory;
  final String? error;
  
  // XP System
  final int xpLevel;
  final int xpCurrentProgress; // 0-100
  final int xpToNextLevel;
  
  // Sync Status
  final SyncStatus syncStatus;
  final DateTime? lastSyncTime;

  // Diagnostics & Debugging Info
  final int sensorStepsToday;
  final int sensorOffset;
  final bool isSensorListening;
  final bool healthAuthorized;
  final String? sensorErrorMessage;
  // New timestamps for step tracking
  final DateTime? firstTrackingTime;
  final DateTime? lastTrackingTime;

  DashboardState({
    this.isLoading = false,
    this.todaySteps,
    this.streak,
    this.wallet,
    this.user,
    this.userStats,
    this.weeklyHistory = const [],
    this.error,
    this.xpLevel = 1,
    this.xpCurrentProgress = 0,
    this.xpToNextLevel = 1000,
    this.syncStatus = SyncStatus.idle,
    this.lastSyncTime,
    this.sensorStepsToday = 0,
    this.sensorOffset = 0,
    this.isSensorListening = false,
    this.healthAuthorized = false,
    this.sensorErrorMessage,
    this.firstTrackingTime,
    this.lastTrackingTime,
  });

  DashboardState copyWith({
    bool? isLoading,
    TodaySteps? todaySteps,
    StreakInfo? streak,
    WalletInfo? wallet,
    Map<String, dynamic>? user,
    Map<String, dynamic>? userStats,
    List<DailyStep>? weeklyHistory,
    String? error,
    int? xpLevel,
    int? xpCurrentProgress,
    int? xpToNextLevel,
    SyncStatus? syncStatus,
    DateTime? lastSyncTime,
    int? sensorStepsToday,
    int? sensorOffset,
    bool? isSensorListening,
    bool? healthAuthorized,
    String? sensorErrorMessage,
    DateTime? firstTrackingTime,
    DateTime? lastTrackingTime,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      todaySteps: todaySteps ?? this.todaySteps,
      streak: streak ?? this.streak,
      wallet: wallet ?? this.wallet,
      user: user ?? this.user,
      userStats: userStats ?? this.userStats,
      weeklyHistory: weeklyHistory ?? this.weeklyHistory,
      error: error,
      xpLevel: xpLevel ?? this.xpLevel,
      xpCurrentProgress: xpCurrentProgress ?? this.xpCurrentProgress,
      xpToNextLevel: xpToNextLevel ?? this.xpToNextLevel,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      sensorStepsToday: sensorStepsToday ?? this.sensorStepsToday,
      sensorOffset: sensorOffset ?? this.sensorOffset,
      isSensorListening: isSensorListening ?? this.isSensorListening,
      healthAuthorized: healthAuthorized ?? this.healthAuthorized,
      sensorErrorMessage: sensorErrorMessage ?? this.sensorErrorMessage,
      firstTrackingTime: firstTrackingTime ?? this.firstTrackingTime,
      lastTrackingTime: lastTrackingTime ?? this.lastTrackingTime,
    );
  }
}

enum SyncStatus { idle, syncing, synced, failed }

class TodaySteps {
  final int stepCount;
  final int caloriesBurned;
  final double distanceKm;
  final int activeMinutes;
  final int goal;
  final int progress;
  final bool goalReached;

  TodaySteps({
    required this.stepCount,
    required this.caloriesBurned,
    required this.distanceKm,
    required this.activeMinutes,
    required this.goal,
    required this.progress,
    required this.goalReached,
  });

  factory TodaySteps.fromJson(Map<String, dynamic> json) {
    return TodaySteps(
      stepCount: json['stepCount'] ?? 0,
      caloriesBurned: json['caloriesBurned'] ?? 0,
      distanceKm: double.tryParse(json['distanceKm']?.toString() ?? '0') ?? 0.0,
      activeMinutes: json['activeMinutes'] ?? 0,
      goal: json['goal'] ?? 10000,
      progress: json['progress'] ?? 0,
      goalReached: json['goalReached'] ?? false,
    );
  }

  TodaySteps copyWith({
    int? stepCount,
    int? caloriesBurned,
    double? distanceKm,
    int? activeMinutes,
    int? goal,
    int? progress,
    bool? goalReached,
  }) {
    return TodaySteps(
      stepCount: stepCount ?? this.stepCount,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      distanceKm: distanceKm ?? this.distanceKm,
      activeMinutes: activeMinutes ?? this.activeMinutes,
      goal: goal ?? this.goal,
      progress: progress ?? this.progress,
      goalReached: goalReached ?? this.goalReached,
    );
  }
}

class StreakInfo {
  final int currentStreak;
  final int longestStreak;
  final int? nextMilestone;
  final int? daysToMilestone;

  StreakInfo({
    required this.currentStreak,
    required this.longestStreak,
    this.nextMilestone,
    this.daysToMilestone,
  });

  factory StreakInfo.fromJson(Map<String, dynamic> json) {
    return StreakInfo(
      currentStreak: json['currentStreak'] ?? 0,
      longestStreak: json['longestStreak'] ?? 0,
      nextMilestone: json['nextMilestone'],
      daysToMilestone: json['daysToMilestone'],
    );
  }
}

class WalletInfo {
  final int balance;
  final int lifetimePoints;
  final int? monthlyXp;

  WalletInfo({
    required this.balance,
    required this.lifetimePoints,
    this.monthlyXp,
  });

  factory WalletInfo.fromJson(Map<String, dynamic> json) {
    return WalletInfo(
      balance: json['balance'] ?? 0,
      lifetimePoints: json['lifetimePoints'] ?? 0,
      monthlyXp: json['monthlyXp'],
    );
  }
}

class DailyStep {
  final DateTime date;
  final int steps;

  DailyStep({required this.date, required this.steps});
}

/// Dashboard Provider
final dashboardProvider = StateNotifierProvider.autoDispose<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier(
    ref.watch(apiServiceProvider),
    ref.watch(healthServiceProvider),
  );
});

class DashboardNotifier extends StateNotifier<DashboardState> with WidgetsBindingObserver {
  final ApiService _apiService;
  final HealthService _healthService;
  final PedometerService _pedometerService = PedometerService();

  int _lastSyncedSteps = 0;
  DateTime? _lastSyncedTime;
  
  int _currentPedometerSteps = 0;
  int _lastPedometerRawSteps = 0;
  int _pedometerOffset = 0;
  bool _pedometerOffsetInitialized = false;
  
  // Real-time active minutes tracking
  DateTime? _lastStepTime;
  int _accumulatedActiveSeconds = 0;
  
  String _trackingDate = DateTime.now().toIso8601String().split('T')[0];
  
  Timer? _uiBatchTimer;

  DashboardNotifier(this._apiService, this._healthService) : super(DashboardState()) {
    _loadUser();
    _initHardwarePedometer();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uiBatchTimer?.cancel();
    _pedometerService.stopListening();
    super.dispose();
  }

  void _checkDayRollover() {
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    if (_trackingDate != todayStr) {
      debugPrint("DashboardNotifier: Midnight rollover detected. Resetting state for $todayStr");
      _trackingDate = todayStr;
      _currentPedometerSteps = 0;
      _pedometerOffset = 0;
      _pedometerOffsetInitialized = false;
      _lastSyncedSteps = 0;
      _accumulatedActiveSeconds = 0;
      state = state.copyWith(
        todaySteps: null, // Clear yesterday's steps from UI
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint("DashboardNotifier: App resumed.");
      // Note: We DO NOT stop and restart the pedometer listener here! 
      // Flutter's EventChannel automatically buffers sensor events while the app is in the background.
      // If we cancel the subscription and restart it, we throw away all the steps taken while the app was in the background!
      
      // Also fetch the latest data from the backend to sync any background progress
      fetchTodayData();
    }
  }

  void _initHardwarePedometer() {
    _uiBatchTimer?.cancel();
    // 1. Start the live pedometer independently so it doesn't get blocked by Health API OAuth
    _pedometerService.startListening(
      onStepsChanged: (stepsToday) {
        _currentPedometerSteps = stepsToday;
        
        if (!_pedometerOffsetInitialized && state.todaySteps != null) {
          final backendSteps = state.todaySteps!.stepCount;
          _pedometerOffset = backendSteps - stepsToday;
          if (_pedometerOffset < 0) _pedometerOffset = 0;
          _pedometerOffsetInitialized = true;
          
          // Immediately sync once when initializing
          syncSteps(stepsToday + _pedometerOffset);
        }

        final expectedTotal = _pedometerOffsetInitialized ? stepsToday + _pedometerOffset : stepsToday;
        
        // Active time tracking logic
        final now = DateTime.now();
        if (_lastStepTime != null) {
          final timeDiff = now.difference(_lastStepTime!);
          final stepDiff = stepsToday - _lastPedometerRawSteps;
          
          if (stepDiff > 0) {
             if (timeDiff.inSeconds <= 15) {
               // Continuous walking (steps registered within 15 seconds)
               _accumulatedActiveSeconds += timeDiff.inSeconds;
             } else {
               // Bulk step update (e.g. app woke up from background)
               // Estimate time for these specific missed steps
               _accumulatedActiveSeconds += (stepDiff / 100 * 60).round();
             }
          }
        }
        _lastStepTime = now;
        _lastPedometerRawSteps = stepsToday;

        // Live recalculations for real-time daily stats cards updates (Walked km, Burned kcal, Active mins)
        TodaySteps? updatedTodaySteps = state.todaySteps;
        if (updatedTodaySteps != null && expectedTotal > updatedTodaySteps.stepCount) {
          // Use accumulated real-time tracking, fallback to clinical standard if it somehow failed
          int newActiveMinutes = (_accumulatedActiveSeconds / 60).round();
          if (newActiveMinutes == 0 && expectedTotal > 0) {
            newActiveMinutes = (expectedTotal / 100).round();
          }

          final activeMinutesToUse = newActiveMinutes > updatedTodaySteps.activeMinutes
              ? newActiveMinutes
              : updatedTodaySteps.activeMinutes;

          updatedTodaySteps = updatedTodaySteps.copyWith(
            stepCount: expectedTotal,
            caloriesBurned: (expectedTotal * 0.045).round(),
            distanceKm: expectedTotal * 0.000762,
            activeMinutes: activeMinutesToUse,
            progress: ((expectedTotal / updatedTodaySteps.goal) * 100).toInt(),
            goalReached: expectedTotal >= updatedTodaySteps.goal,
          );
        }

        final newFirst = state.firstTrackingTime ?? now;
        final newLast = now;

        state = state.copyWith(
          sensorStepsToday: stepsToday,
          sensorOffset: _pedometerOffset,
          isSensorListening: _pedometerService.isListening,
          todaySteps: updatedTodaySteps,
          firstTrackingTime: newFirst,
          lastTrackingTime: newLast,
        );
      },
      onErrorOccurred: (err) {
        state = state.copyWith(
          sensorErrorMessage: err,
          isSensorListening: _pedometerService.isListening,
        );
      },
    ).then((_) {
      state = state.copyWith(
        isSensorListening: _pedometerService.isListening,
      );
    });

    // 2. Request Health SDK (Google Fit) authorization
    Future.microtask(() async {
      final authorized = await _healthService.requestAuthorization();
      state = state.copyWith(
        healthAuthorized: authorized,
      );
    });

    // 3. Batch UI updates every 5 seconds to prevent jitter and save resources
    _uiBatchTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      _checkDayRollover();
      
      int stepsToSync = 0;
      
      if (_currentPedometerSteps > 0) {
        // Use real-time physical sensor steps
        stepsToSync = _pedometerOffsetInitialized 
            ? _currentPedometerSteps + _pedometerOffset 
            : _currentPedometerSteps;
      } else {
        // Fallback: Query Google Fit / Health Connect / HealthKit
        try {
          if (state.healthAuthorized) {
            final healthSteps = await _healthService.getTodaySteps();
            if (healthSteps > 0) {
              stepsToSync = healthSteps;
            }
          }
        } catch (e) {
          debugPrint('Pedometer: Fallback Health Service query failed: $e');
        }
      }

      state = state.copyWith(
        sensorStepsToday: _currentPedometerSteps,
        sensorOffset: _pedometerOffset,
        isSensorListening: _pedometerService.isListening,
      );
      
      if (stepsToSync > 0) {
        // Only trigger if steps actually changed
        if (state.todaySteps == null || stepsToSync > state.todaySteps!.stepCount) {
           syncSteps(stepsToSync);
        }
      }
    });
  }



  void _loadUser() {
    final user = StorageService.getUser();
    state = state.copyWith(user: user);
  }

  Future<void> fetchTodayData() async {
    _checkDayRollover();
    state = state.copyWith(isLoading: true, syncStatus: SyncStatus.syncing);

    // Ensure the physical phone device is registered in the backend before attempting any sync
    try {
      final deviceUUID = await StorageService.getOrCreateDeviceUUID();
      final devicesResponse = await _apiService.get('/devices');
      final devicesData = devicesResponse.data;
      if (devicesData is List) {
        final hasPhone = devicesData.any((d) => d is Map && d['type'] == 'PHONE' && d['identifier'] == deviceUUID);
        if (!hasPhone) {
          await _apiService.post('/devices', data: {
            'name': 'Built-in Phone Sensors',
            'type': 'PHONE',
            'identifier': deviceUUID,
          });
          debugPrint('DashboardNotifier: Registered physical phone device: $deviceUUID');
        }
      }
    } catch (e) {
      debugPrint('DashboardNotifier: Failed to ensure physical phone registered: $e');
    }

    // Auto-sync steps from local sensors first (sync last 7 days of history in parallel to capture past offline steps)
    try {
      // Automatically pre-authorize and request permissions on startup so the physical mobile phone's built-in pedometer tracks out-of-the-box
      final authorized = await _healthService.requestAuthorization();
      if (authorized) {
        final historyMap = await _healthService.getStepHistory(7);
        final List<Future> syncTasks = [];
        
        final isJailBroken = await SafeDevice.isJailBroken;
        final isRealDevice = await SafeDevice.isRealDevice;
        final isMockLocation = await SafeDevice.isMockLocation;
        final deviceUUID = await StorageService.getOrCreateDeviceUUID();

        for (final entry in historyMap.entries) {
          final dateStr = entry.key.toIso8601String().split('T')[0];
          // Security: Clamp steps to max 50,000 to prevent spoofed/injected backdated steps
          final steps = entry.value.clamp(0, 50000);
          
          if (steps > 0) {
            syncTasks.add(
              () async {
                try {
                  // Unique cryptographic nonce and timestamp per day sync
                  final nonce = const Uuid().v4();
                  final timestamp = DateTime.now().millisecondsSinceEpoch;
                  
                  await _apiService.post('/steps/sync', data: {
                    'deviceIdentifier': deviceUUID,
                    'date': dateStr,
                    'stepCount': steps,
                    'activeMinutes': (steps / 100).round(),
                    'source': 'phone_sensors',
                    'nonce': nonce,
                    'timestamp': timestamp,
                    'integrity': {
                      'isJailBroken': isJailBroken,
                      'isRealDevice': isRealDevice,
                      'isMockLocation': isMockLocation,
                    }
                  });
                } catch (err) {
                  print('Failed to sync steps for $dateStr: $err');
                }
              }()
            );
          }
        }
        if (syncTasks.isNotEmpty) {
          await Future.wait(syncTasks);
        }
      }
    } catch (e) {
      print('Auto-sync steps error: $e');
    }

    try {
      // Fetch all data in parallel
      final results = await Future.wait([
        _apiService.get('/steps/today'),
        _apiService.get('/rewards/streak'),
        _apiService.get('/rewards/wallet'),
        _apiService.get('/steps/weekly'),
        _apiService.get('/users/me'),
        _apiService.get('/users/me/stats'),
      ]);

      if (!mounted) return;

      // Calculate XP based on monthly XP (Season Level)
      final walletData = WalletInfo.fromJson(results[2].data);
      // Fallback to lifetimePoints if monthlyXp is missing (e.g. older users before migration)
      final xpInfo = _calculateXpLevel(walletData.monthlyXp ?? 0);

      // Parse weekly history
      final weeklyData = results[3].data['dailyBreakdown'] as List;
      final history = weeklyData.map((d) => DailyStep(
        date: DateTime.parse(d['date']),
        steps: d['stepCount'],
      )).toList();

      // Update local storage with fresh user data
      final userData = results[4].data;
      await StorageService.saveUser(userData);

      // User Stats
      final userStats = results[5].data;

      final backendStepsData = results[0].data;
      final backendSteps = backendStepsData['stepCount'] ?? 0;
      
      final expectedTotal = _currentPedometerSteps + _pedometerOffset;
      if (backendSteps > expectedTotal) {
         _pedometerOffset = backendSteps - _currentPedometerSteps;
         if (_pedometerOffset < 0) _pedometerOffset = 0;
         _pedometerOffsetInitialized = true;
      } else if (!_pedometerOffsetInitialized) {
         _pedometerOffset = backendSteps - _currentPedometerSteps;
         if (_pedometerOffset < 0) _pedometerOffset = 0;
         _pedometerOffsetInitialized = true;
      }

      // Initialize active seconds from backend if we are just starting
      if (_accumulatedActiveSeconds == 0) {
        _accumulatedActiveSeconds = (backendStepsData['activeMinutes'] ?? 0) * 60;
      }

      state = state.copyWith(
        isLoading: false,
        todaySteps: (state.todaySteps != null && TodaySteps.fromJson(backendStepsData).stepCount < state.todaySteps!.stepCount)
            ? state.todaySteps!
            : TodaySteps.fromJson(backendStepsData),
        streak: StreakInfo.fromJson(results[1].data),
        wallet: walletData,
        xpLevel: xpInfo['level'],
        xpCurrentProgress: xpInfo['progress'],
        xpToNextLevel: xpInfo['toNextLevel'],
        syncStatus: SyncStatus.synced,
        lastSyncTime: DateTime.now(),
        weeklyHistory: history,
        user: userData,
        userStats: userStats,
      );
    } catch (e) {
      if (!mounted) return;
      // On error, handle gracefully and reset loading state
      state = state.copyWith(
        isLoading: false,
        error: ApiError.from(e).message,
        syncStatus: SyncStatus.failed,
      );
    }
  }
  
  /// Calculate XP level based on monthly points (Seasonal Level)
  Map<String, int> _calculateXpLevel(int points) {
    // XP thresholds: Level 1 = 0-999, Level 2 = 1000-2499, etc.
    const xpPerLevel = 1000;
    const levelMultiplier = 1.5;
    
    int level = 1;
    int totalXpForCurrentLevel = 0;
    int xpForNextLevel = xpPerLevel;
    
    int remainingPoints = points;
    
    while (remainingPoints >= xpForNextLevel) {
      remainingPoints -= xpForNextLevel;
      level++;
      totalXpForCurrentLevel += xpForNextLevel;
      xpForNextLevel = (xpPerLevel * (1 + (level - 1) * 0.5)).toInt();
    }
    
    final progress = ((remainingPoints / xpForNextLevel) * 100).toInt();
    final toNextLevel = xpForNextLevel - remainingPoints;
    
    return {
      'level': level,
      'progress': progress,
      'toNextLevel': toNextLevel,
    };
  }

  // Removed _generateDemoHistory


  Future<void> syncSteps(int rawStepCount) async {
    // ── Security & Sanity Checks (Fix #3, #4) ───────────────────────
    // 1. Max absolute steps cap (50,000 steps per day)
    int stepCount = rawStepCount.clamp(0, 50000);

    // 2. Cadence Speed Cap: prevent injector hacks sending huge steps in seconds
    final now = DateTime.now();
    if (_lastSyncedTime != null && _lastSyncedSteps > 0) {
      final timeDiff = now.difference(_lastSyncedTime!);
      final stepDiff = stepCount - _lastSyncedSteps;
      
      if (stepDiff > 0 && timeDiff.inSeconds > 0) {
        final stepsPerSecond = stepDiff / timeDiff.inSeconds;
        // Hardware sensors often batch steps and deliver them in bursts.
        // A threshold of 50 steps/sec prevents malicious API injectors while 
        // allowing legitimate sensor batching (e.g. 30 steps delivered in 1 sec).
        if (stepsPerSecond > 50.0) {
          final allowedIncrease = (timeDiff.inSeconds * 50.0).toInt();
          stepCount = _lastSyncedSteps + allowedIncrease;
          debugPrint('⚠️ Security Warning: Cadence check failed ($stepsPerSecond steps/sec). Clamping steps to: $stepCount');
        }
      }
    }
    // ─────────────────────────────────────────────────────────────────

    // 1. Optimistic UI update instantly on every step event (stats only — coins come from backend 4hr sync)
    if (state.todaySteps != null) {
      final currentSteps = state.todaySteps!.stepCount;
      if (stepCount > currentSteps || currentSteps == 0) {
        final goal = state.todaySteps!.goal > 0 ? state.todaySteps!.goal : 10000;
        
        int calculatedActiveMinutes = (_accumulatedActiveSeconds / 60).round();
        if (calculatedActiveMinutes == 0 && stepCount > 0) {
           calculatedActiveMinutes = (stepCount / 100).round();
        }

        final newActiveMinutes = calculatedActiveMinutes > state.todaySteps!.activeMinutes
            ? calculatedActiveMinutes
            : state.todaySteps!.activeMinutes;

        state = state.copyWith(
          todaySteps: TodaySteps(
            stepCount: stepCount,
            caloriesBurned: (stepCount * 0.045).round(),
            distanceKm: stepCount * 0.000762,
            activeMinutes: newActiveMinutes,
            goal: goal,
            progress: ((stepCount / goal) * 100).toInt(),
            goalReached: stepCount >= goal,
          ),
        );
      }
    }


    if (stepCount == _lastSyncedSteps) return;

    final stepDiff = (stepCount - _lastSyncedSteps).abs();
    final timeDiff = _lastSyncedTime == null ? const Duration(seconds: 999) : now.difference(_lastSyncedTime!);

    // Throttling: Only hit the backend if the user walked at least 10 steps, or 30 seconds have passed since the last sync
    if (stepDiff >= 10 || timeDiff.inSeconds >= 30) {
      _lastSyncedSteps = stepCount;
      _lastSyncedTime = now;
      
      try {
        final today = now.toIso8601String().split('T')[0];
        
        // Attestation/device check parameters
        final isJailBroken = await SafeDevice.isJailBroken;
        final isRealDevice = await SafeDevice.isRealDevice;
        final isMockLocation = await SafeDevice.isMockLocation;
        final deviceUUID = await StorageService.getOrCreateDeviceUUID();
        
        // Generate cryptographic nonce and timestamp
        final nonce = const Uuid().v4();
        final timestamp = now.millisecondsSinceEpoch;

        await _apiService.post('/steps/sync', data: {
          'deviceIdentifier': deviceUUID,
          'date': today,
          'stepCount': stepCount,
          'activeMinutes': max((_accumulatedActiveSeconds / 60).round(), (stepCount / 100).round()),
          'source': 'phone_sensors',
          'nonce': nonce,
          'timestamp': timestamp,
          'integrity': {
            'isJailBroken': isJailBroken,
            'isRealDevice': isRealDevice,
            'isMockLocation': isMockLocation,
          }
        });
        
        // Removed fetchTodayData() here to prevent infinite loop and health dialog popups
      } catch (e) {
        print('Pedometer: Failed to sync stepCount $stepCount: $e');
      }
    }
  }
  Future<void> updateDailyGoal(int newGoal) async {
    try {
      // Optimistically update today's steps goal
      if (state.todaySteps != null) {
        state = state.copyWith(
          todaySteps: TodaySteps(
            stepCount: state.todaySteps!.stepCount,
            caloriesBurned: state.todaySteps!.caloriesBurned,
            distanceKm: state.todaySteps!.distanceKm,
            activeMinutes: state.todaySteps!.activeMinutes,
            goal: newGoal,
            progress: ((state.todaySteps!.stepCount / newGoal) * 100).toInt(),
            goalReached: state.todaySteps!.stepCount >= newGoal,
          ),
        );
      }

      // Call API to save to user profile
      await _apiService.put('/users/me', data: {
        'dailyStepGoal': newGoal,
      });

      // Optionally refresh to ensure full sync
      // await fetchTodayData(); 
    } catch (e) {
      // Revert or show error (for now just log/ignore in this notifier)
      // Ideally we would revert the optimistic update here
      
      // If using snackbar service, show error here
    }
  }
}
