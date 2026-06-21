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

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Wait for animation
    await Future.delayed(const Duration(milliseconds: 2500));
    
    if (!mounted) return;
    
    try {
      // Check if onboarding is complete
      final onboardingComplete = StorageService.isOnboardingComplete();
      if (!onboardingComplete) {
        context.go(AppRoutes.onboarding);
        return;
      }
      
      // Check if user is logged in
      final token = await StorageService.getAccessToken();
      
      if (!mounted) return;

      if (token != null) {
        final user = StorageService.getUser();
        if (user != null && (user['name'] == null || (user['name'] as String).isEmpty || user['heightCm'] == null || user['weightKg'] == null)) {
          context.go(AppRoutes.completeProfile);
        } else {
          context.go(AppRoutes.home);
        }
      } else {
        context.go(AppRoutes.login);
      }
    } catch (e) {
      debugPrint("Splash Screen: Error during auth check: $e");
      if (mounted) {
        context.go(AppRoutes.login);
      }
    }
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
