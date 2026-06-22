import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:wellnex_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:wellnex_app/features/settings/presentation/providers/settings_provider.dart';
import 'package:wellnex_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:wellnex_app/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:wellnex_app/services/api_service.dart';
import 'package:wellnex_app/services/storage_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';

class MockApiService extends Mock implements ApiService {}

class MockAuthNotifier extends StateNotifier<AuthState> with Mock implements AuthNotifier {
  MockAuthNotifier() : super(AuthState());

  @override
  Future<void> deleteAccount() async {
    // mock success
  }
}

void main() {
  late MockAuthNotifier mockAuthNotifier;
  late GoRouter router;
  late MockApiService mockApiService;

  setUpAll(() async {
    final temp = await Directory.systemTemp.createTemp();
    Hive.init(temp.path);
    if (!Hive.isBoxOpen('wellnex_storage')) {
      await StorageService.init();
    }
  });

  setUp(() {
    mockAuthNotifier = MockAuthNotifier();
    mockApiService = MockApiService();
    when(() => mockApiService.get(any())).thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: {}, statusCode: 200));
    when(() => mockApiService.post(any(), data: any(named: 'data'))).thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: {}, statusCode: 200));
    when(() => mockApiService.put(any(), data: any(named: 'data'))).thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), data: {}, statusCode: 200));

    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/device-sync',
          builder: (context, state) => const Scaffold(body: Text('Device Sync')),
        ),
        GoRoute(
          path: '/privacy-policy',
          builder: (context, state) => const Scaffold(body: Text('Privacy Policy')),
        ),
        GoRoute(
          path: '/terms',
          builder: (context, state) => const Scaffold(body: Text('Terms')),
        ),
        GoRoute(
          path: '/sensor-diagnostics',
          builder: (context, state) => const Scaffold(body: Text('Diagnostics')),
        ),
      ],
    );
  });

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => mockAuthNotifier),
        settingsProvider.overrideWith((ref) => SettingsNotifier(mockApiService)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
      ),
    );
  }

  testWidgets('renders settings screen and checks default elements', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Data & Privacy'), findsOneWidget);
    
    await tester.dragUntilVisible(
      find.text('Legal & Privacy (GDPR)'),
      find.byType(ListView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.text('Legal & Privacy (GDPR)'), findsOneWidget);
    
    await tester.dragUntilVisible(
      find.text('Reset to Defaults'),
      find.byType(ListView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reset to Defaults'), findsOneWidget);
  });

  testWidgets('toggles interact correctly', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Find Dark Mode toggle
    final darkModeToggle = find.ancestor(
      of: find.text('Dark Mode'),
      matching: find.byType(ListTile),
    );
    expect(darkModeToggle, findsOneWidget);
    await tester.tap(darkModeToggle);
    await tester.pumpAndSettle();

    // Background sync toggle
    final bgSyncToggle = find.ancestor(
      of: find.text('Background Sync'),
      matching: find.byType(ListTile),
    );
    await tester.dragUntilVisible(bgSyncToggle, find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(bgSyncToggle);
    await tester.pumpAndSettle();
  });

  testWidgets('tapping device sync navigates to device sync', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final deviceSyncLink = find.text('Connected Devices');
    
    await tester.dragUntilVisible(
      deviceSyncLink,
      find.byType(ListView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    await tester.tap(deviceSyncLink);
    await tester.pumpAndSettle();

    expect(find.text('Device Sync'), findsOneWidget);
  });

  testWidgets('reset to defaults dialog shows and works', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final resetBtn = find.text('Reset to Defaults');
    await tester.dragUntilVisible(
      resetBtn,
      find.byType(ListView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    await tester.tap(resetBtn);
    await tester.pumpAndSettle();

    expect(find.text('Reset Settings?'), findsOneWidget);

    await tester.tap(find.text('Reset').last);
    await tester.pumpAndSettle();

    expect(find.text('Settings reset to defaults'), findsOneWidget);
  });

  testWidgets('delete account dialog shows and works', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final deleteBtn = find.text('Delete Account');
    await tester.dragUntilVisible(
      deleteBtn,
      find.byType(ListView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Account?'), findsOneWidget);

    await tester.tap(find.text('Delete Forever'));
    // Advance the fake clock until the snackbar appears
    bool found = false;
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (tester.any(find.text('Account deleted successfully.'))) {
        found = true;
        break;
      }
    }
    
    expect(found, isTrue, reason: 'Account deleted successfully text not found');

    expect(find.text('Account deleted successfully.'), findsOneWidget);
  });

  testWidgets('request data export shows snackbar', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final exportBtn = find.text('Request My Data');
    await tester.dragUntilVisible(exportBtn, find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    await tester.tap(exportBtn);
    await tester.pump(); // triggers snackbar
    await tester.pump(const Duration(milliseconds: 100)); // animation

    expect(find.byType(SnackBar), findsOneWidget);
    await tester.pumpAndSettle();
  });
  
  testWidgets('developer mode tap unlock works', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final versionText = find.text('Wellnex v1.0.0');
    await tester.dragUntilVisible(
      versionText,
      find.byType(ListView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    // Tap 7 times
    for (int i = 0; i < 7; i++) {
      await tester.tap(versionText);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100)); // snackbar might appear
    }
    
    await tester.pumpAndSettle();
    
    // Should navigate to diagnostics
    expect(find.text('Diagnostics'), findsOneWidget);
  });

  testWidgets('dropdowns change values', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final distanceUnitText = find.text('Kilometers');
    await tester.dragUntilVisible(distanceUnitText, find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    // Tap distance unit dropdown
    final distanceDropdown = find.byType(DropdownButton<String>).first;
    await tester.dragUntilVisible(distanceDropdown, find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    
    await tester.tap(distanceDropdown);
    await tester.pumpAndSettle();
    
    // Select Miles
    await tester.tap(find.text('Miles').last);
    await tester.pumpAndSettle();

    expect(find.text('Miles'), findsWidgets);
    
    // Change language
    final langDropdown = find.text('English').last;
    final langMenu = find.byType(PopupMenuButton<String>).first;
    await tester.dragUntilVisible(langMenu, find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(langMenu);
    await tester.pumpAndSettle();
    
    await tester.tap(find.text('Français').last);
    await tester.pumpAndSettle();
  });
}
