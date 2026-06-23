import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/api_service.dart';
import '../../data/models/team_model.dart';

/// Teams state
class TeamsState {
  final List<Team> myTeams;
  final List<Team> publicTeams;
  final Team? currentTeam;
  final List<TeamChallenge> teamChallenges;
  final bool isLoading;
  final String? error;

  TeamsState({
    this.myTeams = const [],
    this.publicTeams = const [],
    this.currentTeam,
    this.teamChallenges = const [],
    this.isLoading = false,
    this.error,
  });

  TeamsState copyWith({
    List<Team>? myTeams,
    List<Team>? publicTeams,
    Team? currentTeam,
    List<TeamChallenge>? teamChallenges,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return TeamsState(
      myTeams: myTeams ?? this.myTeams,
      publicTeams: publicTeams ?? this.publicTeams,
      currentTeam: currentTeam ?? this.currentTeam,
      teamChallenges: teamChallenges ?? this.teamChallenges,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Teams provider
class TeamsNotifier extends StateNotifier<TeamsState> {
  final ApiService _api;

  TeamsNotifier(this._api) : super(TeamsState());

  void clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }

  /// Fetch user's teams
  Future<void> fetchMyTeams() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _api.get('/teams/my-teams');
      final teams = (response.data as List)
          .map((t) => Team.fromJson(t))
          .toList();
      state = state.copyWith(myTeams: teams, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Fetch public teams to join
  Future<void> fetchPublicTeams() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _api.get('/teams/public');
      final teams = (response.data as List)
          .map((t) => Team.fromJson(t))
          .toList();
      state = state.copyWith(publicTeams: teams, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Fetch team details
  Future<void> fetchTeamDetails(String teamId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _api.get('/teams/$teamId');
      final team = Team.fromJson(response.data);
      state = state.copyWith(currentTeam: team, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Create a new team
  Future<Team?> createTeam({
    required String name,
    required String description,
    int maxMembers = 10,
    bool isPublic = true,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _api.post('/teams', data: {
        'name': name,
        'description': description,
        'maxMembers': maxMembers,
        'isPublic': isPublic,
      });
      final team = Team.fromJson(response.data);
      state = state.copyWith(
        myTeams: [...state.myTeams, team],
        publicTeams: isPublic ? [...state.publicTeams, team] : state.publicTeams,
        isLoading: false,
      );
      return team;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// Join a team
  Future<bool> joinTeam(String teamId, {String? inviteCode}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _api.post('/teams/$teamId/join', data: {
        if (inviteCode != null) 'inviteCode': inviteCode,
      });
      await fetchMyTeams();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Leave a team
  Future<bool> leaveTeam(String teamId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _api.post('/teams/$teamId/leave');
      state = state.copyWith(
        myTeams: state.myTeams.where((t) => t.id != teamId).toList(),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Delete a team
  Future<bool> deleteTeam(String teamId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _api.delete('/teams/$teamId');
      state = state.copyWith(
        myTeams: state.myTeams.where((t) => t.id != teamId).toList(),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Fetch team challenges
  Future<void> fetchTeamChallenges(String teamId) async {
    try {
      final response = await _api.get('/teams/$teamId/challenges');
      final challenges = (response.data as List)
          .map((c) => TeamChallenge.fromJson(c))
          .toList();
      state = state.copyWith(teamChallenges: challenges);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Fetch team leaderboard
  Future<List<Team>> fetchTeamLeaderboard() async {
    try {
      final response = await _api.get('/teams/leaderboard');
      return (response.data as List)
          .map((t) => Team.fromJson(t))
          .toList();
    } catch (e) {
      throw Exception('Failed to load team leaderboard: $e');
    }
  }

  void clearCurrentTeam() {
    state = state.copyWith(currentTeam: null);
  }
}

/// Provider
final teamsProvider = StateNotifierProvider.autoDispose<TeamsNotifier, TeamsState>((ref) {
  return TeamsNotifier(ref.watch(apiServiceProvider));
});
