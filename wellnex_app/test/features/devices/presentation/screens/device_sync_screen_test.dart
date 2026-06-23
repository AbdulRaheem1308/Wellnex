import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wellnex_app/features/devices/presentation/screens/device_sync_screen.dart';
import 'package:wellnex_app/l10n/app_localizations.dart';

void main() {
  setUp(() {
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
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'requestPermissions') {
          return {1: 1}; // 1 = PermissionStatus.granted
        }
        if (methodCall.method == 'checkPermissionStatus') {
          return 1;
        }
        return 1;
      },
    );
  });

  Widget createWidgetUnderTest() {
    return const ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DeviceSyncScreen(),
      ),
    );
  }

  testWidgets('DeviceSyncScreen loads health status and shows success', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // Allow Future to complete
    
    expect(find.text('Connected Sources'), findsOneWidget);
  });
}
