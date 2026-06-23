import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:safe_device/safe_device.dart';
import 'dart:math';

import '../../../../services/api_service.dart';
import '../../../../services/storage_service.dart';
import 'package:wellnex_app/services/health_service.dart';
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

  int _lastSyncedSteps = 0;
  DateTime? _lastSyncedTime;

  // Real-time active minutes tracking (estimated from Health API poll frequency)
  int _accumulatedActiveSeconds = 0;
  int _lastHealthApiSteps = 0;
  DateTime? _lastStepTime;
  
  String _trackingDate = DateTime.now().toIso8601String().split('T')[0];
  
  Timer? _uiBatchTimer;

  DashboardNotifier(this._apiService, this._healthService) : super(DashboardState()) {
    _loadUser();
    _initHealthPolling();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uiBatchTimer?.cancel();
    super.dispose();
  }

  void _checkDayRollover() {
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    if (_trackingDate != todayStr) {
      debugPrint("DashboardNotifier: Midnight rollover detected. Resetting state for $todayStr");
      _trackingDate = todayStr;
      _lastSyncedSteps = 0;
      _lastHealthApiSteps = 0;
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
      // Poll immediately when app comes to foreground
      _pollHealthApiSteps();
      // Also refresh backend data
      fetchTodayData();
    }
  }

  /// Polls the Health API for today's step count and updates state.
  /// Health API (Google Health Connect / Apple HealthKit) reads the phone's
  /// built-in step counter hardware directly. No external device needed.
  Future<void> _pollHealthApiSteps() async {
    if (!state.healthAuthorized) return;
    try {
      final healthSteps = await _healthService.getTodaySteps();
      if (healthSteps <= 0) return;

      // Estimate active minutes from step increase between polls
      final now = DateTime.now();
      if (_lastStepTime != null && healthSteps > _lastHealthApiSteps) {
        final stepDiff = healthSteps - _lastHealthApiSteps;
        final timeDiff = now.difference(_lastStepTime!);
        // Estimate: ~100 steps/minute of active walking
        _accumulatedActiveSeconds += (stepDiff / 100 * 60).round().clamp(0, timeDiff.inSeconds);
      }
      _lastStepTime = now;
      _lastHealthApiSteps = healthSteps;

      state = state.copyWith(sensorStepsToday: healthSteps);

      if (state.todaySteps == null || healthSteps > state.todaySteps!.stepCount) {
        syncSteps(healthSteps);
      }
    } catch (e) {
      debugPrint('DashboardNotifier: Health API poll error: $e');
    }
  }

  void _initHealthPolling() {
    _uiBatchTimer?.cancel();

    // Request Health authorization and start periodic polling.
    // Polling every 15 seconds gives near-real-time updates without
    // draining battery — Health API is OS-cached so each call is cheap.
    Future.microtask(() async {
      final authorized = await _healthService.requestAuthorization();
      state = state.copyWith(healthAuthorized: authorized);
      if (authorized) {
        // Immediate first poll
        await _pollHealthApiSteps();
      }
    });

    _uiBatchTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      _checkDayRollover();
      await _pollHealthApiSteps();
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

      // Health API is the authoritative source — backend value wins if higher,
      // otherwise the in-progress Health API poll will catch up shortly.
      if (backendSteps > _lastHealthApiSteps) {
        _lastHealthApiSteps = backendSteps;
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
          'source': 'HEALTH_API',
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
        print('Health API: Failed to sync stepCount $stepCount: $e');
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
