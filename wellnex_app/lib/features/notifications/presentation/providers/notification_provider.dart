// Deprecated: Use notifications_provider.dart instead.
// This file is kept temporarily for backward compatibility, although all internal imports
// have been updated to use the unified notifications_provider.dart.

import 'notifications_provider.dart';

// We also re-export the entire unified provider file so that if anything
// imports this file, they still get access to AppNotification, NotificationsNotifier, etc.
export 'notifications_provider.dart';

// Alias for backward compatibility if any third-party or forgotten file still imports it.
final notificationProvider = notificationsProvider;
