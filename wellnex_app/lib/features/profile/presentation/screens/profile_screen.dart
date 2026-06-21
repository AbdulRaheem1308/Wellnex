import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/router/app_router.dart';
import '../../../../services/storage_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../gamification/presentation/providers/streak_provider.dart';
import '../../../gamification/presentation/providers/gamification_provider.dart';
import '../../../gamification/presentation/providers/badges_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../providers/fitness_provider.dart';

/// Screen 24 — Enhanced User Profile with BMI Gauge, Fitness Level & Activity Prefs
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Refresh fitness state whenever screen mounts (e.g. after edit profile)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fitnessProvider.notifier).reload();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user    = StorageService.getUser();
    final streak  = ref.watch(streakProvider).currentStreak;
    final level   = ref.watch(gamificationProvider).level;

    ref.listen(badgesProvider, (prev, next) {
      if (!next.isLoading && next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context, user, streak, level),
          Container(
            color: AppTheme.primaryDark,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.accentYellow,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Badges'),
                Tab(text: 'Activity'),
                Tab(text: 'Settings'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildBadgesTab(),
                _buildActivityTab(),
                _buildSettingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════
  Widget _buildHeader(BuildContext context, Map<String, dynamic>? user,
      int streak, int level) {
    final dashboard  = ref.watch(dashboardProvider);
    final badgeCount = ref.watch(badgesProvider)
        .badges
        .where((b) => b.status == BadgeStatus.unlocked)
        .length;
    final totalSteps = dashboard.todaySteps?.stepCount ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 52, 16, 20),
      decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Stack(
                children: [
                  Builder(builder: (context) {
                    final avatarUrl = user?['avatarUrl'];
                    final hasAvatar =
                        avatarUrl != null && avatarUrl != 'default';
                    return Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: CircleAvatar(
                        backgroundColor: Colors.white24,
                        backgroundImage:
                            hasAvatar ? NetworkImage(avatarUrl) : null,
                        child: hasAvatar
                            ? null
                            : Text(
                                user?['name']?[0] ?? 'G',
                                style: const TextStyle(
                                    fontSize: 30,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                      ),
                    );
                  }),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Semantics(
                      label: 'Edit profile photo',
                      button: true,
                      child: GestureDetector(
                        onTap: () => context.push(AppRoutes.editProfile),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                              color: AppTheme.accentYellow,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.edit,
                              size: 14, color: AppTheme.primaryDark),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?['name'] ?? 'Guest User',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.military_tech,
                            color: AppTheme.accentYellow, size: 14),
                        const SizedBox(width: 4),
                        Text('Level $level  •  Wellnex Pro',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: 'Open settings',
                child: IconButton(
                  onPressed: () => context.push(AppRoutes.settings),
                  icon: const Icon(Icons.settings_outlined, color: Colors.white),
                  tooltip: 'Open settings',
                  style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _headerStat('$streak', 'Streak', Icons.local_fire_department),
              Container(width: 1, height: 30, color: Colors.white24),
              _headerStat(_fmt(totalSteps), 'Steps Today', Icons.directions_walk),
              Container(width: 1, height: 30, color: Colors.white24),
              _headerStat('$badgeCount', 'Badges', Icons.military_tech),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String value, String label, IconData icon) {
    return Semantics(
      label: '$label: $value',
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(icon, color: Colors.white70, size: 15),
              ),
              const SizedBox(width: 4),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
            ],
          ),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // OVERVIEW TAB
  // ═══════════════════════════════════════════════════════
  Widget _buildOverviewTab() {
    final fitness       = ref.watch(fitnessProvider);
    final dashboardState = ref.watch(dashboardProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // BMI GAUGE
        _buildBmiCard(fitness),
        const SizedBox(height: 20),

        // FITNESS LEVEL
        _buildFitnessLevelCard(fitness),
        const SizedBox(height: 20),

        // DAILY GOAL
        _buildGoalCard(fitness),
        const SizedBox(height: 20),

        // LIFETIME STATS
        if (dashboardState.userStats != null) ...[
          _sectionTitle('Lifetime Stats'),
          _buildLifetimeStatsCard(dashboardState.userStats!),
        ],
      ],
    );
  }

  // ─── BMI Gauge Card ───────────────────────────────────────────────────────
  Widget _buildBmiCard(FitnessState fitness) {
    final hasBmi = fitness.bmi != null;
    final bmiValue = fitness.bmi ?? 0.0;

    Color bmiColor() {
      if (bmiValue < 18.5) return AppTheme.secondaryBlue;
      if (bmiValue < 25.0) return AppTheme.primaryGreen;
      if (bmiValue < 30.0) return AppTheme.accentYellow;
      return AppTheme.error;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.monitor_weight_outlined,
                    color: AppTheme.primaryGreen, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Body Mass Index',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push(AppRoutes.editProfile),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.neutral100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Edit',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.neutral600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Gauge
          SizedBox(
            height: 140,
            child: hasBmi
                ? CustomPaint(
                    painter: _BmiGaugePainter(
                        bmi: bmiValue,
                        needleColor: bmiColor()),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              bmiValue.toStringAsFixed(1),
                              style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: bmiColor()),
                            ).animate().fadeIn(duration: 600.ms),
                            Text(
                              fitness.bmiCategory,
                              style: TextStyle(
                                  fontSize: 14,
                                  color: bmiColor(),
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : const Center(
                    child: Text(
                      'Add height & weight in Edit Profile\nto see your BMI',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: AppTheme.neutral400, fontSize: 14),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          // Color legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _bmiLegend('Under', AppTheme.secondaryBlue),
              _bmiLegend('Normal', AppTheme.primaryGreen),
              _bmiLegend('Over', AppTheme.accentYellow),
              _bmiLegend('Obese', AppTheme.error),
            ],
          ),
        ],
      ),
    ).animate().slideY(begin: 0.1, end: 0, duration: 400.ms).fadeIn();
  }

  Widget _bmiLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: AppTheme.neutral500)),
      ],
    );
  }

  // ─── Fitness Level Card ────────────────────────────────────────────────────
  Widget _buildFitnessLevelCard(FitnessState fitness) {
    final levelKey  = fitness.fitnessLevel;
    final meta      = kFitnessLevels[levelKey] ??
        kFitnessLevels['beginner']!;
    final label     = meta['label'] as String;
    final emoji     = meta['emoji'] as String;
    final nextLabel = meta['next'] != null
        ? (kFitnessLevels[meta['next']]!['label'] as String)
        : null;
    final nextMin   = meta['nextMin'] as int?;

    // Use today steps as proxy for avg (in a real app you'd average 30d)
    final dashboard    = ref.watch(dashboardProvider);
    final todaySteps   = dashboard.todaySteps?.stepCount ?? 0;
    final progress     = fitness.fitnessProgress(todaySteps);

    final Color levelColor;
    switch (levelKey) {
      case 'active':
        levelColor = AppTheme.secondaryBlue;
        break;
      case 'athlete':
        levelColor = AppTheme.accentPurple;
        break;
      case 'elite':
        levelColor = AppTheme.accentYellow;
        break;
      default:
        levelColor = AppTheme.primaryGreen;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [levelColor.withValues(alpha: 0.08), Theme.of(context).colorScheme.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: levelColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
              color: levelColor.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Fitness Level',
                      style: TextStyle(
                          color: AppTheme.neutral500, fontSize: 12)),
                  Text(label,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: levelColor)),
                ],
              ),
              const Spacer(),
              // Level badge chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: levelColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: levelColor.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(levelColor),
            ),
          ).animate().scaleX(begin: 0, duration: 700.ms, curve: Curves.easeOut),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toInt()}% progress',
                style: TextStyle(
                    fontSize: 12,
                    color: levelColor,
                    fontWeight: FontWeight.w600),
              ),
              if (nextLabel != null && nextMin != null)
                Text(
                  'Next: $nextLabel ($nextMin+ steps/day)',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.neutral400),
                )
              else
                const Text('🏆 Maximum Level!',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.accentYellow,
                        fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    ).animate().slideY(begin: 0.1, end: 0, duration: 500.ms, delay: 100.ms).fadeIn();
  }

  // ─── Goal Card ────────────────────────────────────────────────────────────
  Widget _buildGoalCard(FitnessState fitness) {
    final dashboard  = ref.watch(dashboardProvider);
    final todaySteps = dashboard.todaySteps?.stepCount ?? 0;
    final goal       = fitness.dailyStepGoal;
    final pct        = (todaySteps / goal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          // Ring
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: pct,
                  strokeWidth: 7,
                  backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryGreen),
                ),
                Text(
                  '${(pct * 100).toInt()}%',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Daily Goal',
                    style: TextStyle(
                        color: AppTheme.neutral500, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  '${_fmt(todaySteps)} / ${_fmt(goal)} steps',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color),
                ),
                const SizedBox(height: 4),
                Text(
                  pct >= 1.0
                      ? '🎉 Goal achieved today!'
                      : '${_fmt(goal - todaySteps)} steps to go',
                  style: TextStyle(
                      fontSize: 13,
                      color: pct >= 1.0
                          ? AppTheme.primaryGreen
                          : AppTheme.neutral400),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.push(AppRoutes.editProfile),
            child: const Icon(Icons.edit_outlined,
                color: AppTheme.neutral400, size: 20),
          ),
        ],
      ),
    ).animate().slideY(begin: 0.1, end: 0, duration: 500.ms, delay: 200.ms).fadeIn();
  }

  // ─── Lifetime Stats Card ──────────────────────────────────────────────────
  Widget _buildLifetimeStatsCard(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _statItem(
                      'Total Steps',
                      _fmt(stats['lifetimeSteps'] ?? 0),
                      Icons.directions_walk,
                      AppTheme.primaryGreen)),
              Expanded(
                  child: _statItem(
                      'Best Day',
                      _fmt(stats['bestDaySteps'] ?? 0),
                      Icons.emoji_events,
                      AppTheme.accentOrange)),
            ],
          ),
          const Divider(height: 28),
          Row(
            children: [
              Expanded(
                  child: _statItem(
                      'Distance',
                      '${(double.tryParse(stats['lifetimeDistanceKm']?.toString() ?? '0') ?? 0).toStringAsFixed(1)} km',
                      Icons.map,
                      AppTheme.accentPurple)),
              Expanded(
                  child: _statItem(
                      'Calories',
                      '${(stats['lifetimeCalories'] ?? 0) ~/ 1000}k kcal',
                      Icons.local_fire_department,
                      AppTheme.error)),
            ],
          ),
        ],
      ),
    ).animate().slideY(begin: 0.1, end: 0, duration: 500.ms, delay: 300.ms).fadeIn();
  }

  Widget _statItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value,
            style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Theme.of(context).textTheme.bodyLarge?.color)),
        Text(label,
            style:
                const TextStyle(color: AppTheme.neutral500, fontSize: 12)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // BADGES TAB — Enhanced with circular progress indicators
  // ═══════════════════════════════════════════════════════
  Widget _buildBadgesTab() {
    final state  = ref.watch(badgesProvider);
    final badges = state.badges;

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (badges.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.military_tech_outlined,
                size: 56, color: AppTheme.neutral300),
            const SizedBox(height: 16),
            const Text('No badges yet',
                style: TextStyle(color: AppTheme.neutral500, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Keep walking to unlock your first badge!',
                style:
                    TextStyle(color: AppTheme.neutral400, fontSize: 13)),
          ],
        ),
      );
    }

    // Sorting: unlocked first, then in-progress, then locked
    final sorted = [...badges]..sort((a, b) {
        int rank(BadgeStatus s) {
          if (s == BadgeStatus.unlocked) return 0;
          if (s == BadgeStatus.inProgress) return 1;
          return 2;
        }
        return rank(a.status).compareTo(rank(b.status));
      });

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.78,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final badge   = sorted[index];
        final locked  = badge.status == BadgeStatus.locked;
        final inProg  = badge.status == BadgeStatus.inProgress;
        final unlocked = badge.status == BadgeStatus.unlocked;

        final Color ringColor = unlocked
            ? AppTheme.accentYellow
            : inProg
                ? AppTheme.secondaryBlue
                : AppTheme.neutral200;
        final Color iconColor = unlocked
            ? AppTheme.accentOrange
            : inProg
                ? AppTheme.secondaryBlue
                : AppTheme.neutral400;

        return Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Circular progress ring
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      value: locked ? 0.0 : badge.progress,
                      strokeWidth: 4,
                      backgroundColor: AppTheme.neutral100,
                      valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                    ),
                  ),
                  // Badge icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: unlocked
                          ? Colors.white
                          : AppTheme.neutral100,
                      boxShadow: unlocked
                          ? [
                              BoxShadow(
                                  color: AppTheme.accentOrange
                                      .withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3))
                            ]
                          : [],
                    ),
                    child: Icon(
                      locked
                          ? Icons.lock
                          : Icons.emoji_events,
                      size: 26,
                      color: iconColor,
                    ),
                  ),
                  // Unlocked checkmark
                  if (unlocked)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                            color: AppTheme.primaryGreen,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.check,
                            size: 12, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              badge.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: locked
                      ? AppTheme.neutral400
                      : AppTheme.neutral800),
            ),
            if (inProg)
              Text(
                '${(badge.progress * 100).toInt()}%',
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.secondaryBlue),
              ),
          ],
        )
            .animate(delay: (index * 40).ms)
            .fadeIn(duration: 350.ms)
            .scale(begin: const Offset(0.85, 0.85));
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // ACTIVITY TAB — Activity Preferences chips
  // ═══════════════════════════════════════════════════════
  Widget _buildActivityTab() {
    final fitness  = ref.watch(fitnessProvider);
    final selected = fitness.activityPreferences;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionTitle('Your Activity Preferences'),
        const Text(
          'Select the activities you enjoy. We\'ll personalise your goals and challenges.',
          style: TextStyle(color: AppTheme.neutral500, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 20),

        // Activity chips grid
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: kActivityOptions.map((activity) {
            final id      = activity['id']!;
            final label   = activity['label']!;
            final emoji   = activity['emoji']!;
            final isSelected = selected.contains(id);

            return GestureDetector(
              onTap: () =>
                  ref.read(fitnessProvider.notifier).toggleActivity(id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryGreen
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryGreen
                        : AppTheme.neutral200,
                    width: 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3))
                        ]
                      : [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2))
                        ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isSelected
                              ? Colors.white
                              : AppTheme.neutral700),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.check_circle,
                          size: 16, color: Colors.white70),
                    ],
                  ],
                ),
              ),
            )
                .animate(delay: (kActivityOptions.indexOf(activity) * 50).ms)
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.1, end: 0);
          }).toList(),
        ),

        if (fitness.isUpdating) ...[
          const SizedBox(height: 20),
          const Center(child: CircularProgressIndicator()),
        ],

        if (fitness.error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(fitness.error!,
                style: const TextStyle(color: AppTheme.error, fontSize: 13)),
          ),
        ],

        const SizedBox(height: 32),

        // Selected summary
        if (selected.isNotEmpty) ...[
          _sectionTitle('Selected (${selected.length})'),
          Wrap(
            spacing: 8,
            children: selected.map((id) {
              final act = kActivityOptions
                  .firstWhere((a) => a['id'] == id, orElse: () => {});
              if (act.isEmpty) return const SizedBox.shrink();
              return Chip(
                label: Text(
                    '${act['emoji']} ${act['label']}',
                    style: const TextStyle(fontSize: 12)),
                backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () =>
                    ref.read(fitnessProvider.notifier).toggleActivity(id),
              );
            }).toList(),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.neutral50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.neutral200),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline,
                    color: AppTheme.neutral400, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tap the activities above to personalise your experience.',
                    style:
                        TextStyle(color: AppTheme.neutral500, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // SETTINGS TAB
  // ═══════════════════════════════════════════════════════
  Widget _buildSettingsTab() {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionTitle('Corporate Wellness'),
        ListTile(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: AppTheme.primaryGreen.withValues(alpha: 0.05),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child:
                const Icon(Icons.business, color: AppTheme.primaryGreen),
          ),
          title: const Text('My Company',
              style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('View leaderboard and challenges'),
          trailing: const Icon(Icons.arrow_forward_ios,
              size: 16, color: AppTheme.neutral400),
          onTap: () => context.push(AppRoutes.companyJoin),
        ),
        const SizedBox(height: 24),

        _sectionTitle('Privacy & Visibility'),
        SwitchListTile(
          value: settings.isPublic,
          onChanged: notifier.togglePublicProfile,
          title: const Text('Public Profile'),
          subtitle: const Text('Allow others to view your profile'),
          activeThumbColor: AppTheme.primaryGreen,
        ),
        SwitchListTile(
          value: settings.showOnLeaderboard,
          onChanged: notifier.toggleShowOnLeaderboard,
          title: const Text('Show on Leaderboards'),
          subtitle: const Text('Compete with community and friends'),
          activeThumbColor: AppTheme.primaryGreen,
        ),
        SwitchListTile(
          value: settings.showMilestones,
          onChanged: notifier.toggleShowMilestones,
          title: const Text('Share Milestones'),
          subtitle:
              const Text('Auto-post achievements to community feed'),
          activeThumbColor: AppTheme.primaryGreen,
        ),
        const Divider(height: 32),

        _sectionTitle('Account'),
        ListTile(
          leading: const Icon(Icons.logout, color: AppTheme.error),
          title: const Text('Logout',
              style: TextStyle(color: AppTheme.error)),
          onTap: () async {
            // Show non-dismissible loader
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
            );
            
            // Add cooling period
            await Future.delayed(const Duration(milliseconds: 10000));
            
            if (mounted) {
              Navigator.pop(context); // Remove dialog
            }
            await ref.read(authProvider.notifier).logout();
            // authProvider automatically redirects to login
          },
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════
  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: AppTheme.neutral800)),
    );
  }

  String _fmt(int steps) {
    if (steps >= 1000000) return '${(steps / 1000000).toStringAsFixed(1)}M';
    if (steps >= 1000) return '${(steps / 1000).toStringAsFixed(0)}k';
    return '$steps';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BMI GAUGE PAINTER
// ═══════════════════════════════════════════════════════════════════════════
class _BmiGaugePainter extends CustomPainter {
  final double bmi;
  final Color needleColor;

  const _BmiGaugePainter({required this.bmi, required this.needleColor});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 18.0;
    // Fit radius within the canvas height and width
    final maxRadiusByHeight = size.height - strokeWidth;
    final maxRadiusByWidth = (size.width - strokeWidth) / 2;
    final radius = math.min(maxRadiusByHeight, maxRadiusByWidth);

    final cx = size.width / 2;
    final cy = size.height - (strokeWidth / 2); // Pivot at the bottom

    // Arc from 180° to 0° (left to right semicircle)
    const startAngle = math.pi;
    const sweepAngle = math.pi;

    // Zone colours: underweight | normal | overweight | obese
    final zones = [
      (AppTheme.secondaryBlue,  0.0,   0.28),  // BMI 10-18.5 → 28% of arc
      (AppTheme.primaryGreen,   0.28,  0.50),  // BMI 18.5-25
      (AppTheme.accentYellow,   0.50,  0.673), // BMI 25-30
      (AppTheme.error,          0.673, 1.0),   // BMI 30-40
    ];

    // Draw track background
    final trackPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      startAngle, sweepAngle, false, trackPaint,
    );

    // Draw coloured zone arcs
    for (final zone in zones) {
      final (color, from, to) = zone;
      final paint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth - 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        startAngle + sweepAngle * from,
        sweepAngle * (to - from),
        false,
        paint,
      );
    }

    // Compute needle angle from BMI (clamped 10..40)
    final t           = ((bmi - 10.0) / 30.0).clamp(0.0, 1.0);
    final needleAngle = math.pi + sweepAngle * t;

    final needleLength = radius - 10;
    final needleX = cx + needleLength * math.cos(needleAngle);
    final needleY = cy + needleLength * math.sin(needleAngle);

    // Start needle outside the text area to prevent overlap
    final innerRadius = 45.0;
    final startX = cx + innerRadius * math.cos(needleAngle);
    final startY = cy + innerRadius * math.sin(needleAngle);

    // Draw needle
    final needlePaint = Paint()
      ..color = needleColor
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(startX, startY), Offset(needleX, needleY), needlePaint);
  }

  @override
  bool shouldRepaint(_BmiGaugePainter old) =>
      old.bmi != bmi || old.needleColor != needleColor;
}
