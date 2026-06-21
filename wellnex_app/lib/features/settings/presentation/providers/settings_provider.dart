import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/api_service.dart';
import '../../../../services/storage_service.dart';
import '../../../../core/services/background_service.dart';

/// App Settings State
class AppSettings {
  final String themeMode; // 'light', 'dark', 'system'
  final String language; // 'en', 'hi', 'es'
  final bool pushNotificationsEnabled;
  final bool dailyRemindersEnabled;
  final bool dataSyncOverCellular;
  final bool soundEnabled;
  final bool isPublic;
  final bool showOnLeaderboard;
  final bool showMilestones;
  final bool backgroundSyncEnabled;
  final String distanceUnit; // 'km', 'mi'
  final String syncFrequency; // 'Auto (15m)', 'Manual Only', 'Every Hour'
  
  final bool isLoading;
  final String? error;

  const AppSettings({
    this.themeMode = 'system',
    this.language = 'en',
    this.pushNotificationsEnabled = true,
    this.dailyRemindersEnabled = true,
    this.dataSyncOverCellular = true,
    this.soundEnabled = true,
    this.isPublic = true,
    this.showOnLeaderboard = true,
    this.showMilestones = true,
    this.backgroundSyncEnabled = true,
    this.distanceUnit = 'km',
    this.syncFrequency = 'Auto (15m)',
    this.isLoading = false,
    this.error,
  });

  AppSettings copyWith({
    String? themeMode,
    String? language,
    bool? pushNotificationsEnabled,
    bool? dailyRemindersEnabled,
    bool? dataSyncOverCellular,
    bool? soundEnabled,
    bool? isPublic,
    bool? showOnLeaderboard,
    bool? showMilestones,
    bool? backgroundSyncEnabled,
    String? distanceUnit,
    String? syncFrequency,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      pushNotificationsEnabled: pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      dailyRemindersEnabled: dailyRemindersEnabled ?? this.dailyRemindersEnabled,
      dataSyncOverCellular: dataSyncOverCellular ?? this.dataSyncOverCellular,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      isPublic: isPublic ?? this.isPublic,
      showOnLeaderboard: showOnLeaderboard ?? this.showOnLeaderboard,
      showMilestones: showMilestones ?? this.showMilestones,
      backgroundSyncEnabled: backgroundSyncEnabled ?? this.backgroundSyncEnabled,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      syncFrequency: syncFrequency ?? this.syncFrequency,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is AppSettings &&
      other.themeMode == themeMode &&
      other.language == language &&
      other.pushNotificationsEnabled == pushNotificationsEnabled &&
      other.dailyRemindersEnabled == dailyRemindersEnabled &&
      other.dataSyncOverCellular == dataSyncOverCellular &&
      other.soundEnabled == soundEnabled &&
      other.isPublic == isPublic &&
      other.showOnLeaderboard == showOnLeaderboard &&
      other.showMilestones == showMilestones &&
      other.backgroundSyncEnabled == backgroundSyncEnabled &&
      other.distanceUnit == distanceUnit &&
      other.syncFrequency == syncFrequency &&
      other.isLoading == isLoading &&
      other.error == error;
  }

  @override
  int get hashCode {
    return themeMode.hashCode ^
      language.hashCode ^
      pushNotificationsEnabled.hashCode ^
      dailyRemindersEnabled.hashCode ^
      dataSyncOverCellular.hashCode ^
      soundEnabled.hashCode ^
      isPublic.hashCode ^
      showOnLeaderboard.hashCode ^
      showMilestones.hashCode ^
      backgroundSyncEnabled.hashCode ^
      distanceUnit.hashCode ^
      syncFrequency.hashCode ^
      isLoading.hashCode ^
      error.hashCode;
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  final ApiService _apiService;

  SettingsNotifier(this._apiService) : super(AppSettings()) {
    _loadSettings();
  }

  void clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }

  Future<void> _loadSettings() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiService.get('/users/me/settings');
      final data = response.data;
      
      state = AppSettings(
        themeMode: data['themeMode'] ?? 'system',
        language: data['language'] ?? 'en',
        pushNotificationsEnabled: data['pushNotifications'] ?? true,
        dailyRemindersEnabled: data['dailyReminders'] ?? true,
        dataSyncOverCellular: data['dataSyncOverCellular'] ?? true,
        soundEnabled: data['soundEnabled'] ?? true,
        isPublic: data['isPublic'] ?? true,
        showOnLeaderboard: data['showOnLeaderboard'] ?? true,
        showMilestones: data['showMilestones'] ?? true,
        backgroundSyncEnabled: StorageService.get('backgroundSyncEnabled', defaultValue: true) ?? true,
        distanceUnit: data['distanceUnit'] ?? 'km',
        syncFrequency: StorageService.get('syncFrequency', defaultValue: 'Auto (15m)') ?? 'Auto (15m)',
        isLoading: false,
      );
      
      if (state.backgroundSyncEnabled) {
        await BackgroundService.registerPeriodicTask();
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      await _apiService.put('/users/me/settings', data: {
        'themeMode': state.themeMode,
        'language': state.language,
        'pushNotifications': state.pushNotificationsEnabled,
        'dailyReminders': state.dailyRemindersEnabled,
        'dataSyncOverCellular': state.dataSyncOverCellular,
        'soundEnabled': state.soundEnabled,
        'isPublic': state.isPublic,
        'showOnLeaderboard': state.showOnLeaderboard,
        'showMilestones': state.showMilestones,
        'distanceUnit': state.distanceUnit,
      });
    } catch (e) {
      state = state.copyWith(error: 'Failed to save settings: $e');
    }
  }

  void setThemeMode(String mode) {
    state = state.copyWith(themeMode: mode);
    _saveSettings();
  }

  void setLanguage(String lang) {
    state = state.copyWith(language: lang);
    _saveSettings();
  }

  void togglePushNotifications(bool value) {
    state = state.copyWith(pushNotificationsEnabled: value);
    _saveSettings();
  }

  void toggleDailyReminders(bool value) {
    state = state.copyWith(dailyRemindersEnabled: value);
    _saveSettings();
  }
  
  void togglePublicProfile(bool value) {
    state = state.copyWith(isPublic: value);
    _saveSettings();
  }
  
  void toggleShowOnLeaderboard(bool value) {
    state = state.copyWith(showOnLeaderboard: value);
    _saveSettings();
  }
  
  void toggleShowMilestones(bool value) {
    state = state.copyWith(showMilestones: value);
    _saveSettings();
  }
  void toggleDataSyncOverCellular(bool value) {
    state = state.copyWith(dataSyncOverCellular: value);
    _saveSettings();
  }

  void toggleSound(bool value) {
    state = state.copyWith(soundEnabled: value);
    _saveSettings();
  }

  Future<void> toggleBackgroundSync(bool value) async {
    state = state.copyWith(backgroundSyncEnabled: value);
    await StorageService.put('backgroundSyncEnabled', value);
    
    if (value) {
      await BackgroundService.registerPeriodicTask();
    } else {
      await BackgroundService.cancelTask();
    }
  }

  void setDistanceUnit(String unit) {
    state = state.copyWith(distanceUnit: unit);
    _saveSettings();
  }

  Future<void> setSyncFrequency(String frequency) async {
    state = state.copyWith(syncFrequency: frequency);
    await StorageService.put('syncFrequency', frequency);
    
    // Re-register periodic background tasks with updated interval if enabled
    if (state.backgroundSyncEnabled) {
      await BackgroundService.cancelTask();
      await BackgroundService.registerPeriodicTask();
    }
  }

  void resetToDefaults() {
    state = AppSettings();
    _saveSettings();
  }
}

final settingsProvider = StateNotifierProvider.autoDispose<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref.watch(apiServiceProvider));
});
