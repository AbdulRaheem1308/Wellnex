/// App-wide constants
library;
import 'package:flutter/foundation.dart';

class AppConstants {
  AppConstants._();

  // API
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.joinwellnex.com/api/v1',
  );

  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user_data';
  static const String onboardingCompleteKey = 'onboarding_complete';
  static const String themeKey = 'theme_mode';
  static const String deviceUuidKey = 'device_uuid';

  // Step Tracking
  static const int defaultDailyGoal = 10000;
  static const double caloriesPerStep = 0.04;
  static const double kmPerStep = 0.000762;

  // Rewards
  static const double pointsPerStep = 0.1;
  static const int adRewardPoints = 10;
  static const int adCooldownMinutes = 5;

  // Streak Milestones
  static const Map<int, int> streakBonuses = {
    7: 50,
    30: 200,
    100: 500,
    365: 2000,
  };

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);

  // ================================================================
  // AdMob Unit IDs
  // Inject production IDs at build time via --dart-define flags:
  //   --dart-define=ADMOB_BANNER_ANDROID=ca-app-pub-YOUR_ID/YOUR_UNIT
  //   --dart-define=ADMOB_INTERSTITIAL_ANDROID=ca-app-pub-YOUR_ID/YOUR_UNIT
  //   --dart-define=ADMOB_REWARDED_ANDROID=ca-app-pub-YOUR_ID/YOUR_UNIT
  //   --dart-define=ADMOB_BANNER_IOS=ca-app-pub-YOUR_ID/YOUR_UNIT
  //   --dart-define=ADMOB_INTERSTITIAL_IOS=ca-app-pub-YOUR_ID/YOUR_UNIT
  //   --dart-define=ADMOB_REWARDED_IOS=ca-app-pub-YOUR_ID/YOUR_UNIT
  // Default values = Google's official test IDs (safe for development).
  // ================================================================

  // Android Ad Units
  static const String _bannerAdUnitIdAndroid = String.fromEnvironment(
    'ADMOB_BANNER_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111', // TEST
  );
  static const String _interstitialAdUnitIdAndroid = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712', // TEST
  );
  static const String _rewardedAdUnitIdAndroid = String.fromEnvironment(
    'ADMOB_REWARDED_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917', // TEST
  );

  // iOS Ad Units
  static const String _bannerAdUnitIdIOS = String.fromEnvironment(
    'ADMOB_BANNER_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/2934735716', // TEST
  );
  static const String _interstitialAdUnitIdIOS = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/4411468910', // TEST
  );
  static const String _rewardedAdUnitIdIOS = String.fromEnvironment(
    'ADMOB_REWARDED_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/1712485313', // TEST
  );

  // Platform-resolved getters (always use these in ad widgets)
  static String get bannerAdUnitId =>
      defaultTargetPlatform == TargetPlatform.iOS
          ? _bannerAdUnitIdIOS
          : _bannerAdUnitIdAndroid;

  static String get interstitialAdUnitId =>
      defaultTargetPlatform == TargetPlatform.iOS
          ? _interstitialAdUnitIdIOS
          : _interstitialAdUnitIdAndroid;

  static String get rewardedAdUnitId =>
      defaultTargetPlatform == TargetPlatform.iOS
          ? _rewardedAdUnitIdIOS
          : _rewardedAdUnitIdAndroid;

  // ================================================================
  // Production Safety Checks
  // Called on app startup in main.dart
  // ================================================================
  static void checkProductionConfig() {
    const bool isProduction = bool.fromEnvironment('dart.vm.product');
    if (!isProduction) return;

    const String testPublisherId = '3940256099942544';
    final usingTestAdIds = [
      _bannerAdUnitIdAndroid,
      _interstitialAdUnitIdAndroid,
      _rewardedAdUnitIdAndroid,
      _bannerAdUnitIdIOS,
      _interstitialAdUnitIdIOS,
      _rewardedAdUnitIdIOS,
    ].any((id) => id.contains(testPublisherId));

    if (usingTestAdIds) {
      debugPrint(
        '⚠️ CRITICAL: AdMob test IDs detected in PRODUCTION build!\n'
        'Pass --dart-define=ADMOB_*= flags at build time with your real Ad Unit IDs.',
      );
    }

    if (apiBaseUrl.contains('localhost') || apiBaseUrl.contains('192.168')) {
      debugPrint(
        '⚠️ CRITICAL: API URL points to local network address in PRODUCTION build!\n'
        'Pass --dart-define=API_BASE_URL=https://api.yourdomain.com/api/v1',
      );
    }
  }
}
