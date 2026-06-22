import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'core/utils/platform_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:wellnex_app/l10n/app_localizations.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'services/storage_service.dart';
import 'services/ad_service.dart';
import 'core/services/remote_config_service.dart';
import 'features/settings/presentation/providers/settings_provider.dart';
import 'core/services/background_service.dart';
import 'core/services/consent_service.dart';
import 'core/services/push_notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:safe_device/safe_device.dart';
import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

@visibleForTesting
bool debugMockCriticalError = false;

void main() {
  runZonedGuarded(() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      if (debugMockCriticalError) throw Exception("Simulated Critical Error");
      
      // Strip debugPrint logs in production for security and performance
      if (kReleaseMode) {
        debugPrint = (String? message, {int? wrapWidth}) {};
      }
      
      // Check production configuration
      AppConstants.checkProductionConfig();

      // Initialize Services safely
      if (isAndroid || isIOS) {
        await Firebase.initializeApp();
        
        // Pass all uncaught "fatal" errors from the framework to Crashlytics
        FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

        // Initialize PostHog
        try {
          final postHogKey = const String.fromEnvironment('POSTHOG_API_KEY', defaultValue: '');
          if (postHogKey.isNotEmpty) {
            final config = PostHogConfig(postHogKey);
            await Posthog().setup(config);
            await Posthog().capture(eventName: 'app_opened');
          }
        } catch (e) {
          debugPrint('Failed to initialize PostHog: $e');
        }
      }
      
      await Hive.initFlutter();
      await StorageService.init();

      // --- Security: Jailbreak, Root, and Emulator Detection ---
      if (isAndroid || isIOS) {
        try {
          final isJailBroken = await SafeDevice.isJailBroken;
          final isRealDevice = await SafeDevice.isRealDevice;
          final isMockLocation = await SafeDevice.isMockLocation;
          
          if (isJailBroken) {
            throw Exception("Security Violation: Jailbroken or Rooted device detected.");
          }
          if (!isRealDevice) {
            if (kReleaseMode) {
              throw Exception("Security Violation: wellnex is not supported on emulators or virtual machines.");
            }
            debugPrint("Warning: App is running on an emulator.");
          }
          if (isMockLocation) {
            if (kReleaseMode) {
              throw Exception("Security Violation: Mock location / GPS spoofing is prohibited.");
            }
            debugPrint("Warning: Mock location detected.");
          }
        } catch (e) {
          debugPrint("SafeDevice check failed or blocked: $e");
          if (e.toString().contains("Security Violation")) {
             rethrow; // Pass it to the UI error screen
          }
        }
      }
      // ---------------------------------------------------------

      if (isAndroid || isIOS) {
        try {
          await BackgroundService.init();
          final isBgSyncEnabled = StorageService.get('backgroundSyncEnabled', defaultValue: true) ?? true;
          if (isBgSyncEnabled) {
            await BackgroundService.registerPeriodicTask();
          }
        } catch (e) {
          debugPrint("Background Service init/register failed (non-fatal): $e");
        }
      }
      
      // Set preferred orientations
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      
      // Set system UI overlay style
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      );
      
      final container = ProviderContainer();

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const WellnexApp(),
        ),
      );

      // Initialize Push Notifications (non-fatal – won't block launch)
      if (isAndroid || isIOS) {
        try {
          await container.read(pushNotificationServiceProvider).initialize();
        } catch (e) {
          debugPrint('Push notification init failed (non-fatal): $e');
        }
      }

      // Initialize Consent & Ads (Post-Launch)
      try {
        if (isAndroid || isIOS) {
          await consentServiceProvider.requestConsentInfoUpdate();
          final canInitAds = await consentServiceProvider.canInitializeAds();
          if (canInitAds) {
            await container.read(remoteConfigServiceProvider).initialize();
            container.read(adServiceProvider).initialize();
          }
        }
      } catch (e) {
        debugPrint("Consent/Ads init error: $e");
      }

    } catch (e, stack) {
      debugPrint("CRITICAL STARTUP ERROR: $e");
      debugPrintStack(stackTrace: stack);
      // Launch Safe Mode UI
      runApp(MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: SelectableText(
                "App Failed to Initialize:\n$e",
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ));
    }
  }, (error, stack) {
    debugPrint("Uncaught Error in Zone: $error");
    if (isAndroid || isIOS) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
  });
}

class WellnexApp extends ConsumerWidget {
  const WellnexApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final settings = ref.watch(settingsProvider);
    
    return MaterialApp.router(
      title: 'Wellnex',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _getThemeMode(settings.themeMode),
      routerConfig: router,
      
      // Localization
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'), // English (US - Default)
        Locale('en', 'GB'), // English (UK)
        Locale('en', 'IN'), // English (India)
        Locale('hi'),       // Hindi
      ],
    );
  }

  ThemeMode _getThemeMode(String mode) {
    switch (mode) {
      case 'light': return ThemeMode.light;
      case 'dark': return ThemeMode.dark;
      case 'system': 
      default: return ThemeMode.system;
    }
  }
}
