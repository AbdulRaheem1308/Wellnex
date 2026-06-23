import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/team_model.dart';
import '../providers/teams_provider.dart';
import '../widgets/team_card.dart';

/// Teams Screen - List of user's teams and public teams to join
class TeamsScreen extends ConsumerStatefulWidget {
  const TeamsScreen({super.key});

  @override
  ConsumerState<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends ConsumerState<TeamsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    Future.microtask(() {
      ref.read(teamsProvider.notifier).fetchMyTeams();
      ref.read(teamsProvider.notifier).fetchPublicTeams();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(teamsProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppTheme.error,
          ),
        );
        ref.read(teamsProvider.notifier).clearError();
      }
    });

    final state = ref.watch(teamsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teams'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryGreen,
          labelColor: AppTheme.primaryGreen,
          unselectedLabelColor: AppTheme.neutral500,
          tabs: const [
            Tab(text: 'My Teams'),
            Tab(text: 'Discover'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard),
            onPressed: () => context.push('/teams/leaderboard'),
            tooltip: 'Team Leaderboard',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // My Teams Tab
          _buildMyTeamsTab(state),
          
          // Discover Tab
          _buildDiscoverTab(state),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateTeamDialog(),
        backgroundColor: AppTheme.primaryGreen,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Create Team', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildMyTeamsTab(TeamsState state) {
    if (state.isLoading && state.myTeams.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.myTeams.isEmpty) {
      return _buildEmptyState(
        icon: Icons.groups_outlined,
        title: 'No Teams Yet',
        subtitle: 'Create a team or join one to compete together!',
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(teamsProvider.notifier).fetchMyTeams(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.myTeams.length,
        itemBuilder: (context, index) {
          final team = state.myTeams[index];
          return TeamCard(
            team: team,
            onTap: () => context.push('/teams/${team.id}'),
          ).animate(delay: (index * 100).ms)
              .fadeIn(duration: 300.ms)
              .slideX(begin: 0.1, end: 0);
        },
      ),
    );
  }

  Widget _buildDiscoverTab(TeamsState state) {
    if (state.isLoading && state.publicTeams.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.publicTeams.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search_off,
        title: 'No Public Teams',
        subtitle: 'Be the first to create a public team!',
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(teamsProvider.notifier).fetchPublicTeams(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.publicTeams.length,
        itemBuilder: (context, index) {
          final team = state.publicTeams[index];
          return TeamCard(
            team: team,
            showJoinButton: true,
            onJoin: () => _joinTeam(team),
            onTap: () => context.push('/teams/${team.id}'),
          ).animate(delay: (index * 100).ms)
              .fadeIn(duration: 300.ms)
              .slideX(begin: 0.1, end: 0);
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: AppTheme.neutral300),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.neutral600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: AppTheme.neutral500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _joinTeam(Team team) async {
    if (team.isFull) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This team is full!')),
      );
      return;
    }

    final success = await ref.read(teamsProvider.notifier).joinTeam(team.id);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Joined ${team.name}!'),
          backgroundColor: AppTheme.success,
        ),
      );
      _tabController.animateTo(0); // Switch to My Teams tab
    }
  }

  void _showCreateTeamDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    int maxMembers = 10;
    bool isPublic = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Create Team',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Name field
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Team Name',
                    hintText: 'Enter team name',
                    prefixIcon: const Icon(Icons.groups),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.primaryGreen, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Description field
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: 'What is your team about?',
                    prefixIcon: const Icon(Icons.description),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.primaryGreen, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Max members slider
                Text('Max Members: $maxMembers'),
                Slider(
                  value: maxMembers.toDouble(),
                  min: 2,
                  max: 10,
                  divisions: 8,
                  label: maxMembers.toString(),
                  activeColor: AppTheme.primaryGreen,
                  onChanged: (val) => setModalState(() => maxMembers = val.toInt()),
                ),
                const SizedBox(height: 8),

                // Public toggle
                SwitchListTile(
                  title: const Text('Public Team'),
                  subtitle: const Text('Anyone can find and join'),
                  value: isPublic,
                  activeThumbColor: AppTheme.primaryGreen,
                  onChanged: (val) => setModalState(() => isPublic = val),
                ),
                const SizedBox(height: 24),

                // Create button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a team name')),
                        );
                        return;
                      }

                      final team = await ref.read(teamsProvider.notifier).createTeam(
                            name: nameController.text.trim(),
                            description: descController.text.trim(),
                            maxMembers: maxMembers,
                            isPublic: isPublic,
                          );

                      if (team != null && mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Team "${team.name}" created!'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Create Team',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}
