import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:wellnex_app/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/health_service.dart';
import '../providers/device_provider.dart';

/// Connected Sources screen — replaces the old Device Management.
///
/// Steps are now read exclusively from the OS health platform
/// (Google Health Connect on Android, Apple HealthKit on iOS).
/// Users do not need to connect devices to Wellnex directly — they
/// connect their wearable to the OS health app and it flows in automatically.
class DeviceSyncScreen extends ConsumerStatefulWidget {
  const DeviceSyncScreen({super.key});

  @override
  ConsumerState<DeviceSyncScreen> createState() => _DeviceSyncScreenState();
}

class _DeviceSyncScreenState extends ConsumerState<DeviceSyncScreen> {
  bool _healthAuthorized = false;
  int _todaySteps = 0;
  bool _loading = true;
  String? _expandedGuide; // which wearable guide is open

  @override
  void initState() {
    super.initState();
    _checkHealthStatus();
  }

  Future<void> _checkHealthStatus() async {
    setState(() => _loading = true);
    try {
      final health = HealthService();
      
      if (Theme.of(context).platform == TargetPlatform.android) {
        final isAvailable = await health.isHealthConnectAvailable();
        if (!isAvailable) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Health Connect is not available on this device.')),
            );
            setState(() {
              _healthAuthorized = false;
              _todaySteps = 0;
              _loading = false;
            });
          }
          return;
        }
      }

      final authorized = await health.requestAuthorization();
      final steps = authorized ? await health.getTodaySteps() : 0;
      if (mounted) {
        setState(() {
          _healthAuthorized = authorized;
          _todaySteps = steps;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openHealthApp() async {
    try {
      if (Platform.isAndroid) {
        // Open Health Connect app
        const platform = MethodChannel('wellnex/health');
        try {
          await platform.invokeMethod('openHealthConnect');
        } catch (_) {
          // Fallback: open Play Store Health Connect page
          const url = 'market://details?id=com.google.android.apps.healthdata';
          await SystemChannels.platform.invokeMethod(
            'url_launcher/launch',
            {'url': url},
          );
        }
      } else if (Platform.isIOS) {
        // Open Apple Health via URL scheme
        try {
          await SystemChannels.platform.invokeMethod(
            'url_launcher/launch',
            {'url': 'x-apple-health://'},
          );
        } catch (_) {}
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isAndroid = !Platform.isIOS;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connected Sources'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh status',
            onPressed: _checkHealthStatus,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Status Card ─────────────────────────────────────
                _StatusCard(
                  authorized: _healthAuthorized,
                  todaySteps: _todaySteps,
                  isAndroid: isAndroid,
                  onGrantPermission: _checkHealthStatus,
                  onOpenHealthApp: _openHealthApp,
                ).animate().fadeIn(duration: 300.ms),

                const SizedBox(height: 20),

                // ── How it works ────────────────────────────────────
                Text(
                  'How step tracking works',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _HowItWorksCard(isAndroid: isAndroid)
                    .animate()
                    .fadeIn(duration: 300.ms, delay: 100.ms),

                const SizedBox(height: 20),

                // ── Wearable connection guides ───────────────────────
                Text(
                  'Connect your wearable',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your wearable steps flow into Wellnex automatically once connected to ${isAndroid ? "Health Connect" : "Apple Health"}.',
                  style: TextStyle(fontSize: 13, color: AppTheme.neutral500),
                ),
                const SizedBox(height: 12),

                ..._wearableGuides(isAndroid).asMap().entries.map((entry) {
                  final guide = entry.value;
                  final isExpanded = _expandedGuide == guide.brand;
                  return _WearableGuideCard(
                    guide: guide,
                    isExpanded: isExpanded,
                    onToggle: () {
                      setState(() {
                        _expandedGuide = isExpanded ? null : guide.brand;
                      });
                    },
                  )
                      .animate()
                      .fadeIn(duration: 300.ms, delay: Duration(milliseconds: 150 + entry.key * 50));
                }),

                const SizedBox(height: 20),

                // ── Tip card ────────────────────────────────────────
                _TipCard(isAndroid: isAndroid)
                    .animate()
                    .fadeIn(duration: 300.ms, delay: 400.ms),

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  List<_WearableGuide> _wearableGuides(bool isAndroid) {
    if (isAndroid) {
      return [
        _WearableGuide(
          brand: 'Fitbit',
          icon: Icons.watch_rounded,
          iconColor: const Color(0xFF00B0B9),
          steps: [
            'Install the Fitbit app from the Play Store.',
            'Log in to your Fitbit account.',
            'In the Fitbit app, go to Today tab → Profile → App Gallery.',
            'Open Fitbit app settings → tap Health Connect.',
            'Enable "Sync with Health Connect" and grant all permissions.',
            'Fitbit will now automatically sync your steps to Health Connect, and Wellnex will read from there.',
          ],
        ),
        _WearableGuide(
          brand: 'Garmin',
          icon: Icons.gps_fixed_rounded,
          iconColor: const Color(0xFF006EBB),
          steps: [
            'Install the Garmin Connect app from the Play Store.',
            'Pair your Garmin device to the app via Bluetooth.',
            'In Garmin Connect, go to More → Settings → Health Snapshot.',
            'Go to More → Connected Apps → Health Connect.',
            'Enable the connection and grant step, distance, and calorie permissions.',
            'Garmin steps will now appear in Health Connect automatically.',
          ],
        ),
        _WearableGuide(
          brand: 'Samsung (Galaxy Watch)',
          icon: Icons.watch_outlined,
          iconColor: const Color(0xFF1428A0),
          steps: [
            'Open the Samsung Health app on your phone.',
            'Go to Profile → Connected Services.',
            'Tap Health Connect → Connect.',
            'Grant all the health permissions shown.',
            'Samsung Health will now sync your Galaxy Watch steps into Health Connect.',
          ],
        ),
        _WearableGuide(
          brand: 'Google (Pixel Watch / WearOS)',
          icon: Icons.android_rounded,
          iconColor: const Color(0xFF4285F4),
          steps: [
            'Your Pixel Watch or WearOS watch automatically syncs with Health Connect via the Wear OS app.',
            'Open the Wear OS app on your phone.',
            'Go to Settings → Health Connect → Verify it is connected.',
            'No extra steps needed — it works automatically once the watch is paired.',
          ],
        ),
        _WearableGuide(
          brand: 'Apple Watch (via iPhone)',
          icon: Icons.apple_rounded,
          iconColor: Colors.black87,
          steps: [
            'Apple Watch step data is stored in Apple Health, not Android Health Connect.',
            'To use Apple Watch steps on Android is not directly supported.',
            'Consider exporting your Apple Health data and importing it manually, or use a third-party sync app like "Health Sync" from the Play Store.',
          ],
        ),
      ];
    } else {
      return [
        _WearableGuide(
          brand: 'Apple Watch',
          icon: Icons.watch_rounded,
          iconColor: Colors.black87,
          steps: [
            'Your Apple Watch automatically syncs steps to Apple Health via the Health app.',
            'No extra setup is needed — as long as your Apple Watch is paired, steps are shared with Apple Health.',
            'Wellnex reads directly from Apple Health with your permission.',
          ],
        ),
        _WearableGuide(
          brand: 'Fitbit',
          icon: Icons.watch_rounded,
          iconColor: const Color(0xFF00B0B9),
          steps: [
            'Install the Fitbit app from the App Store.',
            'Log in to your Fitbit account and pair your device.',
            'Go to Fitbit app → Today → Profile → App Gallery → Health.',
            'Enable "Sync with Apple Health" and allow steps, distance and calories.',
            'Fitbit will now automatically push your steps into Apple Health.',
          ],
        ),
        _WearableGuide(
          brand: 'Garmin',
          icon: Icons.gps_fixed_rounded,
          iconColor: const Color(0xFF006EBB),
          steps: [
            'Install the Garmin Connect app from the App Store.',
            'Pair your Garmin device via Bluetooth.',
            'In Garmin Connect, go to More → Settings → Sync with Apple Health.',
            'Enable the toggle and grant the required permissions.',
            'Your Garmin steps will now flow into Apple Health automatically.',
          ],
        ),
        _WearableGuide(
          brand: 'Samsung (Galaxy Watch)',
          icon: Icons.watch_outlined,
          iconColor: const Color(0xFF1428A0),
          steps: [
            'Samsung Galaxy Watch is primarily designed for Android.',
            'Limited iOS support is available via the Galaxy Wearable app.',
            'In Galaxy Wearable app, go to Watch Settings → Health → Check if Apple Health sync is available for your model.',
            'Note: Not all Galaxy Watch models support Apple Health on iOS.',
          ],
        ),
      ];
    }
  }
}

// ── Status Card ──────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final bool authorized;
  final int todaySteps;
  final bool isAndroid;
  final VoidCallback onGrantPermission;
  final VoidCallback onOpenHealthApp;

  const _StatusCard({
    required this.authorized,
    required this.todaySteps,
    required this.isAndroid,
    required this.onGrantPermission,
    required this.onOpenHealthApp,
  });

  @override
  Widget build(BuildContext context) {
    final platform = isAndroid ? 'Google Health Connect' : 'Apple Health';
    final platformIcon = isAndroid ? Icons.android_rounded : Icons.apple_rounded;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: authorized
              ? [AppTheme.primaryGreen.withValues(alpha: 0.15), AppTheme.primaryGreen.withValues(alpha: 0.05)]
              : [AppTheme.error.withValues(alpha: 0.12), AppTheme.error.withValues(alpha: 0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: authorized ? AppTheme.primaryGreen.withValues(alpha: 0.4) : AppTheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (authorized ? AppTheme.primaryGreen : AppTheme.error).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  platformIcon,
                  color: authorized ? AppTheme.primaryGreen : AppTheme.error,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      platform,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: authorized ? AppTheme.primaryGreen : AppTheme.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          authorized ? 'Connected' : 'Permission Required',
                          style: TextStyle(
                            fontSize: 13,
                            color: authorized ? AppTheme.primaryGreen : AppTheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (authorized) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatPill(
                  icon: Icons.directions_walk_rounded,
                  label: 'Today',
                  value: '$todaySteps steps',
                  color: AppTheme.primaryGreen,
                ),
                const SizedBox(width: 12),
                _StatPill(
                  icon: Icons.sync_rounded,
                  label: 'Polling',
                  value: 'Every 15 sec',
                  color: AppTheme.secondaryBlue,
                ),
              ],
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onOpenHealthApp,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text('Open $platform'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryGreen,
                side: BorderSide(color: AppTheme.primaryGreen.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Text(
              'Wellnex needs access to $platform to read your daily step count. Your data never leaves your device.',
              style: TextStyle(fontSize: 13, color: AppTheme.neutral600, height: 1.4),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onGrantPermission,
              icon: const Icon(Icons.lock_open_rounded, size: 18),
              label: const Text('Grant Permission'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatPill({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8))),
              Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── How It Works Card ────────────────────────────────────────────────────────

class _HowItWorksCard extends StatelessWidget {
  final bool isAndroid;
  const _HowItWorksCard({required this.isAndroid});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neutral200),
      ),
      child: Column(
        children: [
          _HowItWorksStep(
            number: '1',
            icon: Icons.sensors_rounded,
            title: 'Phone counts your steps',
            subtitle: 'Your phone\'s built-in step counter chip detects every step you take — no wearable needed.',
            color: AppTheme.primaryGreen,
          ),
          const _ArrowDivider(),
          _HowItWorksStep(
            number: '2',
            icon: isAndroid ? Icons.android_rounded : Icons.apple_rounded,
            title: isAndroid ? 'Health Connect aggregates' : 'Apple Health aggregates',
            subtitle: isAndroid
                ? 'Google Health Connect collects steps from your phone and any connected wearables into one daily total.'
                : 'Apple Health collects steps from your iPhone and Apple Watch into one accurate daily total.',
            color: AppTheme.secondaryBlue,
          ),
          const _ArrowDivider(),
          _HowItWorksStep(
            number: '3',
            icon: Icons.favorite_rounded,
            title: 'Wellnex reads the total',
            subtitle: 'Every 15 seconds, Wellnex reads your daily step total and syncs your progress, rewards, and streaks.',
            color: const Color(0xFFE91E8C),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksStep extends StatelessWidget {
  final String number;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _HowItWorksStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 3),
              Text(subtitle, style: TextStyle(fontSize: 12, color: AppTheme.neutral500, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArrowDivider extends StatelessWidget {
  const _ArrowDivider();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 19, top: 4, bottom: 4),
      child: Icon(Icons.arrow_downward_rounded, size: 16, color: AppTheme.neutral400),
    );
  }
}

// ── Wearable Guide Card ──────────────────────────────────────────────────────

class _WearableGuide {
  final String brand;
  final IconData icon;
  final Color iconColor;
  final List<String> steps;

  const _WearableGuide({
    required this.brand,
    required this.icon,
    required this.iconColor,
    required this.steps,
  });
}

class _WearableGuideCard extends StatelessWidget {
  final _WearableGuide guide;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _WearableGuideCard({
    required this.guide,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? guide.iconColor.withValues(alpha: 0.4) : AppTheme.neutral200,
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: isExpanded
            ? [BoxShadow(color: guide.iconColor.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: guide.iconColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(guide.icon, color: guide.iconColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        guide.brand,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.neutral500),
                    ),
                  ],
                ),

                // Expandable steps
                if (isExpanded) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  ...guide.steps.asMap().entries.map((entry) {
                    final i = entry.key;
                    final step = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: guide.iconColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: guide.iconColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(step, style: const TextStyle(fontSize: 13, height: 1.4)),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tip Card ─────────────────────────────────────────────────────────────────

class _TipCard extends StatelessWidget {
  final bool isAndroid;
  const _TipCard({required this.isAndroid});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.secondaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.secondaryBlue.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tips_and_updates_rounded, color: AppTheme.secondaryBlue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isAndroid
                  ? 'Tip: Make sure Health Connect is installed on your phone (Android 14+ includes it by default). If steps are missing, open Health Connect and verify that your wearable app has been granted step permissions.'
                  : 'Tip: If steps from your Apple Watch are not appearing, open the Health app → Sources → and make sure your watch is listed and all categories are enabled.',
              style: TextStyle(fontSize: 13, color: AppTheme.secondaryBlue, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
