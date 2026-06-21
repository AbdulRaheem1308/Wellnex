import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/api_service.dart';

class StreakState {
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActiveDate;
  final int? nextMilestone;
  final int? daysToMilestone;
  final List<DateTime> activeDates;
  final List<String> milestones;
  final bool isLoading;
  final String? error;

  StreakState({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastActiveDate,
    this.nextMilestone,
    this.daysToMilestone,
    this.activeDates = const [],
    this.milestones = const [],
    this.isLoading = false,
    this.error,
  });

  StreakState copyWith({
    int? currentStreak,
    int? longestStreak,
    DateTime? lastActiveDate,
    int? nextMilestone,
    int? daysToMilestone,
    List<DateTime>? activeDates,
    List<String>? milestones,
    bool? isLoading,
    String? error,
  }) {
    return StreakState(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      nextMilestone: nextMilestone ?? this.nextMilestone,
      daysToMilestone: daysToMilestone ?? this.daysToMilestone,
      activeDates: activeDates ?? this.activeDates,
      milestones: milestones ?? this.milestones,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class StreakNotifier extends StateNotifier<StreakState> {
  final ApiService _apiService;

  StreakNotifier(this._apiService) : super(StreakState()) {
    loadStreak();
  }

  Future<void> loadStreak() async {
    state = state.copyWith(isLoading: true);
    try {
      // Fetch streak info and step history in parallel
      final results = await Future.wait([
        _apiService.get('/rewards/streak'),
        _apiService.get('/steps/history?limit=180'), // Get last ~6 months of activity
      ]);
      
      final streakData = results[0].data;
      final historyResponse = results[1].data;

      // Parse active dates from step history
      final List<DateTime> activeDates = [];
      
      
      // Handle response - could be { data: [...] } or just [...]
      List? historyList;
      if (historyResponse is List) {
        historyList = historyResponse;
      } else if (historyResponse is Map && historyResponse['data'] != null) {
        historyList = historyResponse['data'] as List;
      }
      
      if (historyList != null && historyList.isNotEmpty) {
        for (var entry in historyList) {
          final stepCount = entry['stepCount'] ?? 0;
          if (stepCount > 0) {
            // Handle both string and DateTime date formats
            final dateValue = entry['date'];
            DateTime? date;
            if (dateValue is String) {
              date = DateTime.tryParse(dateValue);
            } else if (dateValue is DateTime) {
              date = dateValue;
            }
            if (date != null) {
              activeDates.add(date);
            }
          }
        }
      } else {
      }

      state = state.copyWith(
        currentStreak: streakData['currentStreak'] ?? 0,
        longestStreak: streakData['longestStreak'] ?? 0,
        lastActiveDate: streakData['lastActiveDate'] != null
            ? DateTime.parse(streakData['lastActiveDate'])
            : null,
        nextMilestone: streakData['nextMilestone'],
        daysToMilestone: streakData['daysToMilestone'],
        activeDates: activeDates,
        milestones: [], // Milestones now come from achievements API
        isLoading: false,
      );
    } catch (e) {
      // On error, show empty state
      state = state.copyWith(
        isLoading: false, 
        error: ApiError.from(e).message,
        activeDates: [],
        milestones: [],
      );
    }
  }

  // Removed _loadDemoData

}

final streakProvider = StateNotifierProvider.autoDispose<StreakNotifier, StreakState>((ref) {
  return StreakNotifier(ref.watch(apiServiceProvider));
});
