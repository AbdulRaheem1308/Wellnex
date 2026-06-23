import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:wellnex_app/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/router/app_router.dart';
import '../../../../services/storage_service.dart';

/// Splash Screen with animated logo
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// Override this in tests to skip the real delay and avoid fake-clock issues.
  @visibleForTesting
  static Duration? testSplashDelay;

  /// Determines which route the splash screen should navigate to based on the
  /// current auth/onboarding state. Extracted for unit-testability.
  @visibleForTesting
  static Future<String> resolveStartRoute() async {
    final onboardingComplete = StorageService.isOnboardingComplete();
    if (!onboardingComplete) return AppRoutes.onboarding;

    final token = await StorageService.getAccessToken();
    if (token == null) return AppRoutes.login;

    final user = StorageService.getUser();
    if (user != null && user['isProfileCreated'] != true) {
      return AppRoutes.completeProfile;
    }
    return AppRoutes.home;
  }

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  void _checkAuthAndNavigate() {
    // Wait for animation (or skip in tests via testSplashDelay).
    _navTimer = Timer(
        SplashScreen.testSplashDelay ?? const Duration(milliseconds: 2500), () async {
      if (!mounted) return;

      try {
        final route = await SplashScreen.resolveStartRoute();
        if (mounted) context.go(route);
      } catch (e) {
        debugPrint('Splash Screen: Error during auth check: $e');
        if (mounted) context.go(AppRoutes.login);
      }
    });
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Icon
              Semantics(
                label: 'Wellnex Logo',
                child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(51),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/splash_logo.png',
                  width: 80,
                  height: 80,
                ),
              ),
              )
                  .animate()
                  .scale(
                    duration: 600.ms,
                    curve: Curves.elasticOut,
                  )
                  .fadeIn(),
              
              const SizedBox(height: 32),
              
              // App Name
              Semantics(
                header: true,
                child: Text(
                  'Wellnex',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              )
                  .animate(delay: 300.ms)
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.3, end: 0),
              
              const SizedBox(height: 8),
              
              // Tagline
              Semantics(
                label: AppLocalizations.of(context)?.appTagline ?? 'Walk, Track, Earn',
                child: Text(
                  AppLocalizations.of(context)?.appTagline ?? 'Walk • Track • Earn',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withAlpha(230),
                    letterSpacing: 3,
                  ),
                ),
              )
                  .animate(delay: 500.ms)
                  .fadeIn(duration: 500.ms),
              
              const SizedBox(height: 80),
              
              // Loading indicator
              if (SplashScreen.testSplashDelay == null)
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                )
                    .animate(delay: 800.ms)
                    .fadeIn(duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}
