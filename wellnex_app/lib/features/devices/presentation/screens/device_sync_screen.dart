import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:wellnex_app/l10n/app_localizations.dart';
import '../../../../services/ad_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/device_provider.dart';

/// Screen 15: Wearable Sync & Device Dashboard
class DeviceSyncScreen extends ConsumerWidget {
  const DeviceSyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(deviceProvider);

    ref.listen(deviceProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.deviceManagement),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Text(
              l10n.connectedDevices,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Device List
            Expanded(
              child: state.devices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppTheme.neutral100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.watch_off_outlined, size: 48, color: AppTheme.neutral400),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            l10n.noDevicesConnected,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.connectWearablePrompt,
                            style: TextStyle(color: AppTheme.neutral500),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: state.devices.length,
                      itemBuilder: (context, index) {
                        final device = state.devices[index];
                        return _buildDeviceCard(context, ref, device, l10n);
                      },
                    ),
            ),
            
            // Add Device Button
            ElevatedButton.icon(
              onPressed: state.isScanning ? null : () {
                ref.read(deviceProvider.notifier).connectHealthDevice();
              },
              icon: state.isScanning 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add),
              label: Text(l10n.connectHealthApp), // More accurate label
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(BuildContext context, WidgetRef ref, ConnectedDevice device, AppLocalizations l10n) {
    final isSyncing = device.status == SyncStatus.syncing;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neutral200),
        boxShadow: [
          BoxShadow(
            color: AppTheme.neutral200.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Brand Icon Placeholder
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.neutral100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_getBrandIcon(device.brand), color: AppTheme.primaryGreen),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: _getStatusColor(device.status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getStatusText(device.status, l10n),
                          style: TextStyle(color: AppTheme.neutral500, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sync Button
                  IconButton(
                    onPressed: isSyncing 
                      ? null 
                      : () async { // Trigger Sync
                          await ref.read(deviceProvider.notifier).syncDevice(device.id);
                          
                          if (context.mounted) {
                             // Show Interstitial Ad after sync (simulating post-workout)
                             ref.read(adServiceProvider).showInterstitialAd();
                          }
                        },
                    icon: isSyncing 
                      ? const SizedBox(
                          width: 20, height: 20, 
                          child: CircularProgressIndicator(strokeWidth: 2)
                        )
                      : const Icon(Icons.sync, color: AppTheme.primaryGreen),
                    tooltip: l10n.syncSteps,
                  ),
                  
                  // Disconnect Button
                  if (device.type != 'PHONE')
                    IconButton(
                      onPressed: isSyncing 
                        ? null 
                        : () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(l10n.disconnectDeviceTitle),
                                content: Text(l10n.disconnectDeviceConfirm(device.name)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text(l10n.cancel),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                                    child: Text(l10n.disconnect),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await ref.read(deviceProvider.notifier).removeDevice(device.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(l10n.deviceDisconnectedSuccess(device.name))),
                                );
                              }
                            }
                          },
                      icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                      tooltip: l10n.disconnectDeviceTooltip,
                    ),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               _buildMetric(l10n.stepsLabel, '${device.syncedSteps}'),
               _buildMetric(l10n.lastSyncLabel, _formatTime(device.lastSyncTime, l10n)),
             ],
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.1, end: 0);
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.neutral500, fontSize: 12)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }

  IconData _getBrandIcon(String brand) {
    switch (brand) {
      case 'Apple': return Icons.apple;
      case 'Fitbit': return Icons.watch;
      case 'Garmin': return Icons.gps_fixed;
      case 'Phone': return Icons.phone_android;
      case 'Google': return Icons.android;
      default: return Icons.watch;
    }
  }

  Color _getStatusColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.connected: return AppTheme.success;
      case SyncStatus.syncing: return AppTheme.secondaryBlue;
      case SyncStatus.error: return AppTheme.error;
      case SyncStatus.disconnected: return AppTheme.neutral400;
    }
  }

  String _getStatusText(SyncStatus status, AppLocalizations l10n) {
    switch (status) {
      case SyncStatus.connected: return l10n.statusConnected;
      case SyncStatus.syncing: return l10n.statusSyncing;
      case SyncStatus.error: return l10n.statusSyncError;
      case SyncStatus.disconnected: return l10n.statusDisconnected;
    }
  }

  String _formatTime(DateTime? time, AppLocalizations l10n) {
    if (time == null) return l10n.never;
    return DateFormat('MMM d, h:mm a').format(time);
  }
}
