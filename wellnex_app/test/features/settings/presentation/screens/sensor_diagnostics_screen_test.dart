import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wellnex_app/features/settings/presentation/screens/sensor_diagnostics_screen.dart';
import 'package:wellnex_app/services/storage_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final temp = await Directory.systemTemp.createTemp();
    Hive.init(temp.path);
    if (!Hive.isBoxOpen('wellnex_storage')) {
      await StorageService.init();
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'bg_sync_last_run': '2023-01-01',
      'bg_sync_status': 'Success',
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'checkPermissionStatus') return 1; // granted
        if (methodCall.method == 'requestPermissions') return {29: 1, 2: 1}; // granted
        return 1;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('safe_device'),
      (MethodCall methodCall) async {
        final m = methodCall.method.toLowerCase();
        if (m.contains('realdevice')) return true;
        if (m.contains('jailbroken')) return false;
        if (m.contains('mocklocation')) return false;
        return true;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_health'),
      (MethodCall methodCall) async {
        final m = methodCall.method;
        if (m == 'requestAuthorization') return true;
        if (m == 'getTotalStepsInInterval') return 5000;
        if (m == 'getHealthDataFromTypes') return [];
        return true;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('be.tramckrijte.workmanager/workmanager'),
      (MethodCall methodCall) async {
        return true;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/device_info_plus'),
      (MethodCall methodCall) async {
        return {
          'isPhysicalDevice': true,
        };
      },
    );
  });

  Widget createWidgetUnderTest() {
    return const ProviderScope(
      child: MaterialApp(
        home: SensorDiagnosticsScreen(),
      ),
    );
  }

  Future<void> waitForListView(WidgetTester tester) async {
    bool found = false;
    for (int i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(ListView).evaluate().isNotEmpty) {
        found = true;
        break;
      }
    }
    if (!found) {
      throw Exception('ListView never appeared! _isLoading must be stuck.');
    }
  }

  testWidgets('renders diagnostics and loads safe device info', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await waitForListView(tester);

    expect(find.text('Sensor & Sync Diagnostics', skipOffstage: false), findsOneWidget);
    expect(find.text('Health API Tracking', skipOffstage: false), findsOneWidget);
  });

  testWidgets('refresh button triggers reload', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await waitForListView(tester);

    await tester.tap(find.byType(IconButton).first);
    await tester.pump(const Duration(milliseconds: 100));
    await waitForListView(tester);

    expect(find.text('Sensor & Sync Diagnostics', skipOffstage: false), findsOneWidget);
  });

  testWidgets('re-test health api fetch button', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await waitForListView(tester);

    final finder = find.text('Re-Test Health API Fetch', skipOffstage: false);
    await tester.dragUntilVisible(finder, find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 100));
    await waitForListView(tester);
  });

  testWidgets('force trigger background task button', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await waitForListView(tester);

    final finder = find.text('Force Trigger Background Sync Task', skipOffstage: false);
    await tester.dragUntilVisible(finder, find.byType(ListView), const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 100));
    await waitForListView(tester);

    expect(find.byType(SnackBar), findsOneWidget);
  });
}
