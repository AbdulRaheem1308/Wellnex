import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wellnex_app/features/auth/presentation/screens/splash_screen.dart';
import 'package:wellnex_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:wellnex_app/services/storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wellnex_app/core/router/app_router.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Shared test infrastructure
// ──────────────────────────────────────────────────────────────────────────────

const _secureStorageChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

/// Mocks FlutterSecureStorage to return null instantly so it never blocks.
void _mockSecureStorage() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_secureStorageChannel, (_) async => null);
}

void main() {
  // ── Shared setUp / tearDown ────────────────────────────────────────────────

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final temp = await Directory.systemTemp.createTemp();
    Hive.init(temp.path);
    _mockSecureStorage();
    await StorageService.init();
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    _mockSecureStorage();
    StorageService.setMockAccessToken(null);
    await Hive.box('wellnex_storage').clear();
    await StorageService.clearTokens();
  });

  // ── Unit tests for routing logic (no widgets → no ticker/animation hangs) ──

  group('SplashScreen.resolveStartRoute()', () {
    test('returns onboarding route when onboarding not complete', () async {
      // onboarding_complete not set → defaults to false
      final route = await SplashScreen.resolveStartRoute();
      expect(route, AppRoutes.onboarding);
    });

    test('returns login route when onboarding done but no token', () async {
      Hive.box('wellnex_storage').put('onboarding_complete', true);
      StorageService.setMockAccessToken(null);

      final route = await SplashScreen.resolveStartRoute();
      expect(route, AppRoutes.login);
    });

    test('returns completeProfile route when token exists but profile not created', () async {
      Hive.box('wellnex_storage').put('onboarding_complete', true);
      Hive.box('wellnex_storage').put('user_data', {'isProfileCreated': false});
      StorageService.setMockAccessToken('fake_token');

      final route = await SplashScreen.resolveStartRoute();
      expect(route, AppRoutes.completeProfile);
    });

    test('returns home route when token exists and profile created', () async {
      Hive.box('wellnex_storage').put('onboarding_complete', true);
      Hive.box('wellnex_storage').put('user_data', {'isProfileCreated': true});
      StorageService.setMockAccessToken('fake_token');

      final route = await SplashScreen.resolveStartRoute();
      expect(route, AppRoutes.home);
    });
  });

}

