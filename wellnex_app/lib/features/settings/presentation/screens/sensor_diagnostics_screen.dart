import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safe_device/safe_device.dart';
import 'package:workmanager/workmanager.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../services/health_service.dart';
import '../../../../services/storage_service.dart';

import '../../../../core/services/background_service.dart';
import '../../../../services/api_service.dart';

class SensorDiagnosticsScreen extends ConsumerStatefulWidget {
  const SensorDiagnosticsScreen({super.key});

  @override
  ConsumerState<SensorDiagnosticsScreen> createState() => _SensorDiagnosticsScreenState();
}

class _SensorDiagnosticsScreenState extends ConsumerState<SensorDiagnosticsScreen> {
  // Permission statuses
  PermissionStatus _activityPermission = PermissionStatus.denied;

  // Background sync info
  String _bgLastRun = 'Never';
  String _bgLastStatus = 'N/A';

  // Device info (SafeDevice)
  bool _isRealDevice = true;
  bool _isJailbroken = false;
  bool _isMockLocation = false;

  // Health API state
  int _healthStepsToday = -1;
  bool _healthAuthorized = false;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadDiagnostics() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Check permissions
      final activityStatus = await Permission.activityRecognition.status;

      // 2. Read background sync stats from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final bgLastRunVal = prefs.getString('bg_sync_last_run') ?? 'Never';
      final bgLastStatusVal = prefs.getString('bg_sync_status') ?? 'N/A';

      // 3. Read Device Safety Info
      bool realDevice = true;
      bool jailbroken = false;
      bool mockLocation = false;
      try {
        realDevice = await SafeDevice.isRealDevice.timeout(const Duration(seconds: 2));
        jailbroken = await SafeDevice.isJailBroken.timeout(const Duration(seconds: 2));
        mockLocation = await SafeDevice.isMockLocation.timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint('SafeDevice check failed: $e');
      }

      // 4. Test Health API authorization
      bool healthAuth = false;
      int healthSteps = -1;
      try {
        final healthService = HealthService();
        healthAuth = await healthService.requestAuthorization().timeout(const Duration(seconds: 2));
        if (healthAuth) {
          healthSteps = await healthService.getTodaySteps();
        }
      } catch (e) {
        debugPrint('Health check failed: $e');
      }

      if (mounted) {
        setState(() {
          _activityPermission = activityStatus;
          _bgLastRun = bgLastRunVal;
          _bgLastStatus = bgLastStatusVal;
          _isRealDevice = realDevice;
          _isJailbroken = jailbroken;
          _isMockLocation = mockLocation;
          _healthAuthorized = healthAuth;
          _healthStepsToday = healthSteps;
        });
      }
    } catch (e) {
      debugPrint('Error loading diagnostics: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  Future<void> _requestActivityPermission() async {
    final status = await Permission.activityRecognition.request();
    setState(() => _activityPermission = status);
    _loadDiagnostics();
  }

  Future<void> _triggerOneOffBackgroundTask() async {
    setState(() => _isLoading = true);
    try {
      await Workmanager().registerOneOffTask(
        "wellnex_sync_job_manual_${DateTime.now().millisecondsSinceEpoch}",
        kBackgroundSyncTask,
        constraints: Constraints(networkType: NetworkType.connected),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Force triggered background task. Re-load in 10s to inspect results.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to trigger background task: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testHealthSdkFetch() async {
    setState(() => _isLoading = true);
    try {
      final healthService = HealthService();

      final isAuthorized = await healthService.requestAuthorization();
      setState(() => _healthAuthorized = isAuthorized);
      if (isAuthorized) {
        final steps = await healthService.getTodaySteps();
        setState(() => _healthStepsToday = steps);
      } else {
        setState(() => _healthStepsToday = -99); // Unauthorized indicator
      }
    } catch (e) {
      setState(() => _healthStepsToday = -500); // Error indicator
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showReportAnomalyDialog() async {
    final controller = TextEditingController();
    final isSubmitted = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Report Tracking Issue'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Are your steps inaccurate? Describe the issue below and we will investigate.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'E.g., I did not walk 20,000 steps today, it spiked randomly.',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
              child: const Text('Submit Report'),
            ),
          ],
        );
      },
    );

    if (isSubmitted == true && controller.text.isNotEmpty && mounted) {
      setState(() => _isLoading = true);
      try {
        // Need to import ApiService here or use ref.read(apiServiceProvider)
        // Since we are not using ref yet, we can instantiate ApiService directly or via ref.
        // sensor_diagnostics_screen is a ConsumerStatefulWidget so we have access to `ref`
        // However, I need to import api_service.dart at the top. Wait, let me just use ApiService manually 
        // but it's better to use ref.read.
        // Let's assume ApiService is accessible. I will add the import at the top later if needed.
        final api = ref.read(apiServiceProvider);
        await api.post(
          '/anomalies/report',
          data: {
            'description': controller.text,
            'metadata': {
              'reportedSteps': _healthStepsToday,
              'deviceReal': _isRealDevice,
            }
          },
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report submitted successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to submit report: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor & Sync Diagnostics'),
        actions: [
          Tooltip(
            message: 'Refresh diagnostics',
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadDiagnostics,
              tooltip: 'Refresh diagnostics',
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
            ),
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildDiagnosticsWarningCard(),
                const SizedBox(height: 16),
                _buildSectionCard(
                  title: 'Device Safety & Integrations',
                  icon: Icons.security,
                  children: [
                    _buildDiagnosticRow('Is Physical Device?', _isRealDevice ? 'Yes' : 'No (Emulator)', _isRealDevice),
                    _buildDiagnosticRow('Is Rooted/Jailbroken?', _isJailbroken ? 'Yes (Vulnerable)' : 'No', !_isJailbroken),
                    _buildDiagnosticRow('Mock Location Enabled?', _isMockLocation ? 'Yes (Cheating Flagged)' : 'No', !_isMockLocation),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  title: 'Permissions Status',
                  icon: Icons.vpn_key_outlined,
                  children: [
                    _buildPermissionRow('Activity Recognition', _activityPermission, _requestActivityPermission),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  title: 'Health API Tracking',
                  icon: Icons.directions_run_rounded,
                  children: [
                    _buildDiagnosticRow(
                      'Health API Source',
                      'Google Health Connect (Android) / Apple HealthKit (iOS)',
                      true,
                    ),
                    _buildDiagnosticRow(
                      'Authorization Status',
                      _healthAuthorized ? 'Authorized ✅' : 'Not Authorized ❌',
                      _healthAuthorized,
                    ),
                    _buildDiagnosticRow(
                      'Steps Today (Health API)',
                      _healthStepsToday == -1
                          ? 'Tap Refresh to test'
                          : (_healthStepsToday == -99
                              ? 'Unauthorized — grant permission'
                              : '$_healthStepsToday steps'),
                      _healthStepsToday >= 0,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _testHealthSdkFetch,
                      icon: const Icon(Icons.search),
                      label: const Text('Re-Test Health API Fetch'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryBlue),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  title: 'Background Sync Worker Logs',
                  icon: Icons.history_toggle_off,
                  children: [
                    _buildDiagnosticRow('Last Run Executed', _bgLastRun, _bgLastRun != 'Never'),
                    _buildDiagnosticRow('Execution Status Message', _bgLastStatus, _bgLastStatus.contains('Success')),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _triggerOneOffBackgroundTask,
                      icon: const Icon(Icons.sync_problem),
                      label: const Text('Force Trigger Background Sync Task'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  title: 'Support & Issue Reporting',
                  icon: Icons.support_agent,
                  children: [
                    const Text(
                      'If you notice significant discrepancies in your step tracking (e.g. thousands of ghost steps), please report an anomaly to our engineering team.',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _showReportAnomalyDialog,
                      icon: const Icon(Icons.bug_report),
                      label: const Text('Report Tracking Anomaly'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentOrange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildDiagnosticsWarningCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.defaultRadius),
        border: Border.all(color: AppTheme.accentOrange),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.accentOrange, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Developer Screen: This view displays raw hardware sensor telemetry, database sync states, and allows reset operations for testing.',
              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.neutral700, fontSize: 13, height: 1.4),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.defaultRadius),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticRow(String label, String value, bool isOk) {
    return Semantics(
      label: '$label: $value',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color ?? AppTheme.neutral700)),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOk ? Colors.green.withValues(alpha: 0.1) : AppTheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isOk ? Colors.green.shade800 : AppTheme.error,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionRow(String permissionName, PermissionStatus status, VoidCallback onRequest) {
    final isGranted = status == PermissionStatus.granted;
    return Semantics(
      label: '$permissionName permission: ${status.toString().split('.').last}.',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(permissionName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                Text(
                  status.toString().split('.').last.toUpperCase(),
                  style: TextStyle(fontSize: 11, color: isGranted ? Colors.green : AppTheme.error),
                ),
              ],
            ),
            Semantics(
              label: isGranted ? '$permissionName already granted' : 'Grant $permissionName permission',
              button: true,
              child: ElevatedButton(
                onPressed: isGranted ? null : onRequest,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  minimumSize: const Size(60, 44),
                  backgroundColor: isGranted ? AppTheme.neutral300 : AppTheme.primaryGreen,
                ),
                child: Text(isGranted ? 'Granted' : 'Grant', style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
