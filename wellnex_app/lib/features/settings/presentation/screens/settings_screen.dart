import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:wellnex_app/l10n/app_localizations.dart';


import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/settings_provider.dart';

/// Settings & Preferences Screen (Screen 7)
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _versionTapCount = 0;
  static const int _tapThreshold = 7;
  DateTime? _firstTapTime;

  void _onVersionTapped() {
    final now = DateTime.now();
    if (_firstTapTime == null || now.difference(_firstTapTime!) > const Duration(seconds: 5)) {
      _firstTapTime = now;
      _versionTapCount = 1;
    } else {
      _versionTapCount++;
    }

    final remaining = _tapThreshold - _versionTapCount;
    if (remaining > 0 && remaining <= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$remaining more taps to unlock Developer Mode'),
          duration: const Duration(milliseconds: 800),
        ),
      );
    }

    if (_versionTapCount >= _tapThreshold) {
      _versionTapCount = 0;
      context.push(AppRoutes.sensorDiagnostics);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);

    ref.listen<AppSettings>(settingsProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppTheme.error,
          ),
        );
        ref.read(settingsProvider.notifier).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance Section
          _buildSection(
            context,
            title: 'Appearance',
            icon: Icons.palette_outlined,
            children: [
              _buildToggleTile(
                context,
                title: 'Dark Mode',
                subtitle: 'Easier on the eyes',
                icon: Icons.dark_mode_outlined,
                value: settings.themeMode == 'dark',
                onChanged: (v) => ref.read(settingsProvider.notifier).setThemeMode(v ? 'dark' : 'light'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Notifications Section
          _buildSection(
            context,
            title: 'Notifications',
            icon: Icons.notifications_outlined,
            children: [
              _buildToggleTile(
                context,
                title: 'Push Notifications',
                subtitle: 'Receive updates and alerts',
                icon: Icons.notifications_active,
                value: settings.pushNotificationsEnabled,
                onChanged: (v) => ref.read(settingsProvider.notifier).togglePushNotifications(v),
              ),
              _buildToggleTile(
                context,
                title: 'Daily Reminders',
                subtitle: 'Get reminded to walk daily',
                icon: Icons.alarm,
                value: settings.dailyRemindersEnabled,
                onChanged: (v) => ref.read(settingsProvider.notifier).toggleDailyReminders(v),
              ),
              _buildToggleTile(
                context,
                title: 'Sound Effects',
                subtitle: 'Play sounds for achievements',
                icon: Icons.volume_up,
                value: settings.soundEnabled,
                onChanged: (v) => ref.read(settingsProvider.notifier).toggleSound(v),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Data & Privacy Section
          _buildSection(
            context,
            title: 'Data & Privacy',
            icon: Icons.shield_outlined,
            children: [
              _buildToggleTile(
                context,
                title: l10n.syncOverCellular,
                subtitle: l10n.syncOverCellularSubtitle,
                icon: Icons.signal_cellular_alt,
                value: settings.dataSyncOverCellular,
                onChanged: (v) => ref.read(settingsProvider.notifier).toggleDataSyncOverCellular(v),
              ),
              _buildToggleTile(
                context,
                title: l10n.backgroundSync,
                subtitle: l10n.backgroundSyncSubtitle,
                icon: Icons.history_toggle_off,
                value: settings.backgroundSyncEnabled,
                onChanged: (v) => ref.read(settingsProvider.notifier).toggleBackgroundSync(v),
              ),
              _buildLinkTile(
                context,
                title: l10n.connectedDevices,
                icon: Icons.watch,
                onTap: () => context.push('/device-sync'),
              ),
              _buildLanguageSelector(context, ref, settings),
              _buildDropdownTile(
                context,
                title: 'Distance Unit',
                icon: Icons.straighten,
                value: settings.distanceUnit == 'km' ? 'Kilometers' : 'Miles',
                items: const ['Kilometers', 'Miles'],
                onChanged: (val) {
                  if (val != null) {
                    ref.read(settingsProvider.notifier).setDistanceUnit(val == 'Kilometers' ? 'km' : 'mi');
                  }
                },
              ),
              _buildDropdownTile(
                context,
                title: 'Sync Frequency',
                icon: Icons.sync,
                value: settings.syncFrequency,
                items: const ['Auto (15m)', 'Manual Only', 'Every Hour'],
                onChanged: (val) {
                  if (val != null) {
                    ref.read(settingsProvider.notifier).setSyncFrequency(val);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Legal & GDPR Section
          _buildSection(
            context,
            title: 'Legal & Privacy (GDPR)',
            icon: Icons.gavel_outlined,
            children: [
              _buildLinkTile(
                context,
                title: 'Privacy Policy',
                icon: Icons.privacy_tip_outlined,
                onTap: () => context.push('/privacy-policy'),
              ),
              _buildLinkTile(
                context,
                title: 'Terms of Service',
                icon: Icons.description_outlined,
                onTap: () => context.push('/terms'),
              ),
              const Divider(height: 1),
              _buildLinkTile(
                context,
                title: 'Request My Data',
                icon: Icons.download_outlined,
                onTap: () => _handleDataExport(context),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_forever_outlined, size: 20, color: AppTheme.error),
                ),
                title: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: AppTheme.error)),
                onTap: () => _handleAccountDeletion(context),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Reset Button
          Center(
            child: Semantics(
              label: 'Reset all settings to defaults',
              button: true,
              child: TextButton.icon(
                onPressed: () => _showResetDialog(context, ref),
                icon: const Icon(Icons.restore, color: AppTheme.error),
                label: const Text('Reset to Defaults', style: TextStyle(color: AppTheme.error)),
                style: TextButton.styleFrom(
                  minimumSize: const Size(160, 48),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),

          // App Version — hidden developer access: tap 7 times
          Center(
            child: GestureDetector(
              onTap: _onVersionTapped,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 80), // Extra padding to clear bottom nav
                child: Text(
                  'Wellnex v1.0.0',
                  style: TextStyle(color: AppTheme.neutral400, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.defaultRadius),
        side: BorderSide(color: AppTheme.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
  }



  Widget _buildToggleTile(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Semantics(
      label: '$title. $subtitle. Currently ${value ? 'enabled' : 'disabled'}.',
      toggled: value,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ExcludeSemantics(
            child: Icon(icon, size: 20, color: Theme.of(context).iconTheme.color ?? AppTheme.neutral600),
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(color: AppTheme.neutral500, fontSize: 12)),
        trailing: ExcludeSemantics(
          child: Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryGreen,
          ),
        ),
        onTap: () => onChanged(!value),
        minVerticalPadding: 12,
      ),
    );
  }

  Widget _buildLanguageSelector(BuildContext context, WidgetRef ref, AppSettings settings) {
    final languages = {
      'en': 'English',
      'hi': 'हिन्दी',
      'es': 'Español',
      'fr': 'Français',
      'de': 'Deutsch',
    };

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.language, size: 20, color: Theme.of(context).iconTheme.color ?? AppTheme.neutral600),
      ),
      title: const Text('Language', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: Text(languages[settings.language] ?? 'English', style: TextStyle(color: AppTheme.neutral500, fontSize: 12)),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.arrow_drop_down),
        onSelected: (lang) => ref.read(settingsProvider.notifier).setLanguage(lang),
        itemBuilder: (context) => languages.entries.map((e) {
          return PopupMenuItem(
            value: e.key,
            child: Row(
              children: [
                if (settings.language == e.key)
                  const Icon(Icons.check, size: 18, color: AppTheme.primaryGreen),
                if (settings.language != e.key)
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Text(e.value),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLinkTile(BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: title,
      button: true,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ExcludeSemantics(
            child: Icon(icon, size: 20, color: Theme.of(context).iconTheme.color ?? AppTheme.neutral600),
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        trailing: ExcludeSemantics(
          child: const Icon(Icons.open_in_new, size: 18, color: AppTheme.neutral400),
        ),
        onTap: onTap,
        minVerticalPadding: 12,
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Settings?'),
        content: const Text('This will restore all settings to their default values.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).resetToDefaults();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings reset to defaults')),
              );
            },
            child: const Text('Reset', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  void _handleDataExport(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data export requested. Check your email shortly.')),
    );
    // TODO: Call API /users/me/export
  }

  void _handleAccountDeletion(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?', style: TextStyle(color: AppTheme.error)),
        content: const Text('This action is permanent and cannot be undone. All your steps, rewards, and data will be permanently erased. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Deleting account...')),
              );
              
              try {
                await ref.read(authProvider.notifier).deleteAccount();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account deleted successfully.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete account: $e'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete Forever', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }


  Widget _buildDropdownTile(BuildContext context, {
    required String title,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: Theme.of(context).iconTheme.color ?? AppTheme.neutral600),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down),
        onChanged: onChanged,
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(item, style: const TextStyle(fontSize: 14)),
          );
        }).toList(),
      ),
    );
  }
}
