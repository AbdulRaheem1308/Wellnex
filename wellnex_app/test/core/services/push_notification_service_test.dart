import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:wellnex_app/core/services/push_notification_service.dart';
import 'package:wellnex_app/services/api_service.dart';
import 'package:wellnex_app/services/storage_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';

class MockApiService extends ApiService {
  MockApiService() : super();

  bool postCalled = false;
  String? registeredToken;
  bool isCleared = false;

  @override
  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    postCalled = true;
    if (path == '/notifications/fcm-token') {
      registeredToken = data['token'] as String?;
      if (registeredToken == '') {
        isCleared = true;
      }
    }
    return Response(
      requestOptions: RequestOptions(path: path),
      data: {},
      statusCode: 200,
    );
  }
}

class MockLocalNotificationsPlatform extends FlutterLocalNotificationsPlatform
    with MockPlatformInterfaceMixin {}

class MockFirebaseMessagingPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements FirebaseMessagingPlatform {}

class FakeFirebaseApp extends Fake implements FirebaseApp {}

void main() {
  late MockApiService mockApiService;
  late MockFirebaseMessagingPlatform mockMessagingPlatform;
  late StreamController<String> onTokenRefreshController;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    FlutterLocalNotificationsPlatform.instance = MockLocalNotificationsPlatform();

    mockMessagingPlatform = MockFirebaseMessagingPlatform();
    FirebaseMessagingPlatform.instance = mockMessagingPlatform;

    registerFallbackValue(mockMessagingPlatform);
    registerFallbackValue(FakeFirebaseApp());

    // ignore: invalid_use_of_protected_member
    when(() => mockMessagingPlatform.delegateFor(
          app: any(named: 'app'),
        )).thenReturn(mockMessagingPlatform);

    when(() => mockMessagingPlatform.isAutoInitEnabled).thenReturn(true);

    // ignore: invalid_use_of_protected_member
    when(() => mockMessagingPlatform.setInitialValues(
          isAutoInitEnabled: any(named: 'isAutoInitEnabled'),
        )).thenReturn(mockMessagingPlatform);

    when(() => mockMessagingPlatform.requestPermission(
          alert: any(named: 'alert'),
          announcement: any(named: 'announcement'),
          badge: any(named: 'badge'),
          carPlay: any(named: 'carPlay'),
          criticalAlert: any(named: 'criticalAlert'),
          provisional: any(named: 'provisional'),
          sound: any(named: 'sound'),
          providesAppNotificationSettings: any(named: 'providesAppNotificationSettings'),
        )).thenAnswer((_) async => NotificationSettings(
          alert: AppleNotificationSetting.enabled,
          announcement: AppleNotificationSetting.disabled,
          badge: AppleNotificationSetting.enabled,
          carPlay: AppleNotificationSetting.disabled,
          criticalAlert: AppleNotificationSetting.disabled,
          authorizationStatus: AuthorizationStatus.authorized,
          lockScreen: AppleNotificationSetting.enabled,
          notificationCenter: AppleNotificationSetting.enabled,
          showPreviews: AppleShowPreviewSetting.always,
          sound: AppleNotificationSetting.enabled,
          timeSensitive: AppleNotificationSetting.enabled,
          providesAppNotificationSettings: AppleNotificationSetting.disabled,
        ));

    when(() => mockMessagingPlatform.getToken(
          vapidKey: any(named: 'vapidKey'),
        )).thenAnswer((_) async => 'mock-fcm-token');

    when(() => mockMessagingPlatform.deleteToken()).thenAnswer((_) async {});

    // Mock Path provider
    final temp = await Directory.systemTemp.createTemp();
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async => temp.path,
    );

    // Mock Secure Storage
    const secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      secureStorageChannel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'read' && methodCall.arguments['key'] == 'access_token') {
          return 'mock_access_token';
        }
        return null;
      },
    );

    // Mock Firebase Messaging Channels
    const firebaseMessagingChannel = MethodChannel('plugins.flutter.io/firebase_messaging');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      firebaseMessagingChannel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'FirebaseMessaging#requestPermission' || methodCall.method == 'Messaging#requestPermission') {
          return {
            'alert': 1,
            'badge': 1,
            'sound': 1,
            'provisional': 0,
            'announcement': 0,
            'carPlay': 0,
            'criticalAlert': 0,
            'authorizationStatus': 1,
          };
        }
        if (methodCall.method == 'FirebaseMessaging#getToken' || methodCall.method == 'Messaging#getToken') {
          return 'mock-fcm-token';
        }
        if (methodCall.method == 'FirebaseMessaging#deleteToken' || methodCall.method == 'Messaging#deleteToken') {
          return true;
        }
        return null;
      },
    );

    // Mock Local Notifications Channels
    const localNotificationsChannel = MethodChannel('dexterous.com/flutter/local_notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      localNotificationsChannel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'initialize') {
          return true;
        }
        if (methodCall.method == 'show') {
          return null;
        }
        return null;
      },
    );

    await Firebase.initializeApp();
    Hive.init(temp.path);
    if (!Hive.isBoxOpen('wellnex_storage')) {
      await StorageService.init();
    }
  });

  setUp(() {
    mockApiService = MockApiService();
    
    // Set up active StreamController for token refresh
    onTokenRefreshController = StreamController<String>.broadcast();
    when(() => mockMessagingPlatform.onTokenRefresh).thenAnswer((_) => onTokenRefreshController.stream);
    
    // Default initial message is null
    when(() => mockMessagingPlatform.getInitialMessage()).thenAnswer((_) async => null);
  });

  tearDown(() {
    onTokenRefreshController.close();
  });

  test('PushNotificationService Provider should provide an instance', () {
    final container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(mockApiService),
      ],
    );

    final service = container.read(pushNotificationServiceProvider);
    expect(service, isNotNull);
    container.dispose();
  });

  testWidgets('PushNotificationService should initialize and handle notifications successfully', (WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(mockApiService),
      ],
    );

    final service = container.read(pushNotificationServiceProvider);

    // 1. Initialize service
    await expectLater(service.initialize(), completes);

    // Verify token was fetched and registered with mock api service
    expect(mockApiService.postCalled, isTrue);
    expect(mockApiService.registeredToken, equals('mock-fcm-token'));

    // 2. Trigger registerTokenAfterLogin
    mockApiService.postCalled = false;
    mockApiService.registeredToken = null;
    await service.registerTokenAfterLogin();
    expect(mockApiService.postCalled, isTrue);
    expect(mockApiService.registeredToken, equals('mock-fcm-token'));

    // 3. Trigger clearTokenOnLogout
    await service.clearTokenOnLogout();
    expect(mockApiService.isCleared, isTrue);

    // 4. Test onTokenRefresh stream event
    mockApiService.postCalled = false;
    mockApiService.registeredToken = null;
    onTokenRefreshController.add('refreshed-token');
    await tester.pump(Duration.zero);
    expect(mockApiService.postCalled, isTrue);
    expect(mockApiService.registeredToken, equals('refreshed-token'));

    // 5. Test Foreground handler directly
    const mockMessage = RemoteMessage(
      notification: RemoteNotification(
        title: 'Walk Goal Reached!',
        body: 'You walked 10,000 steps today!',
      ),
      data: {'type': 'goal_reached'},
    );
    expect(() => service.handleForegroundMessage(mockMessage), returnsNormally);

    // 6. Test onMessageOpenedApp directly
    expect(() => service.handleNotificationOpen(mockMessage), returnsNormally);

    container.dispose();
  });

  testWidgets('PushNotificationService handles terminated state initial message', (WidgetTester tester) async {
    // Mock getInitialMessage to return a mock remote message representing launching from terminated state
    const terminatedMessage = RemoteMessage(
      notification: RemoteNotification(
        title: 'Launch Title',
        body: 'Launch Body',
      ),
      data: {'type': 'badge_earned'},
    );
    when(() => mockMessagingPlatform.getInitialMessage()).thenAnswer((_) async => terminatedMessage);

    final container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(mockApiService),
      ],
    );

    final service = container.read(pushNotificationServiceProvider);
    
    // Initialize service and verify it completes without crashing
    await expectLater(service.initialize(), completes);

    container.dispose();
  });

  test('PushNotificationService background handler runs without crash', () async {
    const mockMessage = RemoteMessage(
      messageId: 'msg_123',
      data: {'type': 'challenge_invite'},
    );

    // Directly call the exposed top-level background handler
    await expectLater(
      firebaseMessagingBackgroundHandler(mockMessage),
      completes,
    );
  });

  test('PushNotificationService local notifications tap callback runs without crash', () {
    final container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(mockApiService),
      ],
    );

    final service = container.read(pushNotificationServiceProvider);

    // Directly call exposed local notification tap handler callback
    expect(
      () => service.onLocalNotificationTap(
        NotificationResponse(
          notificationResponseType: NotificationResponseType.selectedNotification,
          payload: '{"type":"reward"}',
        ),
      ),
      returnsNormally,
    );

    container.dispose();
  });
}
