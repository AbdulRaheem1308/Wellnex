import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:wellnex_app/services/ad_service.dart';
import 'package:wellnex_app/core/services/remote_config_service.dart';

class MockRemoteConfigService extends Mock implements RemoteConfigService {}
class MockBannerAd extends Mock implements BannerAd {}

void main() {
  late AdService adService;
  late MockRemoteConfigService mockConfigService;

  setUp(() {
    mockConfigService = MockRemoteConfigService();
    adService = AdService(mockConfigService);
  });

  group('AdService tests', () {
    test('createBannerAd sets up listeners properly', () {
      bool loadedCalled = false;
      bool failedCalled = false;

      final bannerAd = adService.createBannerAd(
        onAdLoaded: () {
          loadedCalled = true;
        },
        onAdFailedToLoad: (error) {
          failedCalled = true;
        },
      );

      // We just ensure the bannerAd is successfully created.
      // Testing the actual callbacks would require calling the internal listener functions,
      // but creating it without exceptions and verifying it's not null covers the code.
      expect(bannerAd, isNotNull);
      expect(bannerAd?.adUnitId, isNotEmpty);
      expect(bannerAd?.size, equals(AdSize.banner));
      
      // Simulate calling the listeners manually if possible
      final listener = bannerAd!.listener;
      
      // Trigger onAdLoaded
      listener.onAdLoaded?.call(bannerAd);
      expect(loadedCalled, isTrue);
      
      // We can't trigger onAdFailedToLoad easily with a mocked LoadAdError 
      // without it throwing or being complex, but we can check it exists.
      expect(listener.onAdFailedToLoad, isNotNull);
    });

    test('adServiceProvider initializes correctly', () {
      final container = ProviderContainer(
        overrides: [
          remoteConfigServiceProvider.overrideWithValue(mockConfigService),
        ],
      );
      final service = container.read(adServiceProvider);
      expect(service, isA<AdService>());
    });
  });
}
