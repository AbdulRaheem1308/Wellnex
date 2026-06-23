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
        if (methodCall.method == 'requestPermissions') return {2: 1}; // granted
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
        return false;
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
  });

  Widget createWidgetUnderTest() {
    return const ProviderScope(
      child: MaterialApp(
        home: SensorDiagnosticsScreen(),
      ),
    );
  }

  testWidgets('renders diagnostics and loads safe device info', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Sensor & Sync Diagnostics'), findsOneWidget);
    expect(find.text('Health API Tracking'), findsOneWidget);
  });

  testWidgets('refresh button triggers reload', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byType(IconButton).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Sensor & Sync Diagnostics'), findsOneWidget);
  });

  testWidgets('re-test health api fetch button', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final finder = find.text('Re-Test Health API Fetch');
    await tester.dragUntilVisible(finder, find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('force trigger background task button', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final finder = find.text('Force Trigger Background Sync Task');
    await tester.dragUntilVisible(finder, find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(SnackBar), findsOneWidget);
  });
}
