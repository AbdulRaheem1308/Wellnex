import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wellnex_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:wellnex_app/features/auth/services/social_auth_service.dart';
import 'package:wellnex_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wellnex_app/services/storage_service.dart';
import 'package:wellnex_app/core/services/push_notification_service.dart';
import 'package:wellnex_app/core/router/app_router.dart';
import 'package:wellnex_app/features/auth/domain/models/user_model.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter/services.dart';

class MockApiService extends Mock implements ApiService {}
class MockSocialAuthService extends Mock implements SocialAuthService {}
class MockPushNotificationService extends Mock implements PushNotificationService {}
class MockGoRouter extends Mock implements GoRouter {}

void main() {
  late MockApiService mockApiService;
  late MockSocialAuthService mockSocialAuth;
  late MockPushNotificationService mockPushService;
  late MockGoRouter mockRouter;
  late AuthNotifier notifier;
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('auth_provider_test_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async => tempDir.path,
    );
    const secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      secureStorageChannel,
      (MethodCall methodCall) async => null,
    );
  });

  setUp(() async {
    await Hive.initFlutter(tempDir.path);
    await StorageService.init();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    
    mockApiService = MockApiService();
    mockSocialAuth = MockSocialAuthService();
    mockPushService = MockPushNotificationService();
    mockRouter = MockGoRouter();
    
    when(() => mockPushService.registerTokenAfterLogin()).thenAnswer((_) async {});
    when(() => mockPushService.clearTokenOnLogout()).thenAnswer((_) async {});
    
    notifier = AuthNotifier(mockApiService, mockSocialAuth, mockPushService, mockRouter);
  });

  group('Providers', () {
    test('authProvider and currentUserProvider return expected instances', () {
      final container = ProviderContainer(overrides: [
        apiServiceProvider.overrideWithValue(mockApiService),
        socialAuthServiceProvider.overrideWithValue(mockSocialAuth),
        pushNotificationServiceProvider.overrideWithValue(mockPushService),
        appRouterProvider.overrideWithValue(mockRouter),
      ]);
      
      final authState = container.read(authProvider);
      expect(authState.isLoading, false);
      expect(authState.isAuthenticated, false);
      
      final user = container.read(currentUserProvider);
      expect(user, null);
      
      // Update state to test currentUserProvider
      container.read(authProvider.notifier).updateUser({'id': '1', 'name': 'John'});
      final user2 = container.read(currentUserProvider);
      expect(user2, isNotNull);
      expect(user2?.name, 'John');
    });
  });

  group('AuthNotifier', () {
    test('initial state is correct', () {
      expect(notifier.state.isLoading, false);
      expect(notifier.state.isAuthenticated, false);
      expect(notifier.state.user, null);
    });

    test('sendOtp updates loading state and succeeds (phone)', () async {
      when(() => mockApiService.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: {}));

      final future = notifier.sendOtp(phone: '+1234567890');
      expect(notifier.state.isLoading, true);
      
      await future;
      expect(notifier.state.isLoading, false);
      expect(notifier.state.error, null);
    });

    test('sendOtp updates loading state and succeeds (email)', () async {
      when(() => mockApiService.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: {}));

      await notifier.sendOtp(email: 'test@test.com');
      expect(notifier.state.isLoading, false);
      expect(notifier.state.error, null);
    });

    test('sendOtp handles error', () async {
      when(() => mockApiService.post(any(), data: any(named: 'data')))
          .thenThrow(DioException(requestOptions: RequestOptions(path: '')));

      try {
        await notifier.sendOtp(phone: '+1234567890');
        fail('Should throw error');
      } catch (e) {
        expect(notifier.state.isLoading, false);
        expect(notifier.state.error, isNotNull);
      }
    });

    test('verifyOtp updates authentication state on success (phone)', () async {
      final mockData = {
        'tokens': {'accessToken': 'at', 'refreshToken': 'rt'},
        'user': {'id': '1', 'name': 'Test'},
        'isNewUser': false
      };
      
      when(() => mockApiService.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: mockData));

      final isNewUser = await notifier.verifyOtp(phone: '+1234567890', otp: '123456');
      
      expect(isNewUser, false);
      expect(notifier.state.isAuthenticated, true);
      expect(notifier.state.user?['name'], 'Test');
    });

    test('verifyOtp updates authentication state on success (email)', () async {
      final mockData = {
        'tokens': {'accessToken': 'at', 'refreshToken': 'rt'},
        'user': {'id': '1', 'name': 'Test'},
        'isNewUser': false
      };
      
      when(() => mockApiService.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: mockData));

      final isNewUser = await notifier.verifyOtp(email: 'test@test.com', otp: '123456');
      expect(isNewUser, false);
    });

    test('verifyOtp handles error', () async {
      when(() => mockApiService.post(any(), data: any(named: 'data')))
          .thenThrow(DioException(requestOptions: RequestOptions(path: '')));

      try {
        await notifier.verifyOtp(phone: '+1234567890', otp: '123456');
        fail('Should throw');
      } catch (e) {
        expect(notifier.state.isLoading, false);
        expect(notifier.state.error, isNotNull);
      }
    });

    test('loginWithSocial calls API and updates state', () async {
      final mockData = {
        'tokens': {'accessToken': 'at', 'refreshToken': 'rt'},
        'user': {'id': '1', 'email': 'test@g.com'},
        'isNewUser': true
      };
      
      when(() => mockApiService.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: mockData));

      final isNewUser = await notifier.loginWithSocial('mock_id_token');
      
      expect(isNewUser, true);
      expect(notifier.state.isAuthenticated, true);
      expect(notifier.state.user?['email'], 'test@g.com');
    });

    test('loginWithSocial handles error', () async {
      when(() => mockApiService.post(any(), data: any(named: 'data')))
          .thenThrow(DioException(requestOptions: RequestOptions(path: '')));

      try {
        await notifier.loginWithSocial('mock_id_token');
        fail('Should throw');
      } catch (e) {
        expect(notifier.state.isLoading, false);
        expect(notifier.state.error, isNotNull);
      }
    });

    test('logout clears tokens and delegates to socialAuth', () async {
      when(() => mockSocialAuth.signOut()).thenAnswer((_) async {});
      
      await notifier.logout();
      
      verify(() => mockSocialAuth.signOut()).called(1);
      expect(notifier.state.isAuthenticated, false);
      expect(notifier.state.user, null);
    });

    test('logout handles socialAuth error gracefully', () async {
      when(() => mockSocialAuth.signOut()).thenThrow(Exception('Failed to sign out'));
      
      await notifier.logout();
      
      expect(notifier.state.isAuthenticated, false);
    });

    test('deleteAccount calls api and logs out', () async {
      when(() => mockApiService.delete(any()))
          .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: {}));
      when(() => mockSocialAuth.signOut()).thenAnswer((_) async {});

      await notifier.deleteAccount();

      verify(() => mockApiService.delete('/users/me')).called(1);
      verify(() => mockSocialAuth.signOut()).called(1);
    });

    test('deleteAccount handles error', () async {
      when(() => mockApiService.delete(any()))
          .thenThrow(DioException(requestOptions: RequestOptions(path: '')));

      try {
        await notifier.deleteAccount();
        fail('Should throw');
      } catch (e) {
        expect(notifier.state.isLoading, false);
        expect(notifier.state.error, isNotNull);
      }
    });

    test('updateProfile calls api and updates state', () async {
      final mockData = {'id': '1', 'name': 'Updated Name'};
      when(() => mockApiService.put(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: mockData));

      await notifier.updateProfile({'name': 'Updated Name'});

      expect(notifier.state.user?['name'], 'Updated Name');
      expect(notifier.state.isLoading, false);
    });

    test('updateProfile handles error', () async {
      when(() => mockApiService.put(any(), data: any(named: 'data')))
          .thenThrow(DioException(requestOptions: RequestOptions(path: '')));

      try {
        await notifier.updateProfile({'name': 'Updated Name'});
        fail('Should throw');
      } catch (e) {
        expect(notifier.state.isLoading, false);
        expect(notifier.state.error, isNotNull);
      }
    });

    test('updateUser updates state directly', () {
      notifier.updateUser({'id': '1', 'name': 'Direct Update'});
      expect(notifier.state.user?['name'], 'Direct Update');
    });
  });

  tearDownAll(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });
}
