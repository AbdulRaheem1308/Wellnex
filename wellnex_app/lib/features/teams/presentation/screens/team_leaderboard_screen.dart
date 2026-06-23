import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/team_model.dart';
import '../providers/teams_provider.dart';

/// Team Leaderboard Screen - Ranks all teams by weekly steps
class TeamLeaderboardScreen extends ConsumerStatefulWidget {
  const TeamLeaderboardScreen({super.key});

  @override
  ConsumerState<TeamLeaderboardScreen> createState() => _TeamLeaderboardScreenState();
}

class _TeamLeaderboardScreenState extends ConsumerState<TeamLeaderboardScreen> {
  List<Team> _leaderboard = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await ref.read(teamsProvider.notifier).fetchTeamLeaderboard();
      if (mounted) {
        setState(() {
          _leaderboard = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Leaderboard'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _leaderboard.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadLeaderboard,
                  child: CustomScrollView(
                    slivers: [
                      // Top 3 podium
                      SliverToBoxAdapter(child: _buildPodium()),

                      // Rest of leaderboard
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final team = _leaderboard[index + 3];
                            return _buildLeaderboardTile(team, index + 4)
                                .animate(delay: (index * 50).ms)
                                .fadeIn()
                                .slideX(begin: 0.1, end: 0);
                          },
                          childCount: (_leaderboard.length - 3).clamp(0, 100),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events_outlined, size: 80, color: AppTheme.neutral300),
          const SizedBox(height: 16),
          Text(
            'Leaderboard Empty',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.neutral600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Get your team stepping to appear here!',
            style: TextStyle(color: AppTheme.neutral500),
          ),
        ],
      ),
    );
  }

  Widget _buildPodium() {
    if (_leaderboard.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place
          if (_leaderboard.length > 1) _buildPodiumItem(_leaderboard[1], 2, 100),
          if (_leaderboard.length > 1) const SizedBox(width: 12),
          
          // 1st place
          if (_leaderboard.isNotEmpty) _buildPodiumItem(_leaderboard[0], 1, 130),
          
          // 3rd place
          if (_leaderboard.length > 2) ...[
            const SizedBox(width: 12),
            _buildPodiumItem(_leaderboard[2], 3, 80),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildPodiumItem(Team team, int rank, double height) {
    final colors = [
      AppTheme.accentYellow, // Gold
      AppTheme.neutral400,   // Silver
      const Color(0xFFCD7F32), // Bronze
    ];
    final color = colors[rank - 1];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown for 1st
        if (rank == 1)
          const Icon(Icons.military_tech, color: AppTheme.accentYellow, size: 32)
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 2000.ms),

        // Team avatar
        Container(
          width: rank == 1 ? 70 : 56,
          height: rank == 1 ? 70 : 56,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
          ),
          child: Center(
            child: Text(
              team.name.isNotEmpty ? team.name[0].toUpperCase() : 'T',
              style: TextStyle(
                color: Colors.white,
                fontSize: rank == 1 ? 28 : 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Team name
        SizedBox(
          width: 80,
          child: Text(
            team.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),

        // Steps
        Text(
          _formatNumber(team.weeklySteps),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),

        // Podium base
        Container(
          width: 80,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color, color.withValues(alpha: 0.7)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardTile(Team team, int rank) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
          ),
        ],
      ),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.neutral500,
                ),
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  team.name.isNotEmpty ? team.name[0].toUpperCase() : 'T',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          team.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${team.memberCount} members',
          style: TextStyle(color: AppTheme.neutral500, fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatNumber(team.weeklySteps),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryGreen,
                fontSize: 16,
              ),
            ),
            Text(
              'steps',
              style: TextStyle(
                color: AppTheme.neutral500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
