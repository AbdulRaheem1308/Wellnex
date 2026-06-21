import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:posthog_flutter/posthog_flutter.dart';


import '../../../../core/theme/app_theme.dart';
import '../../../../core/router/app_router.dart';
import '../../../../services/api_service.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../dashboard/presentation/widgets/weekly_steps_chart.dart';
import '../../../dashboard/presentation/widgets/monthly_steps_chart.dart';
import '../../../dashboard/presentation/widgets/calorie_trend_chart.dart';

/// Step Analytics Screen with charts
class StepAnalyticsScreen extends ConsumerStatefulWidget {
  const StepAnalyticsScreen({super.key});

  @override
  ConsumerState<StepAnalyticsScreen> createState() => _StepAnalyticsScreenState();
}

class _StepAnalyticsScreenState extends ConsumerState<StepAnalyticsScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _weeklyData;
  Map<String, dynamic>? _monthlyData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    try {
      Posthog().capture(eventName: 'view_step_analytics');
    } catch (_) {
      // Ignore during tests
    }
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final api = ref.read(apiServiceProvider);
      final results = await Future.wait([
        api.get('/steps/weekly'),
        api.get('/steps/monthly'),
      ]);
      
      if (mounted) {
        setState(() {
          _weeklyData = results[0].data;
          _monthlyData = results[1].data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load analytics: $e'), backgroundColor: AppTheme.error),
        );
        setState(() {
          _weeklyData ??= _getEmptyWeeklyData();
          _monthlyData ??= _getEmptyMonthlyData();
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _getEmptyWeeklyData() {
    return {
      'totalSteps': 0,
      'averageSteps': 0,
      'totalCalories': 0,
      'totalDistanceKm': 0.0,
      'activeDays': 0,
      'dailyBreakdown': [
        {'dayName': 'Mon', 'date': DateTime.now().subtract(const Duration(days: 6)).toIso8601String(), 'stepCount': 0},
        {'dayName': 'Tue', 'date': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(), 'stepCount': 0},
        {'dayName': 'Wed', 'date': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(), 'stepCount': 0},
        {'dayName': 'Thu', 'date': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(), 'stepCount': 0},
        {'dayName': 'Fri', 'date': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'stepCount': 0},
        {'dayName': 'Sat', 'date': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(), 'stepCount': 0},
        {'dayName': 'Sun', 'date': DateTime.now().toIso8601String(), 'stepCount': 0},
      ],
    };
  }

  Map<String, dynamic> _getEmptyMonthlyData() {
    final now = DateTime.now();
    final monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 
                        'July', 'August', 'September', 'October', 'November', 'December'];
    return {
      'monthName': monthNames[now.month - 1],
      'totalSteps': 0,
      'averageSteps': 0,
      'activeDays': 0,
      'totalDaysInMonth': DateTime(now.year, now.month + 1, 0).day,
      'bestDay': null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildWeeklyTab(context, isDark),
                        _buildMonthlyTab(context, isDark),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Tooltip(
            message: 'Go back',
            child: IconButton(
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  context.go(AppRoutes.home);
                }
              },
              icon: Icon(Icons.arrow_back_ios_new, size: 20, color: Theme.of(context).iconTheme.color),
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).cardColor,
                padding: const EdgeInsets.all(12),
                minimumSize: const Size(48, 48),
              ),
              tooltip: 'Go back',
            ),
          ),
          Semantics(
            label: 'Analytics period selector',
            child: Container(
              height: 44,
              width: 200,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                dividerColor: Colors.transparent,
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                tabs: const [
                  Tab(text: 'Weekly'),
                  Tab(text: 'Monthly'),
                ],
              ),
            ),
          ),
          Tooltip(
            message: 'Refresh data',
            child: IconButton(
              onPressed: () => _fetchData(isRefresh: true),
              icon: Icon(Icons.refresh, size: 24, color: Theme.of(context).iconTheme.color),
              tooltip: 'Refresh data',
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyTab(BuildContext context, bool isDark) {
    final data = _weeklyData!;
    final dailyBreakdown = List<Map<String, dynamic>>.from(data['dailyBreakdown'] ?? []);

    // Convert API data to List<DailyStep> for the shared widget
    final weeklyHistory = dailyBreakdown.map((day) {
      return DailyStep(
        date: DateTime.parse(day['date']), // Ensure YYYY-MM-DD parsing works
        steps: day['stepCount'],
      );
    }).toList();

    // Use real daily step goal from dashboardProvider (default 10000 if not yet loaded)
    final dashboardState = ref.watch(dashboardProvider);
    final dailyGoal = dashboardState.todaySteps?.goal ?? 10000;
    final weeklyGoalTarget = dailyGoal * 7;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
           // 1. Hero Card
           _buildTotalStepsHero(
             context, 
             data['totalSteps'] ?? 0, 
             'This Week', 
             goalLabel: 'Weekly Goal',
             goalTarget: weeklyGoalTarget,
           ),
           const SizedBox(height: 24),
           
           // 2. Chart Section (Now using the Shared Widget from Streak Screen)
           Text(
             'Activity Trends',
             style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
           ),
           const SizedBox(height: 16),
           WeeklyStepsChart(weeklyHistory: weeklyHistory),
           
           const SizedBox(height: 24),
           CalorieTrendChart(weeklyHistory: weeklyHistory),
           const SizedBox(height: 24),
           
           // 3. Metrics Grid
           Text(
             'Highlights',
             style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
           ),
           const SizedBox(height: 16),
           _buildMetricsGrid(context, data, isDark),
           
           const SizedBox(height: 24),

           // 4. Complete Health Insights Section
           Text(
             'Health Insights',
             style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
           ),
           const SizedBox(height: 16),
           _buildInsightCard(
             context,
             title: 'Peak Performance',
             description: 'You burned the most calories on active intervals! Keep maintaining this daily energy burst.',
             icon: Icons.flash_on_rounded,
             iconColor: AppTheme.accentOrange,
           ),
           _buildInsightCard(
             context,
             title: 'Active Consistency',
             description: 'You completed active workouts on ${data['activeDays']} days this week. Excellent stamina!',
             icon: Icons.favorite_rounded,
             iconColor: AppTheme.accentPink,
           ),
           const SizedBox(height: 32),
        ],
      ),
    );
  }



  Widget _buildTotalStepsHero(
    BuildContext context, 
    int steps, 
    String subtitle, {
    double? trendPercentage,
    required String goalLabel,
    required int goalTarget,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF334155)], // Premium dark gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
           BoxShadow(
             color: const Color(0xFF0F172A).withValues(alpha: 0.4),
             blurRadius: 20,
             offset: const Offset(0, 10),
           ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitle.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatNumber(steps),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.insights, color: AppTheme.primaryGreen, size: 32),
              ),
            ],
          ),
          if (trendPercentage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: trendPercentage >= 0 ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    trendPercentage >= 0 ? Icons.trending_up : Icons.trending_down,
                    color: trendPercentage >= 0 ? Colors.greenAccent : Colors.redAccent,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${trendPercentage >= 0 ? '+' : ''}${trendPercentage.toStringAsFixed(1)}% vs last ${subtitle.toLowerCase().contains('week') ? 'week' : 'month'}',
                    style: TextStyle(
                      color: trendPercentage >= 0 ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          // Progress Bar within Hero
          Semantics(
            label: '$goalLabel: ${(steps / goalTarget * 100).toInt()}% complete. $steps of $goalTarget steps.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(goalLabel, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    Text(
                      '${(steps / goalTarget * 100).toInt()}%',
                      style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (steps / goalTarget).clamp(0.0, 1.0),
                    backgroundColor: Colors.white10,
                    color: AppTheme.primaryGreen,
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildMetricsGrid(BuildContext context, Map<String, dynamic> data, bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                context,
                'Calories',
                '${data['totalCalories']}',
                'kcal',
                Icons.local_fire_department_rounded,
                const Color(0xFFFF6B6B),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                context,
                'Distance',
                '${data['totalDistanceKm']}',
                'km',
                Icons.map_outlined,
                const Color(0xFF4ECDC4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                context,
                'Avg Steps',
                '${data['averageSteps']}',
                '/day',
                Icons.speed_rounded,
                const Color(0xFFFFD93D),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                context,
                'Active Days',
                '${data['activeDays']}',
                'days',
                Icons.calendar_month_rounded,
                const Color(0xFFA8E6CF),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildMetricCard(BuildContext context, String title, String value, String unit, IconData icon, Color color) {
    return Semantics(
      label: '$title: $value $unit',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                ),
                if (unit == 'kcal')
                  ExcludeSemantics(
                    child: const Icon(Icons.arrow_outward, size: 14, color: Colors.green),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: value,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontFamily: 'Inter',
                        ),
                      ),
                      TextSpan(
                        text: ' $unit',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).disabledColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).disabledColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyTab(BuildContext context, bool isDark) {
    final data = _monthlyData!;
    final dailyBreakdown = List<Map<String, dynamic>>.from(data['dailyBreakdown'] ?? []);
    
    // Convert backend data; use empty list if breakdown is missing (no fake fallback data)
    final monthlyHistory = dailyBreakdown.isNotEmpty 
      ? dailyBreakdown.map((day) => DailyStep(
          date: DateTime.parse(day['date']), 
          steps: day['stepCount']
        )).toList()
      : <DailyStep>[];

    // Use real daily step goal from dashboardProvider (default 10000 if not yet loaded)
    final dashboardState = ref.watch(dashboardProvider);
    final dailyGoal = dashboardState.todaySteps?.goal ?? 10000;
    final monthlyGoalTarget = dailyGoal * 30;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            _buildTotalStepsHero(
              context, 
              data['totalSteps'] ?? 0, 
              'This Month', 
              goalLabel: 'Monthly Goal',
              goalTarget: monthlyGoalTarget,
            ),
           const SizedBox(height: 24),
           
           // Monthly Chart
           Text(
             'Activity Trends',
             style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
           ),
           const SizedBox(height: 16),
           MonthlyStepsChart(monthlyHistory: monthlyHistory),
           const SizedBox(height: 24),

           // Best Day Highlight
           if (data['bestDay'] != null) ...[
             Container(
               padding: const EdgeInsets.all(20),
               decoration: BoxDecoration(
                 gradient: LinearGradient(
                   colors: [AppTheme.accentYellow.withValues(alpha: 0.2), AppTheme.accentYellow.withValues(alpha: 0.03)],
                 ),
                 borderRadius: BorderRadius.circular(24),
                 border: Border.all(color: AppTheme.accentYellow.withValues(alpha: 0.25)),
               ),
               child: Row(
                 children: [
                   Container(
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(
                       color: isDark ? AppTheme.neutral800 : Colors.white,
                       shape: BoxShape.circle,
                       boxShadow: [
                         BoxShadow(
                           color: Colors.black.withValues(alpha: 0.04),
                           blurRadius: 8,
                         )
                       ],
                     ),
                     child: const Icon(Icons.emoji_events, color: AppTheme.accentYellow, size: 24),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         const Text('Best Performance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                         const SizedBox(height: 2),
                         Text(
                           '${data['bestDay']['stepCount']} steps on ${data['bestDay']['date']}', 
                           style: Theme.of(context).textTheme.bodySmall
                         ),
                       ],
                     ),
                   ),
                 ],
               ),
             ),
             const SizedBox(height: 24),
           ],
           
           Text(
             'Monthly Overview',
             style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
           ),
           const SizedBox(height: 16),
           _buildMetricsGrid(context, data, isDark),
           const SizedBox(height: 24),

           // Monthly Insights
           Text(
             'Monthly Milestone',
             style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
           ),
           const SizedBox(height: 16),
           _buildInsightCard(
             context,
             title: 'Walked Distance Milestone',
             description: 'You traversed a massive ${data['totalDistanceKm']} km this month! That is roughly the length of a marathon!',
             icon: Icons.emoji_events_rounded,
             iconColor: AppTheme.accentYellow,
           ),
           _buildInsightCard(
             context,
             title: 'Steady Progress',
             description: 'Your average step count of ${data['averageSteps']} per day shows fantastic endurance growth.',
             icon: Icons.trending_up_rounded,
             iconColor: AppTheme.success,
           ),
           const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInsightCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
  }) {
    return Semantics(
      label: '$title. $description',
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      // 12,500
      return number.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
    }
    return number.toString();
  }
}
