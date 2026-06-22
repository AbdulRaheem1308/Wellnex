import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/app_constants.dart';

/// Local storage service backed by Hive (general data) and
/// FlutterSecureStorage (tokens & device UUID).
///
/// Call [StorageService.init] once at app startup before using any other
/// method. Calling methods before [init] will throw a [StateError] with a
/// helpful message.
class StorageService {
  static const String _boxName = 'wellnex_storage';

  static Box? _box;

  // In-memory cache for fast, synchronous token access to bypass Android Keystore async delay
  static String? _cachedAccessToken;
  static String? _cachedRefreshToken;

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Initialises Hive and opens the main storage box.
  ///
  /// Must be called before any other [StorageService] method.
  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  /// Returns the open Hive box, throwing a [StateError] if [init] has not
  /// been called yet.
  static Box get _openBox {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StateError(
        'StorageService is not initialised. '
        'Call StorageService.init() before using any other method.',
      );
    }
    return box;
  }

  // ── Secure Storage ────────────────────────────────────────────────────────

  /// Saves the access and refresh tokens in the secure enclave.
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    // Cache in RAM immediately to avoid Keystore async reordering
    _cachedAccessToken = accessToken;
    _cachedRefreshToken = refreshToken;

    await _secureStorage.write(
        key: AppConstants.accessTokenKey, value: accessToken);
    await _secureStorage.write(
        key: AppConstants.refreshTokenKey, value: refreshToken);
  }

  @visibleForTesting
  static void setMockAccessToken(String? token) {
    _cachedAccessToken = token;
  }

  /// Returns the stored access token, or `null` if none exists.
  static Future<String?> getAccessToken() async {
    if (_cachedAccessToken != null) return _cachedAccessToken;

    try {
      final token = await _secureStorage.read(key: AppConstants.accessTokenKey);
      _cachedAccessToken = token;
      return token;
    } catch (e) {
      debugPrint('StorageService: Error reading access token: $e');
      await _secureStorage.deleteAll().catchError((_) {});
      return null;
    }
  }

  /// Returns the stored refresh token, or `null` if none exists.
  static Future<String?> getRefreshToken() async {
    if (_cachedRefreshToken != null) return _cachedRefreshToken;

    try {
      final token = await _secureStorage.read(key: AppConstants.refreshTokenKey);
      _cachedRefreshToken = token;
      return token;
    } catch (e) {
      debugPrint('StorageService: Error reading refresh token: $e');
      return null;
    }
  }

  /// Deletes both tokens from the secure enclave.
  static Future<void> clearTokens() async {
    // Clear RAM instantly so fast logins don't see ghosts
    _cachedAccessToken = null;
    _cachedRefreshToken = null;

    try {
      await _secureStorage.delete(key: AppConstants.accessTokenKey);
      await _secureStorage.delete(key: AppConstants.refreshTokenKey);
    } catch (e) {
      debugPrint('StorageService: Error clearing tokens: $e');
    }
  }

  /// Returns a stable device UUID, creating one if it does not yet exist.
  static Future<String> getOrCreateDeviceUUID() async {
    try {
      String? uuidStr = await _secureStorage.read(key: AppConstants.deviceUuidKey);
      if (uuidStr == null) {
        uuidStr = const Uuid().v4();
        await _secureStorage.write(key: AppConstants.deviceUuidKey, value: uuidStr);
      }
      return uuidStr;
    } catch (e) {
      debugPrint('StorageService: Error reading device UUID: $e');
      final uuidStr = const Uuid().v4();
      try {
        await _secureStorage.write(key: AppConstants.deviceUuidKey, value: uuidStr);
      } catch (_) {}
      return uuidStr;
    }
  }

  // ── Hive Storage ───────────────────────────────────────────────────────────

  // User Management
  static Future<void> saveUser(Map<String, dynamic> user) async {
    await _openBox.put(AppConstants.userKey, user);
  }

  /// Returns the cached user object, or `null` if not found.
  static Map<String, dynamic>? getUser() {
    final data = _openBox.get(AppConstants.userKey);
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  /// Removes the cached user object.
  static Future<void> clearUser() async {
    await _openBox.delete(AppConstants.userKey);
  }

  /// Clears all user-specific session data from the Hive box, but preserves
  /// app preferences like theme and onboarding status.
  static Future<void> clearSessionData() async {
    final keysToKeep = [
      AppConstants.onboardingCompleteKey,
      AppConstants.themeKey,
    ];
    
    final keysToDelete = _openBox.keys.where((k) => !keysToKeep.contains(k)).toList();
    for (var key in keysToDelete) {
      await _openBox.delete(key);
    }
  }

  // ── Onboarding ─────────────────────────────────────────────────────────────

  static bool isOnboardingComplete() {
    return _openBox.get(AppConstants.onboardingCompleteKey,
        defaultValue: false) as bool;
  }

  static Future<void> setOnboardingComplete() async {
    await _openBox.put(AppConstants.onboardingCompleteKey, true);
  }

  // ── Theme ──────────────────────────────────────────────────────────────────

  static String getThemeMode() {
    return _openBox.get(AppConstants.themeKey, defaultValue: 'system') as String;
  }

  static Future<void> setThemeMode(String mode) async {
    await _openBox.put(AppConstants.themeKey, mode);
  }

  // ── Generic ────────────────────────────────────────────────────────────────

  /// Writes [value] to the Hive box under [key].
  static Future<void> put(String key, dynamic value) async {
    await _openBox.put(key, value);
  }

  /// Reads the value stored under [key], cast to [T].
  ///
  /// Returns [defaultValue] if the key does not exist or the stored value
  /// cannot be cast to [T].
  static T? get<T>(String key, {T? defaultValue}) {
    final box = _openBox;
    try {
      final value = box.get(key, defaultValue: defaultValue);
      if (value == null) return defaultValue;
      return value as T;
    } catch (e) {
      debugPrint(
          'StorageService: Type mismatch reading "$key" as $T: $e');
      return defaultValue;
    }
  }

  /// Removes the value for [key] from the Hive box.
  static Future<void> delete(String key) async {
    await _openBox.delete(key);
  }

  /// Clears all Hive data and all secure-storage entries.
  ///
  /// Both operations are attempted even if the first fails.
  static Future<void> clearAll() async {
    Object? hiveError;
    try {
      await _openBox.clear();
    } catch (e) {
      hiveError = e;
      debugPrint('StorageService: Hive clear error: $e');
    }

    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      debugPrint('StorageService: Secure storage clear error: $e');
    }

    if (hiveError != null) {
      throw StateError(
          'StorageService.clearAll: Hive clear failed: $hiveError');
    }
  }
}
