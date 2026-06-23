import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:wellnex_app/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/referral_provider.dart';
import '../widgets/visual_share_card.dart';

/// Invite & Referral Dashboard Screen (Screen 8)
class ReferralScreen extends ConsumerStatefulWidget {
  final ScreenshotController? screenshotController;
  
  const ReferralScreen({
    super.key,
    this.screenshotController,
  });

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  late final ScreenshotController _screenshotController;
  
  @override
  void initState() {
    super.initState();
    _screenshotController = widget.screenshotController ?? ScreenshotController();
    Future.microtask(() {
      ref.read(referralProvider.notifier).fetchReferralData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(referralProvider);

    ref.listen(referralProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: Colors.red),
        );
        ref.read(referralProvider.notifier).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.referral),
        centerTitle: true,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(referralProvider.notifier).fetchReferralData(),
              child: Stack(
                 children: [
                    SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildReferralCodeCard(state.stats),
                          const SizedBox(height: 20),
                          _buildStatsSection(state.stats),
                          const SizedBox(height: 20),
                          _buildMilestoneTracker(state.stats),
                          const SizedBox(height: 20),
                          _buildRewardTiers(state.stats),
                          const SizedBox(height: 20),
                          _buildLeaderboard(state.leaderboard),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                    // Hidden widget for screenshot generation
                    Transform.translate(
                      offset: const Offset(9999, 9999),
                      child: Screenshot(
                        controller: _screenshotController,
                        child: VisualShareCard(referralCode: state.stats.referralCode),
                      ),
                    ),
                 ],
              ),
            ),
    );
  }

  Widget _buildReferralCodeCard(ReferralStats stats) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.card_giftcard, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Your Referral Code',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _copyCode(stats.referralCode),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    stats.referralCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.copy, color: Colors.white70, size: 24),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Earn 50 coins for each friend who joins!',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _shareInvite(stats.referralCode),
            icon: const Icon(Icons.share),
            label: const Text('Invite Friends'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryGreen,
              minimumSize: const Size(120, 48), // Override global full-width
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildStatsSection(ReferralStats stats) {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Sent', stats.invitesSent.toString(), Icons.send, AppTheme.secondaryBlue)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Accepted', stats.invitesAccepted.toString(), Icons.check_circle, AppTheme.success)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Earned', '${stats.coinsEarned}', Icons.stars_rounded, AppTheme.accentYellow)),
      ],
    ).animate().fadeIn(delay: 100.ms, duration: 300.ms);
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: color)),
          Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMilestoneTracker(ReferralStats stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag, color: AppTheme.accentPurple, size: 24),
              const SizedBox(width: 8),
              const Text('Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              Text(
                '${stats.invitesAccepted} / ${stats.nextMilestoneTarget}',
                style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: stats.progressToNextMilestone.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 800),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 12,
                backgroundColor: AppTheme.neutral200,
                valueColor: const AlwaysStoppedAnimation(AppTheme.accentPurple),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${stats.nextMilestoneTarget - stats.invitesAccepted} more referrals to unlock next reward!',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 300.ms);
  }

  Widget _buildRewardTiers(ReferralStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Reward Tiers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        ...stats.milestones.asMap().entries.map((entry) {
          final milestone = entry.value;
          return _buildTierItem(milestone, entry.key);
        }),
      ],
    ).animate().fadeIn(delay: 300.ms, duration: 300.ms);
  }

  Widget _buildTierItem(ReferralMilestone milestone, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: milestone.isUnlocked 
            ? AppTheme.success.withValues(alpha: 0.1) 
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: milestone.isUnlocked ? AppTheme.success : Theme.of(context).dividerColor,
          width: milestone.isUnlocked ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: milestone.isUnlocked ? AppTheme.success : Theme.of(context).dividerColor.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: milestone.isUnlocked
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : Text('${milestone.target}', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${milestone.target} Referrals',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: milestone.isUnlocked ? AppTheme.success : null,
                  ),
                ),
                Text(
                  milestone.isUnlocked ? 'Completed!' : 'Invite ${milestone.target} friends',
                  style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.accentYellow.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, color: AppTheme.accentYellow, size: 16),
                const SizedBox(width: 4),
                Text('+${milestone.reward}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboard(List<TopReferrer> leaderboard) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.leaderboard, color: AppTheme.accentOrange, size: 24),
            const SizedBox(width: 8),
            const Text('Top Referrers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            TextButton(
               onPressed: () => context.push('/referral-leaderboard'),
               child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        leaderboard.isEmpty
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  children: [
                    Icon(Icons.emoji_events_outlined, size: 48, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text(
                      'No top referrers yet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Be the first to invite friends!',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).textTheme.bodySmall?.color),
                    ),
                  ],
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  children: leaderboard.take(5).toList().asMap().entries.map((entry) {
                    final referrer = entry.value;
                    return _buildLeaderboardItem(referrer, entry.key == (leaderboard.length < 5 ? leaderboard.length : 5) - 1);
                  }).toList(),
                ),
              ),
      ],
    ).animate().fadeIn(delay: 400.ms, duration: 300.ms);
  }

  Widget _buildLeaderboardItem(TopReferrer referrer, bool isLast) {
    Color? rankColor;
    IconData? rankIcon;
    if (referrer.rank == 1) { rankColor = const Color(0xFFFFD700); rankIcon = Icons.emoji_events; }
    else if (referrer.rank == 2) { rankColor = const Color(0xFFC0C0C0); rankIcon = Icons.emoji_events; }
    else if (referrer.rank == 3) { rankColor = const Color(0xFFCD7F32); rankIcon = Icons.emoji_events; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          if (rankIcon != null)
            Icon(rankIcon, color: rankColor, size: 24)
          else
            Container(
              width: 24,
              alignment: Alignment.center,
              child: Text('#${referrer.rank}', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontWeight: FontWeight.bold)),
            ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 18,
            backgroundColor: Theme.of(context).dividerColor,
            child: Text(referrer.name.isNotEmpty ? referrer.name[0] : '?', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium?.color)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(referrer.name, style: const TextStyle(fontWeight: FontWeight.w500))),
          Text('${referrer.referrals} invites', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 13)),
        ],
      ),
    );
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text('Code "$code" copied!'),
          ],
        ),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareInvite(String code) async {
    try {
      // 1. Show loading feedback ? 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating invite card...')),
      );

      // 2. Capture the hidden VisualShareCard
      final Uint8List? imageBytes = await _screenshotController.capture();
      
      if (imageBytes != null) {
        // 3. Save to temp file
        final directory = await getTemporaryDirectory();
        final imagePath = await File('${directory.path}/wellnex_invite.png').create();
        await imagePath.writeAsBytes(imageBytes);

        // 4. Create proper sharing message
        final message = '''
🚀 Join me on Wellnex and get rewarded!
        
My Invite Code: $code
        
Download: https://joinwellnex.com/invite?code=$code
''';
        
        // 5. Share image + text
        await Share.shareXFiles(
          [XFile(imagePath.path)],
          text: message,
          subject: 'Join Wellnex Challenge!',
        );
      } else {
         // Fallback to text only if capture fail
         _shareTextOnly(code);
      }
    } catch (e) {
      debugPrint('Error sharing invite: $e');
      _shareTextOnly(code);
    }
  }

  void _shareTextOnly(String code) {
    Share.share(
      'Join me on Wellnex! Use code: $code\nhttps://joinwellnex.com/invite?code=$code', 
      subject: 'Join Wellnex!'
    );
  }
}
