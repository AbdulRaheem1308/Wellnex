import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:wellnex_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:wellnex_app/features/auth/services/social_auth_service.dart';
import 'package:wellnex_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:wellnex_app/services/storage_service.dart';
import 'package:wellnex_app/core/services/push_notification_service.dart';

import 'package:go_router/go_router.dart';

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

  setUp(() async {
    final temp = await Directory.systemTemp.createTemp();
    Hive.init(temp.path);
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

  group('AuthNotifier', () {
    test('initial state is correct', () {
      expect(notifier.state.isLoading, false);
      expect(notifier.state.isAuthenticated, false);
      expect(notifier.state.user, null);
    });

    test('sendOtp updates loading state and succeeds', () async {
      when(() => mockApiService.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: {}));

      final future = notifier.sendOtp(phone: '+1234567890');
      expect(notifier.state.isLoading, true);
      
      await future;
      expect(notifier.state.isLoading, false);
      expect(notifier.state.error, null);
    });

    test('verifyOtp updates authentication state on success', () async {
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

    test('logout clears tokens and delegates to socialAuth', () async {
      when(() => mockSocialAuth.signOut()).thenAnswer((_) async {});
      
      await notifier.logout();
      
      verify(() => mockSocialAuth.signOut()).called(1);
      expect(notifier.state.isAuthenticated, false);
      expect(notifier.state.user, null);
    });
  });
}
