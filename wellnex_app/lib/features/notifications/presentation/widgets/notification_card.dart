import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wellnex_app/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/notifications_provider.dart';

class NotificationCard extends ConsumerWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 7) {
      return '${date.day}/${date.month}';
    } else if (diff.inDays >= 1) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours >= 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes >= 1) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final semanticLabel = '${notification.title}. ${notification.description}. ${_timeAgo(notification.timestamp)}. ${notification.isRead ? '' : 'Unread'}';

    return Semantics(
      label: semanticLabel,
      button: true,
      child: Dismissible(
        key: Key(notification.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDismiss(),
        background: Container(
          color: AppTheme.error,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const ExcludeSemantics(child: Icon(Icons.delete, color: Colors.white)),
        ),
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: notification.isRead ? Colors.transparent : AppTheme.primaryGreen.withValues(alpha: 0.05),
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                ExcludeSemantics(child: _buildIcon(context, notification.type)),
                const SizedBox(width: 16),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                                fontSize: 16,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _timeAgo(notification.timestamp),
                            style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.description,
                        style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (notification.actionUrl != null) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Tap to view', 
                          style: TextStyle(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Unread Dot
                if (!notification.isRead)
                  ExcludeSemantics(
                    child: Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(left: 8, top: 6),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context, NotificationType type) {
    IconData icon;
    Color color;

    switch (type) {
      case NotificationType.challenge:
        icon = Icons.emoji_events;
        color = AppTheme.accentOrange;
        break;
      case NotificationType.reward:
        icon = Icons.card_giftcard;
        color = AppTheme.accentPurple;
        break;
      case NotificationType.social:
        icon = Icons.people;
        color = AppTheme.secondaryBlue;
        break;
      case NotificationType.achievement:
        icon = Icons.military_tech;
        color = AppTheme.primaryGreen;
        break;
      case NotificationType.steps:
        icon = Icons.directions_walk;
        color = AppTheme.primaryGreen;
        break;
      case NotificationType.system:
        icon = Icons.info_outline;
        color = AppTheme.neutral500;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
