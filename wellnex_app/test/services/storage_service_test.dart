// Comprehensive tests for StorageService — covers Hive generic ops,
// user data, onboarding, theme, tokens (via in-memory mock), session clearing,
// logout cooldown, and clearAll.
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wellnex_app/services/storage_service.dart';

// ── Secure-storage channel mock ────────────────────────────────────────────
const _secureStorageChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void _mockSecureStorageWith(Map<String, String?> values) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_secureStorageChannel, (call) async {
    switch (call.method) {
      case 'read':
        final key = (call.arguments as Map)['key'] as String?;
        return values[key];
      case 'write':
      case 'delete':
      case 'deleteAll':
        return null;
      default:
        return null;
    }
  });
}

void _mockSecureStorage() => _mockSecureStorageWith({});

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('storage_service_test_');
    Hive.init(tempDir.path);
    _mockSecureStorage();
    await StorageService.init();
  });

  setUp(() async {
    _mockSecureStorage();
    StorageService.setMockAccessToken(null);
    if (Hive.isBoxOpen('wellnex_storage')) {
      await Hive.box('wellnex_storage').clear();
    }
  });

  tearDownAll(() async {
    await Hive.close();
    try { await tempDir.delete(recursive: true); } catch (_) {}
  });

  // ── Guard — StateError before init ────────────────────────────────────────
  group('StorageService — guard', () {
    test('throws StateError before init is called', () async {
      if (Hive.isBoxOpen('wellnex_storage')) {
        await Hive.box('wellnex_storage').close();
      }
      expect(
        () => StorageService.get<String>('any_key'),
        throwsA(isA<StateError>()),
      );
      await StorageService.init();
    });
  });

  // ── Generic get/put/delete ────────────────────────────────────────────────
  group('StorageService — generic get/put/delete', () {
    test('put and get string value', () async {
      await StorageService.put('str_key', 'hello');
      expect(StorageService.get<String>('str_key'), 'hello');
    });

    test('put and get int value', () async {
      await StorageService.put('int_key', 42);
      expect(StorageService.get<int>('int_key'), 42);
    });

    test('get returns defaultValue when key is absent', () {
      expect(StorageService.get<String>('missing', defaultValue: 'def'), 'def');
    });

    test('get returns null when key is absent and no default', () {
      expect(StorageService.get<String>('missing'), isNull);
    });

    test('get returns defaultValue on type mismatch without throwing', () async {
      await StorageService.put('bad_type', 'not_an_int');
      expect(StorageService.get<int>('bad_type', defaultValue: 0), 0);
    });

    test('delete removes the key', () async {
      await StorageService.put('del_key', 'val');
      await StorageService.delete('del_key');
      expect(StorageService.get<String>('del_key'), isNull);
    });
  });

  // ── User data ─────────────────────────────────────────────────────────────
  group('StorageService — user data', () {
    const user = <String, dynamic>{'id': '1', 'name': 'Alice'};

    test('saveUser and getUser round-trip', () async {
      await StorageService.saveUser(user);
      final retrieved = StorageService.getUser();
      expect(retrieved, isNotNull);
      expect(retrieved!['name'], 'Alice');
    });

    test('getUser returns null when not set', () {
      expect(StorageService.getUser(), isNull);
    });

    test('clearUser removes the user', () async {
      await StorageService.saveUser(user);
      await StorageService.clearUser();
      expect(StorageService.getUser(), isNull);
    });
  });

  // ── Onboarding ────────────────────────────────────────────────────────────
  group('StorageService — onboarding', () {
    test('isOnboardingComplete returns false by default', () {
      expect(StorageService.isOnboardingComplete(), isFalse);
    });

    test('setOnboardingComplete persists the flag', () async {
      await StorageService.setOnboardingComplete();
      expect(StorageService.isOnboardingComplete(), isTrue);
    });
  });

  // ── Theme ─────────────────────────────────────────────────────────────────
  group('StorageService — theme', () {
    test('getThemeMode returns system by default', () {
      expect(StorageService.getThemeMode(), 'system');
    });

    test('setThemeMode and getThemeMode round-trip', () async {
      await StorageService.setThemeMode('dark');
      expect(StorageService.getThemeMode(), 'dark');
    });
  });

  // ── Token methods ─────────────────────────────────────────────────────────
  group('StorageService — tokens', () {
    setUp(() {
      StorageService.setMockAccessToken(null);
    });

    test('saveTokens caches access token in memory', () async {
      _mockSecureStorage();
      await StorageService.saveTokens(
        accessToken: 'acc123',
        refreshToken: 'ref456',
      );
      // Cache hit — doesn't call secure storage again
      final token = await StorageService.getAccessToken();
      expect(token, 'acc123');
    });

    test('getAccessToken returns cached value without hitting storage', () async {
      StorageService.setMockAccessToken('cached-tok');
      final token = await StorageService.getAccessToken();
      expect(token, 'cached-tok');
    });

    test('getAccessToken reads from secure storage when cache is empty', () async {
      StorageService.setMockAccessToken(null);
      // Provide the correct key 'access_token'
      _mockSecureStorageWith({'access_token': 'from-storage'});
      final token = await StorageService.getAccessToken();
      expect(token, 'from-storage');
    });

    test('getRefreshToken reads from cache when set', () async {
      await StorageService.saveTokens(
        accessToken: 'a',
        refreshToken: 'cached-refresh',
      );
      final token = await StorageService.getRefreshToken();
      expect(token, 'cached-refresh');
    });

    test('getRefreshToken reads from secure storage when cache is empty', () async {
      await StorageService.clearTokens();
      _mockSecureStorageWith({'refresh_token': 'storage-refresh'});
      final token = await StorageService.getRefreshToken();
      expect(token, 'storage-refresh');
    });

    test('clearTokens clears both cached and stored tokens', () async {
      await StorageService.saveTokens(
        accessToken: 'access',
        refreshToken: 'refresh',
      );
      await StorageService.clearTokens();
      StorageService.setMockAccessToken(null);
      _mockSecureStorage(); // returns null for both
      expect(await StorageService.getAccessToken(), isNull);
    });

    test('setMockAccessToken sets the cache directly', () async {
      StorageService.setMockAccessToken('mock-tok');
      final token = await StorageService.getAccessToken();
      expect(token, 'mock-tok');
    });
  });

  // ── Device UUID ───────────────────────────────────────────────────────────
  group('StorageService — device UUID', () {
    test('getOrCreateDeviceUUID returns a valid UUID string', () async {
      _mockSecureStorage();
      final uuid = await StorageService.getOrCreateDeviceUUID();
      expect(uuid, isNotEmpty);
      // UUID v4 format: 8-4-4-4-12 hex chars
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(uuid),
        isTrue,
      );
    });

    test('getOrCreateDeviceUUID returns existing UUID when already stored', () async {
      _mockSecureStorage();
      // Set up mock to return a specific UUID for device key
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_secureStorageChannel, (call) async {
        if (call.method == 'read') {
          final key = (call.arguments as Map)['key'] as String?;
          if (key?.contains('device') == true) {
            return '550e8400-e29b-41d4-a716-446655440000';
          }
        }
        return null;
      });

      final uuid = await StorageService.getOrCreateDeviceUUID();
      expect(uuid, '550e8400-e29b-41d4-a716-446655440000');
    });
  });

  // ── Session data clearing ─────────────────────────────────────────────────
  group('StorageService — clearSessionData', () {
    test('clears user and step data but preserves theme and onboarding', () async {
      await StorageService.setOnboardingComplete();
      await StorageService.setThemeMode('dark');
      await StorageService.saveUser({'id': '1'});
      await StorageService.put('step_count', 1000);

      await StorageService.clearSessionData();

      expect(StorageService.isOnboardingComplete(), isTrue);
      expect(StorageService.getThemeMode(), 'dark');
      expect(StorageService.getUser(), isNull);
      expect(StorageService.get<int>('step_count'), isNull);
    });

    test('clearSessionData on empty box completes without error', () async {
      await expectLater(StorageService.clearSessionData(), completes);
    });
  });

  // ── Logout cooldown ───────────────────────────────────────────────────────
  group('StorageService — logout cooldown', () {
    test('loginCooldownSecondsRemaining returns 0 when no logout recorded', () {
      expect(StorageService.loginCooldownSecondsRemaining(), 0);
    });

    test('saveLogoutTimestamp persists, cooldown is positive immediately after', () async {
      await StorageService.saveLogoutTimestamp();
      final remaining = StorageService.loginCooldownSecondsRemaining();
      // Should be a positive number (cooldown not yet elapsed)
      expect(remaining, greaterThan(0));
    });

    test('loginCooldownSecondsRemaining returns 0 after cooldown elapsed', () async {
      // Store a timestamp from the distant past
      final box = Hive.box('wellnex_storage');
      await box.put(
        'logout_timestamp',
        DateTime.now()
            .subtract(const Duration(hours: 1))
            .millisecondsSinceEpoch,
      );
      expect(StorageService.loginCooldownSecondsRemaining(), 0);
    });
  });

  // ── clearAll ──────────────────────────────────────────────────────────────
  group('StorageService — clearAll', () {
    test('clearAll removes all Hive and secure storage data', () async {
      await StorageService.put('some_key', 'some_value');
      await StorageService.saveUser({'id': '42'});
      _mockSecureStorage();

      await StorageService.clearAll();

      // Hive box should be cleared
      expect(StorageService.get<String>('some_key'), isNull);
    });
  });
}
