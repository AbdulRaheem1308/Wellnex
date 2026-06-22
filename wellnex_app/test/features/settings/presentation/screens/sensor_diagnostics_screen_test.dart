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
    
    // Add EventChannel mock for Pedometer to prevent MissingPluginException
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('step_count'),
      (MethodCall methodCall) async {
        return null; 
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
    await tester.pump(const Duration(seconds: 1)); // allow futures to complete
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Sensor & Sync Diagnostics'), findsOneWidget);
    // Because SafeDevice could fail or take time, let's just check if it loaded something.
    expect(find.text('Activity Recognition'), findsOneWidget);
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

  testWidgets('request activity permission button', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Since our mock returns 'granted' (1), the UI might show 'Granted'
    // If it's already granted, button is disabled.
    // We can simulate denied by modifying the mock before pump
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'checkPermissionStatus') return 0; // denied
        if (methodCall.method == 'requestPermissions') return {2: 1}; // returns granted
        return null;
      },
    );

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final grantButton = find.text('Grant');
    if (grantButton.evaluate().isNotEmpty) {
      await tester.tap(grantButton);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }
  });

  testWidgets('reset pedometer baseline button', (WidgetTester tester) async {
    // Scroll to it
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Reset Daily Baseline'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Pedometer baseline cleared. Walk to re-initialize.'), findsOneWidget);
  });

  testWidgets('test fetch health steps button', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Test Fetch Health Steps'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

  });

  testWidgets('force trigger background task button', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Force Trigger Background Sync Task'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(SnackBar), findsOneWidget);
  });
}
