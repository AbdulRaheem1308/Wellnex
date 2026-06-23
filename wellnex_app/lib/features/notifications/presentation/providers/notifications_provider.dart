import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/api_service.dart';

enum NotificationType { challenge, reward, social, system, achievement, steps }

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String description;
  final DateTime timestamp;
  final bool isRead;
  final String? actionUrl;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.isRead,
    this.actionUrl,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    DateTime parsedTimestamp;
    try {
      parsedTimestamp = json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now();
    } catch (_) {
      parsedTimestamp = DateTime.now();
    }

    return AppNotification(
      id: json['id']?.toString() ?? '',
      type: _parseType(json['type']?.toString()),
      title: json['title']?.toString() ?? '',
      description: (json['message'] ?? json['description'])?.toString() ?? '',
      timestamp: parsedTimestamp,
      isRead: json['isRead'] ?? false,
      actionUrl: json['actionUrl']?.toString(),
    );
  }

  static NotificationType _parseType(String? type) {
    if (type == null) return NotificationType.system;
    
    final t = type.toLowerCase();
    if (t.contains('achievement')) return NotificationType.achievement;
    if (t.contains('step')) return NotificationType.steps;
    if (t.contains('reward') || t.contains('streak')) return NotificationType.reward;
    if (t.contains('social') || t.contains('referral')) return NotificationType.social;
    if (t.contains('challenge')) return NotificationType.challenge;
    
    return NotificationType.system;
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      description: description,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      actionUrl: actionUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotification &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type &&
          title == other.title &&
          description == other.description &&
          timestamp == other.timestamp &&
          isRead == other.isRead &&
          actionUrl == other.actionUrl;

  @override
  int get hashCode =>
      id.hashCode ^
      type.hashCode ^
      title.hashCode ^
      description.hashCode ^
      timestamp.hashCode ^
      isRead.hashCode ^
      actionUrl.hashCode;
}

class NotificationsState {
  final List<AppNotification> notifications;
  final String activeFilter;
  final bool isLoading;
  final String? error;

  NotificationsState({
    this.notifications = const [],
    this.activeFilter = 'All',
    this.isLoading = false,
    this.error,
  });

  NotificationsState copyWith({
    List<AppNotification>? notifications,
    String? activeFilter,
    bool? isLoading,
    String? error,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      activeFilter: activeFilter ?? this.activeFilter,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  int get unreadCount => notifications.where((n) => !n.isRead).length;
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final ApiService _apiService;

  NotificationsNotifier(this._apiService) : super(NotificationsState()) {
    loadNotifications();
  }

  void setFilter(String filter) {
    state = state.copyWith(activeFilter: filter);
  }

  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _apiService.get('/notifications');
      final notifications = (response.data as List)
          .map((json) => AppNotification.fromJson(json))
          .toList();
      state = state.copyWith(notifications: notifications, isLoading: false);
    } catch (e) {
      // Show empty state on error - no demo data
      state = state.copyWith(
        notifications: [],
        isLoading: false,
        error: ApiError.from(e).message,
      );
    }
  }

  void markAsRead(String id) {
    _apiService.post('/notifications/$id/read').ignore();
    state = state.copyWith(
      notifications: state.notifications.map((n) {
        return n.id == id ? n.copyWith(isRead: true) : n;
      }).toList(),
    );
  }

  void markAllAsRead() {
    _apiService.post('/notifications/all/read').ignore();
    state = state.copyWith(
      notifications: state.notifications.map((n) => n.copyWith(isRead: true)).toList(),
    );
  }

  void deleteNotification(String id) {
    _apiService.post('/notifications/$id/delete').ignore();
    state = state.copyWith(
      notifications: state.notifications.where((n) => n.id != id).toList(),
    );
  }
  
  void clearError() {
    state = state.copyWith(error: null);
  }
}

final notificationsProvider = StateNotifierProvider.autoDispose<NotificationsNotifier, NotificationsState>((ref) {
  return NotificationsNotifier(ref.watch(apiServiceProvider));
});
