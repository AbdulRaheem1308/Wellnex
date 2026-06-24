import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:confetti/confetti.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/router/app_router.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import 'package:wellnex_app/l10n/app_localizations.dart';
import '../providers/dashboard_provider.dart';

// New Widgets
import '../widgets/dashboard_header.dart';
import 'package:wellnex_app/features/ai/presentation/widgets/ai_suggestions_widget.dart';
import '../widgets/hero_progress_card.dart';
import '../widgets/level_coin_row.dart';
import '../widgets/streak_banner.dart';
import '../widgets/daily_stats_row.dart';
import '../widgets/quick_action_grid.dart';
import '../widgets/motivation_footer_banner.dart';

/// Home Dashboard Screen 2.0 - Redesigned
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _progressAnimController;
  late Animation<double> _progressAnimation;
  late ConfettiController _confettiController;
  bool _hasPlayedConfetti = false;
  
  @override
  void initState() {
    super.initState();
    
    // Animation controller for progress ring
    _progressAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _progressAnimController, curve: Curves.easeOutCubic),
    );
    
    // Fetch today's data
    Future.microtask(() {
      ref.read(dashboardProvider.notifier).fetchTodayData();
    });
  }

  @override
  void dispose() {
    _progressAnimController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardProvider);
    
    // Listen for errors (Commented out to prevent intrusive popups)
    /*
    ref.listen(dashboardProvider, (prev, next) {
      if (!next.isLoading && next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
    */

    // Loading State
    if (dashboard.isLoading && dashboard.todaySteps == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Error State (Full Screen if no data)
    if (dashboard.error != null && dashboard.todaySteps == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  AppLocalizations.of(context)?.dashboardError ?? 'Something went wrong. Please check your internet connection and try again.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(dashboardProvider.notifier).fetchTodayData(),
                child: Text(AppLocalizations.of(context)?.retry ?? 'Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!dashboard.isLoading && dashboard.todaySteps != null) {

      
      // Check for goal completion
      final steps = dashboard.todaySteps?.stepCount ?? 0;
      final goal = dashboard.todaySteps?.goal ?? 10000;
      if (steps >= goal && !_hasPlayedConfetti) {
        _confettiController.play();
        _hasPlayedConfetti = true;
      }
    }

    final steps = dashboard.todaySteps?.stepCount ?? 0;
    final goal = dashboard.todaySteps?.goal ?? 10000;
    final stepsToGo = (goal - steps).clamp(0, goal);
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: () => ref.read(dashboardProvider.notifier).fetchTodayData(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Header
                    DashboardHeader(
                      user: dashboard.user,
                      unreadCount: ref.watch(notificationsProvider).unreadCount,
                      onNotificationTap: () => context.push(AppRoutes.notifications),
                      onSettingsTap: () => context.push(AppRoutes.settings),
                      onProfileTap: () => context.push(AppRoutes.profile),
                      onRefreshTap: () => ref.read(dashboardProvider.notifier).fetchTodayData(),
                    ).animate().fadeIn(),

                    const SizedBox(height: 16),
                    
                    if (!dashboard.healthAuthorized)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Material(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () => context.push(AppRoutes.deviceSync),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Colors.red),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      AppLocalizations.of(context)?.localeName == 'en' 
                                          ? 'Health tracking not authorized. Tap to connect.' 
                                          : 'Health tracking not authorized. Tap to connect.',
                                      style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: Colors.red),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ).animate().fadeIn(),
                    
                    // 1.5 AI Suggestions
                    const AiSuggestionsWidget(),

                    const SizedBox(height: 16),
                    
                    // 2. Hero Progress Card (Animated)
                    TweenAnimationBuilder<int>(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      tween: IntTween(begin: 0, end: steps),
                      builder: (context, animatedSteps, child) {
                        return HeroProgressCard(
                          steps: animatedSteps,
                          goal: goal,
                          onAdjustGoal: () => _showAdjustGoalDialog(context, goal),
                        );
                      },
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
                    
                    const SizedBox(height: 20),

                    // 3. Daily Stats Grid
                    DailyStatsRow(
                      distanceKm: dashboard.todaySteps?.distanceKm ?? 0,
                      calories: dashboard.todaySteps?.caloriesBurned ?? 0,
                      minutes: dashboard.todaySteps?.activeMinutes ?? 0,
                    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, end: 0),
                    
                    const SizedBox(height: 20),

                    // 4. Motivation Footer
                    MotivationFooterBanner(stepsToGo: stepsToGo)
                        .animate().fadeIn(delay: 700.ms),

                    const SizedBox(height: 20),
                    
                    // 5. Level & Coin Row
                    LevelCoinRow(
                      level: dashboard.xpLevel,
                      currentXp: dashboard.xpCurrentProgress,
                      nextLevelXp: dashboard.xpToNextLevel,
                      coins: dashboard.wallet?.balance ?? 0,
                      onLevelTap: () => context.push(AppRoutes.gamification),
                      onCoinTap: () => context.push(AppRoutes.rewards), // Rewards tab includes wallet
                    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),
                    
                    const SizedBox(height: 20),
                    
                    // 6. Streak Banner
                    StreakBanner(
                      streakDays: dashboard.streak?.currentStreak ?? 0,
                      bestStreak: dashboard.streak?.longestStreak ?? 0,
                      onTap: () => context.push(AppRoutes.streak),
                    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),
                    
                    const SizedBox(height: 20),
                    
                    // 7. Quick Action Grid
                    QuickActionGrid(
                      onChallengesTap: () => context.push(AppRoutes.challenges),
                      onOffersTap: () => context.push(AppRoutes.offers),
                      onCommunityTap: () => context.push('/community'),
                      onTeamsTap: () => context.push(AppRoutes.teams),
                      onActivitiesTap: () => context.push(AppRoutes.activityLog),
                      onHistoryTap: () => context.push(AppRoutes.activityHistory),
                    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1, end: 0),
                    
                    const SizedBox(height: 10),
                    // const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
          
          // Confetti Overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
            ),
          ),
        ],
      ),
    );
  }

  void _showAdjustGoalDialog(BuildContext context, int currentGoal) {
    final TextEditingController goalController = TextEditingController(text: currentGoal.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.setDailyGoal ?? 'Set Daily Goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppLocalizations.of(context)?.enterNewTarget ?? 'Enter your new target for daily steps:'),
            const SizedBox(height: 16),
            TextField(
              controller: goalController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)?.stepsGoal ?? 'Steps Goal',
                border: const OutlineInputBorder(),
                suffixText: AppLocalizations.of(context)?.steps ?? 'steps',
              ),
              autofocus: true,
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          Row(
            children: [
              // Cancel Button
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel', style: const TextStyle(color: Colors.grey)),
                ),
              ),
              const SizedBox(width: 12),
              
              // Save Button
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final newGoal = int.tryParse(goalController.text.replaceAll(',', ''));
                    if (newGoal != null && newGoal > 0) {
                      ref.read(dashboardProvider.notifier).updateDailyGoal(newGoal);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppLocalizations.of(context)?.goalUpdated(newGoal) ?? 'Goal updated to $newGoal steps!')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(AppLocalizations.of(context)?.saveGoal ?? 'Save Goal', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
