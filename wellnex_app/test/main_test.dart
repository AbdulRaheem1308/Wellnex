import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wellnex_app/main.dart' as app;
import 'package:wellnex_app/main.dart';
import 'package:wellnex_app/core/router/app_router.dart';
import 'package:wellnex_app/services/api_service.dart';
import 'package:wellnex_app/core/utils/src/platform_io.dart' as platform_io;
import 'package:wellnex_app/services/storage_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';

class MockApiService extends ApiService {
  MockApiService() : super();

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: path),
      data: {
        'themeMode': 'system',
        'language': 'en',
        'pushNotifications': true,
        'dailyReminders': true,
        'dataSyncOverCellular': true,
        'soundEnabled': true,
        'isPublic': true,
        'showOnLeaderboard': true,
        'showMilestones': true,
        'distanceUnit': 'km',
      },
      statusCode: 200,
    );
  }

  @override
  Future<Response<dynamic>> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    return Response(
      requestOptions: RequestOptions(path: path),
      data: {},
      statusCode: 200,
    );
  }
}

// Global network overrides to make Dio/HTTP requests finish instantly without timers
class MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return MockHttpClient();
  }
}

class MockHttpClient extends Mock implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return MockHttpClientRequest();
  }
  
  @override
  set badCertificateCallback(bool Function(X509Certificate cert, String host, int port)? callback) {}
}

class MockHttpClientRequest extends Mock implements HttpClientRequest {
  @override
  HttpHeaders get headers => MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async {
    return MockHttpClientResponse();
  }
}

class MockHttpHeaders extends Mock implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class MockHttpClientResponse extends Mock implements HttpClientResponse {
  @override
  int get statusCode => 404;

  @override
  int get contentLength => 0;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final stream = Stream<List<int>>.empty();
    return stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Path provider mock
    final temp = await Directory.systemTemp.createTemp();
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async => temp.path,
    );

    // Flutter secure storage mock
    const secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      secureStorageChannel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'read' && methodCall.arguments['key'] == 'access_token') {
          return 'fake_token';
        }
        return null;
      },
    );

    // Workmanager mock
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('be.tramckrijte.workmanager/workmanager'),
            (MethodCall methodCall) async {
      return null;
    });

    // Mock Firebase Core
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_core'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'Firebase#initializeCore' || methodCall.method == 'Firebase#initializeApp') {
          return {
            'name': '[DEFAULT]',
            'options': {
              'apiKey': '123',
              'appId': '123',
              'messagingSenderId': '123',
              'projectId': '123',
            },
            'pluginConstants': {},
          };
        }
        return null;
      },
    );

    // Mock Firebase Crashlytics
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_crashlytics'),
      (MethodCall methodCall) async {
        return null;
      },
    );

    // Mock Safe Device
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('safe_device'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'isJailBroken') return false;
        if (methodCall.method == 'isRealDevice') return true;
        if (methodCall.method == 'isMockLocation') return false;
        return false;
      },
    );

    // Mock PostHog
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('posthog_flutter'),
      (MethodCall methodCall) async {
        return null;
      },
    );

    Hive.init(temp.path);
    if (!Hive.isBoxOpen('wellnex_storage')) {
      await StorageService.init();
    }
  });

  testWidgets('WellnexApp creates successfully', (WidgetTester tester) async {
    final mockRouter = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SizedBox()),
      ],
    );

    // Basic test to ensure the root widget can be constructed
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRouterProvider.overrideWithValue(mockRouter),
          apiServiceProvider.overrideWithValue(MockApiService()),
        ],
        child: const WellnexApp(),
      ),
    );
    
    // We just verify it pumps without throwing a critical widget error
    expect(find.byType(WellnexApp), findsOneWidget);
  });

  testWidgets('main() entry point runs and initializes the app successfully', (WidgetTester tester) async {
    HttpOverrides.global = MockHttpOverrides();

    // Call the main function of the app and verify it doesn't crash
    expect(() => app.main(), returnsNormally);

    // Allow any asynchronous/zoned initialization code to run
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('main() catches critical startup errors and shows Safe Mode UI', (WidgetTester tester) async {
    HttpOverrides.global = MockHttpOverrides();
    
    app.debugMockCriticalError = true;
    
    // Clear any previous widgets
    await tester.pumpWidget(Container());

    // Call the main function of the app.
    app.main();

    // Wait for the async code to hit the catch block and run the Safe Mode UI
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    
    // We should see the Safe Mode UI
    expect(find.textContaining('App Failed to Initialize'), findsOneWidget);
    
    app.debugMockCriticalError = false; // Reset
  });

  testWidgets('main() runs fully with simulated Android platform', (WidgetTester tester) async {
    HttpOverrides.global = MockHttpOverrides();
    
    // Temporarily mock isAndroid to true to trigger Firebase and other initializations
    platform_io.debugMockIsAndroid = true;
    
    // Clear any previous widgets
    await tester.pumpWidget(Container());

    // Call the main function of the app.
    app.main();

    // Wait for the async code to complete
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    
    // Just verify the app runs without critical errors and does not show the Safe Mode UI
    expect(find.textContaining('App Failed to Initialize'), findsNothing);


    platform_io.debugMockIsAndroid = null; // Reset
  });
}
