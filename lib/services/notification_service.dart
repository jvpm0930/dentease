import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Notification Service for real-time in-app notifications
/// Listens to Supabase realtime changes on notifications table
class NotificationService {
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;
  RealtimeChannel? _notificationChannel;

  /// Initialize real-time listener for user notifications
  void initializeListener(
    BuildContext context,
    String userId,
    String userRole,
  ) {
    _notificationChannel = supabase
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final notification = payload.newRecord;
            _showInAppNotification(context, notification);
            _markAsRead(notification['notification_id']);
          },
        )
        .subscribe();
  }

  /// Show in-app SnackBar notification
  void _showInAppNotification(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    if (!context.mounted) return;

    final title = data['title'] ?? 'Notification';
    final body = data['body'] ?? '';
    final type = data['type'] as String?;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(fontSize: 13)),
          ],
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _getNotificationColor(type),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            _handleNotificationTap(context, data);
          },
        ),
      ),
    );
  }

  /// Get color based on notification type
  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'clinic_approved':
        return const Color(0xFF4CAF50); // Green
      case 'booking_confirmed':
        return const Color(0xFF0D2A7A); // Blue
      case 'new_message':
        return const Color(0xFF9C27B0); // Purple
      case 'clinic_application':
        return const Color(0xFFFF9800); // Orange
      default:
        return const Color(0xFF424242); // Grey
    }
  }

  /// Handle notification tap - navigate to relevant page
  void _handleNotificationTap(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final type = data['type'] as String?;
    final notificationData = data['data'] as Map<String, dynamic>?;

    // TODO: Implement navigation based on type
    // Example:
    // if (type == 'booking_confirmed') {
    //   Navigator.push(context, MaterialPageRoute(...));
    // }
  }

  /// Mark notification as read
  Future<void> _markAsRead(String? notificationId) async {
    if (notificationId == null) return;

    try {
      await supabase
          .from('notifications')
          .update({'is_read': true}).eq('notification_id', notificationId);
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Fetch unread notification count
  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await supabase
          .from('notifications')
          .select('notification_id')
          .eq('user_id', userId)
          .eq('is_read', false);

      return response.length;
    } catch (e) {
      debugPrint('Error fetching unread count: $e');
      return 0;
    }
  }

  /// Dispose and cleanup
  void dispose() {
    _notificationChannel?.unsubscribe();
  }
}
