import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wellnex_app/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../services/api_service.dart';
import '../../../wallet/presentation/providers/wallet_provider.dart';
import '../providers/rewards_catalog_provider.dart';

/// Unified Rewards Hub Screen
/// Combines: Wallet/Ledger | Rewards Catalog | Achievements
class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ConfettiController _confettiController;
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _achievements = [];
  String _badgeFilter = 'All'; // All, Unlocked, Locked

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    // Fetch wallet and catalog data via providers
    Future.microtask(() {
      ref.read(walletProvider.notifier).fetchWalletData();
      ref.read(rewardsCatalogProvider.notifier).fetchCatalog();
      ref.read(rewardsCatalogProvider.notifier).fetchMyOffers();
    });

    // Fetch badges/achievements from API
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get('/rewards/achievements');
      final apiData = List<Map<String, dynamic>>.from(response.data ?? []);
      
      // Map API data to include icons
      final badges = apiData.map((badge) {
        return {
          ...badge,
          'icon': _getIconForBadge(badge['icon'] ?? badge['code'] ?? ''),
        };
      }).toList();
      
      setState(() {
        _achievements = badges;
        _isLoading = false;
      });
    } catch (e) {
      // Show empty state on error - no hardcoded badges
      setState(() {
        _achievements = [];
        _isLoading = false;
      });
    }
  }
  
  // Helper to map icon strings from API to Flutter Icons
  IconData _getIconForBadge(String iconName) {
    final iconMap = {
      'directions_walk': Icons.directions_walk,
      'flag': Icons.flag,
      'local_fire_department': Icons.local_fire_department,
      'calendar_today': Icons.calendar_today,
      'emoji_events': Icons.emoji_events,
      'wb_sunny': Icons.wb_sunny,
      'nightlight': Icons.nightlight,
      'people': Icons.people,
      'military_tech': Icons.military_tech,
      'stars': Icons.stars,
      'trending_up': Icons.trending_up,
      'stars_rounded': Icons.stars_rounded,
      'groups': Icons.groups,
      'emoji_flags': Icons.emoji_flags,
      'card_giftcard': Icons.card_giftcard,
    };
    return iconMap[iconName] ?? Icons.emoji_events;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.rewards),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryGreen,
          unselectedLabelColor: AppTheme.neutral500,
          indicatorColor: AppTheme.primaryGreen,
          tabs: [
            Tab(icon: const Icon(Icons.account_balance_wallet, size: 20), text: l10n.wallet),
            const Tab(icon: Icon(Icons.card_giftcard, size: 20), text: 'Catalog'),
            Tab(icon: const Icon(Icons.emoji_events, size: 20), text: l10n.badges),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildWalletTab(),
              _buildCatalogTab(),
              _buildAchievementsTab(),
            ],
          ),
          // Confetti for redemption success
          Align(
            alignment: Alignment.topCenter,
            child: RepaintBoundary(
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [AppTheme.primaryGreen, AppTheme.accentYellow, AppTheme.accentPurple],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== WALLET TAB ====================
  Widget _buildWalletTab() {
    final walletState = ref.watch(walletProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(walletProvider.notifier).fetchWalletData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Balance Card
            _buildBalanceCard(walletState),
            const SizedBox(height: 16),
            
            // Quick Stats
            _buildQuickStats(walletState),
            const SizedBox(height: 20),
            
            // Filter Chips
            _buildTransactionFilters(walletState),
            const SizedBox(height: 12),
            
            // Transaction List
            ...walletState.filteredTransactions.take(10).toList().asMap().entries.map((entry) {
              return _buildTransactionCard(entry.value, entry.key);
            }),
            
            if (walletState.filteredTransactions.isEmpty)
              _buildEmptyTransactions(),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(WalletState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Coin Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.stars_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          // Balance Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Step Coins', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 2),
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: state.balance),
                  duration: const Duration(milliseconds: 800),
                  builder: (context, value, _) => Text(
                    '$value',
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          // Lifetime Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.trending_up, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${state.lifetimePoints}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildQuickStats(WalletState state) {
    final earned = state.transactions.where((t) => t.isEarning).fold<int>(0, (sum, t) => sum + t.points);
    final spent = state.transactions.where((t) => t.isRedemption).fold<int>(0, (sum, t) => sum + t.points.abs());

    return Row(
      children: [
        Expanded(child: _buildStatCard('Earned', '+$earned', AppTheme.success, Icons.arrow_upward)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Spent', '-$spent', AppTheme.error, Icons.arrow_downward)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionFilters(WalletState state) {
    final filters = ['ALL', 'EARNED', 'REDEEMED'];
    return Row(
      children: filters.map((filter) {
        final isSelected = state.selectedFilter == filter;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: Text(filter == 'ALL' ? 'All' : filter == 'EARNED' ? 'Earned' : 'Redeemed'),
            selected: isSelected,
            onSelected: (_) => ref.read(walletProvider.notifier).setFilter(filter),
            selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
            checkmarkColor: AppTheme.primaryGreen,
            backgroundColor: Theme.of(context).cardColor,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTransactionCard(WalletTransaction tx, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: _getTxTypeColor(tx.type).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_getTxTypeIcon(tx.type), color: _getTxTypeColor(tx.type), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.description ?? tx.type, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(_formatDate(tx.createdAt), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Text(
            tx.isEarning ? '+${tx.points}' : '${tx.points}',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: tx.isEarning ? AppTheme.success : AppTheme.error),
          ),
        ],
      ),
    ).animate(delay: (index * 50).ms).fadeIn(duration: 200.ms).slideX(begin: 0.05, end: 0);
  }

  Widget _buildEmptyTransactions() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 60, color: AppTheme.neutral300),
          const SizedBox(height: 12),
          Text('No transactions yet', style: TextStyle(color: AppTheme.neutral500)),
        ],
      ),
    );
  }

  // ==================== CATALOG TAB ====================
  Widget _buildCatalogTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.card_giftcard, size: 64, color: AppTheme.neutral300),
          const SizedBox(height: 16),
          const Text(
            'Coming Soon!',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.neutral700),
          ),
          const SizedBox(height: 8),
          const Text(
            'The Rewards Catalog will be unlocked\nonce we are fully live!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.neutral500),
          ),
        ],
      ),
    );
  }

  // ==================== ACHIEVEMENTS TAB ====================
  Widget _buildAchievementsTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    // Filter logic
    final filtered = _achievements.where((a) {
      if (_badgeFilter == 'Unlocked') return a['unlocked'] == true;
      if (_badgeFilter == 'Locked') return a['unlocked'] == false;
      return true;
    }).toList();

    return Column(
      children: [
        // Badge Filters
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: ['All', 'Unlocked', 'Locked'].map((filter) {
              final isSelected = _badgeFilter == filter;
              return GestureDetector(
                onTap: () => setState(() => _badgeFilter = filter),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.accentPurple : AppTheme.neutral100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Text(filter, style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.neutral600,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  )),
                ),
              );
            }).toList(),
          ),
        ),

        // Badges Grid
        Expanded(
          child: filtered.isEmpty 
              ? Center(child: Text('No $_badgeFilter badges found', style: TextStyle(color: AppTheme.neutral500)))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final achievement = filtered[index];
                    return _buildBadgeItem(achievement, index);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBadgeItem(Map<String, dynamic> achievement, int index) {
    final unlocked = achievement['unlocked'] ?? false;
    final icon = achievement['icon'] ?? Icons.emoji_events;

    return GestureDetector(
      onTap: () => _showBadgeDetails(achievement),
      child: Column(
        children: [
          Container(
            width: 54, height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked ? AppTheme.accentPurple.withValues(alpha: 0.1) : AppTheme.neutral100,
              border: Border.all(
                color: unlocked ? AppTheme.accentPurple : AppTheme.neutral300, 
                width: unlocked ? 2 : 1
              ),
              boxShadow: unlocked ? [
                BoxShadow(color: AppTheme.accentPurple.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 3))
              ] : null,
            ),
            child: Icon(
              unlocked ? icon : Icons.lock, 
              color: unlocked ? AppTheme.accentPurple : AppTheme.neutral400, 
              size: 24
            ),
          ),
          const SizedBox(height: 8),
          Text(
            achievement['name'],
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 12, 
              color: unlocked ? AppTheme.neutral900 : AppTheme.neutral500
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ).animate(delay: (index * 50).ms).fadeIn().scale(duration: 300.ms);
  }

  void _showBadgeDetails(Map<String, dynamic> badge) {
    final unlocked = badge['unlocked'];
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unlocked ? AppTheme.accentPurple.withValues(alpha: 0.1) : AppTheme.neutral100,
                  border: Border.all(color: unlocked ? AppTheme.accentPurple : AppTheme.neutral300, width: 3),
                ),
                child: Icon(
                  unlocked ? (badge['icon'] ?? Icons.emoji_events) : Icons.lock, 
                  color: unlocked ? AppTheme.accentPurple : AppTheme.neutral400, 
                  size: 48
                ),
              ),
              const SizedBox(height: 16),
              Text(
                badge['name'],
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: unlocked ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.neutral200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  unlocked ? 'Unlocked' : 'Locked',
                  style: TextStyle(
                    color: unlocked ? AppTheme.success : AppTheme.neutral600,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                badge['description'],
                style: TextStyle(color: AppTheme.neutral600, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              
              if (!unlocked) ...[
                const SizedBox(height: 16),
                const Text('Progress:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.left),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (badge['progress'] ?? 0) / 100,
                    backgroundColor: AppTheme.neutral200,
                    valueColor: const AlwaysStoppedAnimation(AppTheme.accentPurple),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 4),
                Text('${badge['progress']}% completed', style: TextStyle(color: AppTheme.neutral500, fontSize: 11)),
              ],
              
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                  if (unlocked) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final msg = '🏆 I just earned the "${badge['name']}" badge on Wellnex! Can you beat my score?\n\nJoin me: https://joinwellnex.com';
                          Share.share(msg);
                        },
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text('Share'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentPurple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== HELPERS ====================
  IconData _getTxTypeIcon(String type) {
    switch (type) {
      case 'STEPS': return Icons.directions_walk;
      case 'STREAK_BONUS': return Icons.local_fire_department;
      case 'MILESTONE': return Icons.emoji_events;
      case 'AD_REWARD': return Icons.play_circle_filled;
      case 'REFERRAL': return Icons.people;
      case 'REDEMPTION': return Icons.card_giftcard;
      default: return Icons.stars_rounded;
    }
  }

  Color _getTxTypeColor(String type) {
    switch (type) {
      case 'STEPS': return AppTheme.primaryGreen;
      case 'STREAK_BONUS': return AppTheme.accentOrange;
      case 'MILESTONE': return AppTheme.accentPurple;
      case 'AD_REWARD': return AppTheme.secondaryBlue;
      case 'REFERRAL': return AppTheme.accentPink;
      case 'REDEMPTION': return AppTheme.error;
      default: return AppTheme.neutral500;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return diff.inHours == 0 ? '${diff.inMinutes}m ago' : '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
