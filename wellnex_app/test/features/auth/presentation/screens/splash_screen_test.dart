import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wellnex_app/features/auth/presentation/screens/splash_screen.dart';
import 'package:wellnex_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wellnex_app/services/storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final temp = await Directory.systemTemp.createTemp();
    Hive.init(temp.path);
    
    // Mock FlutterSecureStorage channel to prevent hangs on read/write/delete
    const secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (_) async => null);

    await StorageService.init();
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestApp(GoRouter router) {
    return ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  setUp(() async {
    const secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (_) async => null);

    StorageService.setMockAccessToken(null);
    await Hive.box('wellnex_storage').clear();
    await StorageService.clearTokens();
  });

  testWidgets('navigates to onboarding if not completed', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
        GoRoute(path: '/onboarding', builder: (context, state) => const Scaffold(body: Text('Onboarding'))),
      ],
    );

    await tester.pumpWidget(buildTestApp(router));
    expect(find.text('Wellnex'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pump();
    expect(find.text('Onboarding'), findsOneWidget);
  });

  testWidgets('navigates to login if onboarding done but no token', (tester) async {
    Hive.box('wellnex_storage').put('onboarding_complete', true);
    StorageService.setMockAccessToken(null);
    
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
        GoRoute(path: '/login', builder: (context, state) => const Scaffold(body: Text('Login'))),
      ],
    );

    await tester.pumpWidget(buildTestApp(router));
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pump();
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('navigates to completeProfile if token exists but profile not created', (tester) async {
    print('Starting test 3');
    Hive.box('wellnex_storage').put('onboarding_complete', true);
    Hive.box('wellnex_storage').put('user_data', {'isProfileCreated': false});
    StorageService.setMockAccessToken('fake_token');
    print('Set up complete');
    
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
        GoRoute(path: '/complete-profile', builder: (context, state) => const Scaffold(body: Text('CompleteProfile'))),
      ],
    );

    print('Pumping widget');
    await tester.pumpWidget(buildTestApp(router));
    print('Pumping time 2600ms');
    await tester.pump(const Duration(milliseconds: 2600));
    print('Pumping again');
    await tester.pump();
    print('Checking expectation');
    expect(find.text('CompleteProfile'), findsOneWidget);
    print('Done test 3');
  });

  testWidgets('navigates to home if token exists and profile created', (tester) async {
    Hive.box('wellnex_storage').put('onboarding_complete', true);
    Hive.box('wellnex_storage').put('user_data', {'isProfileCreated': true});
    StorageService.setMockAccessToken('fake_token');
    
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
        GoRoute(path: '/home', builder: (context, state) => const Scaffold(body: Text('Home'))),
      ],
    );

    await tester.pumpWidget(buildTestApp(router));
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pump();
    expect(find.text('Home'), findsOneWidget);
  });
}
