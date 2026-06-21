import 'package:flutter_test/flutter_test.dart';
import 'package:wellnex_app/core/constants/app_constants.dart';

void main() {
  group('AppConstants', () {
    test('apiBaseUrl is defined correctly', () {
      expect(AppConstants.apiBaseUrl, isNotEmpty);
      expect(AppConstants.apiBaseUrl.startsWith('http'), isTrue);
    });

    test('storage keys are correctly defined', () {
      expect(AppConstants.accessTokenKey, 'access_token');
      expect(AppConstants.refreshTokenKey, 'refresh_token');
      expect(AppConstants.userKey, 'user_data');
      expect(AppConstants.onboardingCompleteKey, 'onboarding_complete');
      expect(AppConstants.themeKey, 'theme_mode');
    });

    test('step tracking constants are correct', () {
      expect(AppConstants.defaultDailyGoal, 10000);
      expect(AppConstants.caloriesPerStep, 0.04);
      expect(AppConstants.kmPerStep, 0.000762);
    });

    test('rewards constants are correct', () {
      expect(AppConstants.pointsPerStep, 0.1);
      expect(AppConstants.adRewardPoints, 10);
      expect(AppConstants.adCooldownMinutes, 5);
    });

    test('streakBonuses map is populated', () {
      expect(AppConstants.streakBonuses, isNotEmpty);
      expect(AppConstants.streakBonuses[7], 50);
      expect(AppConstants.streakBonuses[365], 2000);
    });

    test('ad unit IDs return non-null strings', () {
      // By default returns test IDs depending on target platform
      expect(AppConstants.bannerAdUnitId, isNotEmpty);
      expect(AppConstants.interstitialAdUnitId, isNotEmpty);
      expect(AppConstants.rewardedAdUnitId, isNotEmpty);
    });

    test('checkProductionConfig does not throw in debug mode', () {
      // Should not throw, should just complete safely
      expect(() => AppConstants.checkProductionConfig(), returnsNormally);
    });
  });
}
