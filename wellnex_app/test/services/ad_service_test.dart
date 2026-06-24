import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wellnex_app/services/ad_service.dart';
import 'package:wellnex_app/core/services/remote_config_service.dart';
import 'package:flutter/foundation.dart';

class MockRemoteConfigService extends Mock implements RemoteConfigService {}

void main() {
  group('AdService Tests', () {
    late AdService adService;
    late MockRemoteConfigService mockConfig;

    setUp(() {
      mockConfig = MockRemoteConfigService();
      adService = AdService(mockConfig);
    });

    test('isPremium fallback check', () {
      expect(adService.bannerAdUnitId, isNotEmpty);
      expect(adService.interstitialAdUnitId, isNotEmpty);
      expect(adService.rewardedAdUnitId, isNotEmpty);
      expect(adService.nativeAdUnitId, isNotEmpty);
    });

    test('createBannerAd returns null on web', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final banner = adService.createBannerAd();
      expect(banner, isNull);
      debugDefaultTargetPlatformOverride = null;
    });

    test('showInterstitialAd gracefully fails if not ready', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      adService.showInterstitialAd();
      debugDefaultTargetPlatformOverride = null;
    });

    test('showRewardedAd gracefully fails if not ready', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      var failed = false;
      adService.showRewardedAd(
        onUserEarnedReward: (_) {},
        onAdFailedToShow: () => failed = true,
      );
      expect(failed, isTrue);
      debugDefaultTargetPlatformOverride = null;
    });

    test('loadNativeAd gracefully fails if unsupported', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final ad = await adService.loadNativeAd(factoryId: 'test_factory');
      expect(ad, isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
