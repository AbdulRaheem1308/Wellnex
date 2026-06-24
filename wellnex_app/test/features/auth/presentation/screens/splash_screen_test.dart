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
// ignore_for_file: invalid_use_of_visible_for_testing_member

// ──────────────────────────────────────────────────────────────────────────────
// Shared test infrastructure
// ──────────────────────────────────────────────────────────────────────────────

const _secureStorageChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void _mockSecureStorage() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_secureStorageChannel, (_) async => null);
}

/// Builds a [GoRouter] placing [SplashScreen] at '/' with stub destination routes.
GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppRoutes.onboarding,
          builder: (_, __) => const Scaffold(body: Text('Onboarding'))),
      GoRoute(path: AppRoutes.login,
          builder: (_, __) => const Scaffold(body: Text('Login'))),
      GoRoute(path: AppRoutes.completeProfile,
          builder: (_, __) => const Scaffold(body: Text('Complete Profile'))),
      GoRoute(path: AppRoutes.home,
          builder: (_, __) => const Scaffold(body: Text('Home'))),
    ],
  );
}

Widget _buildApp() {
  return ProviderScope(
    child: MaterialApp.router(
      routerConfig: _buildRouter(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
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
    SplashScreen.testSplashDelay = Duration.zero;
    SplashScreen.testResolveStartRouteOverride = null;
    StorageService.setMockAccessToken(null);
    await Hive.box('wellnex_storage').clear();
    await StorageService.clearTokens();
  });

  tearDown(() {
    SplashScreen.testSplashDelay = null;
    SplashScreen.testResolveStartRouteOverride = null;
  });

  // ── Unit tests: resolveStartRoute() routing logic ─────────────────────────

  group('SplashScreen.resolveStartRoute()', () {
    test('returns onboarding route when onboarding not complete', () async {
      final route = await SplashScreen.resolveStartRoute();
      expect(route, AppRoutes.onboarding);
    });

    test('returns login route when onboarding done but no token', () async {
      Hive.box('wellnex_storage').put('onboarding_complete', true);
      StorageService.setMockAccessToken(null);
      final route = await SplashScreen.resolveStartRoute();
      expect(route, AppRoutes.login);
    });

    test('returns completeProfile when token exists but profile not created', () async {
      Hive.box('wellnex_storage').put('onboarding_complete', true);
      Hive.box('wellnex_storage').put('user_data', {'isProfileCreated': false});
      StorageService.setMockAccessToken('tok');
      final route = await SplashScreen.resolveStartRoute();
      expect(route, AppRoutes.completeProfile);
    });

    test('returns home route when token exists and profile created', () async {
      Hive.box('wellnex_storage').put('onboarding_complete', true);
      Hive.box('wellnex_storage').put('user_data', {'isProfileCreated': true});
      StorageService.setMockAccessToken('tok');
      final route = await SplashScreen.resolveStartRoute();
      expect(route, AppRoutes.home);
    });
  });

  // ── Widget tests ──────────────────────────────────────────────────────────
  //
  // Timer draining strategy:
  //  • Navigation tests: use Duration.zero + pumpAndSettle() (timer fires during
  //    first pump, navigation settles quickly).
  //  • UI-check tests: use 500ms delay, pump once, assert, then pump(500ms) +
  //    pumpAndSettle() to fully drain.
  //  • All navigation tests use testResolveStartRouteOverride for reliability.
  // ──────────────────────────────────────────────────────────────────────────

  const kDelay = Duration(milliseconds: 500);

  group('SplashScreen widget', () {
    testWidgets('renders "Wellnex" app name', (tester) async {
      SplashScreen.testSplashDelay = kDelay;
      await tester.pumpWidget(_buildApp());
      await tester.pump(); // initial frame; timer still pending
      expect(find.text('Wellnex'), findsOneWidget);
      await tester.pump(kDelay);       // fire nav timer → navigate
      await tester.pumpAndSettle();    // settle routing
    });

    testWidgets('renders tagline text', (tester) async {
      SplashScreen.testSplashDelay = kDelay;
      await tester.pumpWidget(_buildApp());
      await tester.pump();
      expect(find.textContaining('Track', findRichText: true), findsAtLeastNWidgets(1));
      await tester.pump(kDelay);
      await tester.pumpAndSettle();
    });

    testWidgets('does NOT show CircularProgressIndicator when testSplashDelay is set',
        (tester) async {
      SplashScreen.testSplashDelay = kDelay;
      await tester.pumpWidget(_buildApp());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pump(kDelay);
      await tester.pumpAndSettle();
    });

    testWidgets('shows CircularProgressIndicator when testSplashDelay is null',
        (tester) async {
      // null → real 2500ms timer → loading indicator shown in build()
      SplashScreen.testSplashDelay = null;
      await tester.pumpWidget(_buildApp());
      await tester.pump(); // render frame; 2500ms timer pending
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Fire the real timer
      await tester.pump(const Duration(milliseconds: 2500));
      await tester.pumpAndSettle();
    });

    // ── Navigation tests (use override to avoid storage async issues) ────────

    testWidgets('navigates to onboarding when onboarding not complete',
        (tester) async {
      SplashScreen.testSplashDelay = Duration.zero;
      SplashScreen.testResolveStartRouteOverride =
          () async => AppRoutes.onboarding;
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();
      expect(find.text('Onboarding'), findsOneWidget);
    });

    testWidgets('navigates to login when no token', (tester) async {
      SplashScreen.testSplashDelay = Duration.zero;
      SplashScreen.testResolveStartRouteOverride = () async => AppRoutes.login;
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('navigates to completeProfile when profile not created',
        (tester) async {
      SplashScreen.testSplashDelay = Duration.zero;
      SplashScreen.testResolveStartRouteOverride =
          () async => AppRoutes.completeProfile;
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();
      expect(find.text('Complete Profile'), findsOneWidget);
    });

    testWidgets('navigates to home when profile is created', (tester) async {
      SplashScreen.testSplashDelay = Duration.zero;
      SplashScreen.testResolveStartRouteOverride = () async => AppRoutes.home;
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('falls back to login on resolveStartRoute exception',
        (tester) async {
      SplashScreen.testSplashDelay = Duration.zero;
      SplashScreen.testResolveStartRouteOverride =
          () async => throw Exception('Storage unavailable');
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('dispose cancels the nav timer without errors', (tester) async {
      // Use a long delay so the nav timer is still pending when we dispose.
      const longDelay = Duration(seconds: 10);
      SplashScreen.testSplashDelay = longDelay;
      SplashScreen.testResolveStartRouteOverride =
          () async => AppRoutes.onboarding;

      await tester.pumpWidget(_buildApp());
      await tester.pump(); // initial frame; all timers pending

      // Drain flutter_animate's internal delayed-animation timers first.
      // The longest is delay(800ms) + duration(400ms) = 1200ms.
      // Nav timer is at 10s so it won't fire here.
      await tester.pump(const Duration(milliseconds: 1200));

      // Replace widget → SplashScreen.dispose() cancels the 10s nav timer.
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Text('Replaced'))));
      await tester.pumpAndSettle(); // no remaining timers → settles immediately

      expect(find.text('Replaced'), findsOneWidget);
    });
  });
}
