import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/referral_provider.dart';
import '../../../../services/storage_service.dart';

/// Screen 18: Referral Leaderboard
class ReferralLeaderboardScreen extends ConsumerStatefulWidget {
  const ReferralLeaderboardScreen({super.key});

  @override
  ConsumerState<ReferralLeaderboardScreen> createState() => _ReferralLeaderboardScreenState();
}

class _ReferralLeaderboardScreenState extends ConsumerState<ReferralLeaderboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
       ref.read(referralProvider.notifier).fetchReferralData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(referralProvider);
    final currentUser = StorageService.getUser();
    final currentUserId = currentUser?['id'] ?? '';

    ref.listen(referralProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: Colors.red),
        );
        ref.read(referralProvider.notifier).clearError();
      }
    });

    // Use leaderboard from provider
    final topReferrers = state.leaderboard;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Top Referrers'),
        centerTitle: true,
      ),
      body: state.isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // User Stats Header (Current User)
              _buildUserStats(context, state.stats),
              
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: topReferrers.isEmpty 
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: topReferrers.length,
                        separatorBuilder: (c, i) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final referrer = topReferrers[index];
                          final isMe = referrer.id == currentUserId;
                          return _buildReferralRow(context, referrer, index + 1, isMe);
                        },
                      ),
                ),
              ),
            ],
          ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  // Share invite logic
                 _shareInvite(state.stats.referralCode);
                }, 
                icon: const Icon(Icons.share),
                label: const Text('Invite Friends & Climb Rank'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 48), // Compact size
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
     return Center(
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           Icon(Icons.emoji_events_outlined, size: 64, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.3)),
           const SizedBox(height: 16),
           Text(
             'No referrers yet',
             style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
           ),
           const SizedBox(height: 8),
           Text(
             'Be the first to join the leaderboard!',
             style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).textTheme.bodySmall?.color),
           ),
         ],
       ),
     );
  }

  Widget _buildUserStats(BuildContext context, ReferralStats stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
           _buildStatBox(context, 'Rank', stats.rank > 0 ? '#${stats.rank}' : '-'),
           Container(width: 1, height: 40, color: Theme.of(context).dividerColor),
           _buildStatBox(context, 'Invites', '${stats.invitesAccepted}'),
           Container(width: 1, height: 40, color: Theme.of(context).dividerColor),
           _buildStatBox(context, 'Earned', '${stats.coinsEarned}'),
        ],
      ),
    ).animate().fadeIn().slideY();
  }
  
  Widget _buildStatBox(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 13)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Theme.of(context).textTheme.bodyLarge?.color)),
      ],
    );
  }

  Widget _buildReferralRow(BuildContext context, TopReferrer user, int rank, bool isMe) {
    final isTop3 = rank <= 3;
    final earnedCoins = user.referrals * 50;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        tileColor: isMe ? AppTheme.primaryGreen.withValues(alpha: 0.05) : null,
        shape: isMe ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)) : null,
        leading: SizedBox(
        width: 40,
        child: Center(
          child: isTop3 
            ? Icon(Icons.emoji_events, color: _getRankColor(rank)) 
            : Text('#$rank', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.neutral500)),
        ),
      ),
      title: Row(
        children: [
          CircleAvatar(
             radius: 16,
             backgroundColor: Theme.of(context).dividerColor, 
             child: Text(user.name.isNotEmpty ? user.name[0] : '?', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color)),
          ),
          const SizedBox(width: 12),
          Text(user.name, style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.w500)),
          if (isMe) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(4)),
              child: const Text('You', style: TextStyle(fontSize: 10)),
            ),
          ]
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars_rounded, size: 14, color: AppTheme.accentYellow),
              const SizedBox(width: 4),
              Text('$earnedCoins', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          Text('${user.referrals} active', style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color)),
        ],
      ),
      ),
    ).animate().fadeIn(delay: (30 * rank).ms);
  }

  Color _getRankColor(int rank) {
    switch(rank) {
      case 1: return const Color(0xFFFFD700);
      case 2: return const Color(0xFFC0C0C0);
      case 3: return const Color(0xFFCD7F32);
      default: return AppTheme.neutral400;
    }
  }

  void _shareInvite(String code) {
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite code not found. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    
    Share.share(
      '🚀 Join me on Wellnex and get rewarded! Use my invite code: $code\n\nDownload: https://joinwellnex.com/invite?code=$code', 
      subject: 'Join Wellnex Challenge!'
    );
  }
}
