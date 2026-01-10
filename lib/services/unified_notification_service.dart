import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dentease/logic/fcm_service.dart';

/// Unified Notification Service
/// Handles both FCM push notifications and in-app notifications
/// Integrates with the messaging system for real-time updates
class UnifiedNotificationService {
  static final UnifiedNotificationService _instance =
      UnifiedNotificationService._internal();
  factory UnifiedNotificationService() => _instance;
  UnifiedNotificationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _notificationChannel;
  StreamSubscription? _messageNotificationSubscription;

  /// Initialize notification service for a user
  Future<void> initialize({
    required String userId,
    required String userRole,
    required String tableName,
    required String idColumn,
    BuildContext? context,
  }) async {
    debugPrint(
        '🔔 [UnifiedNotificationService] Initializing for $userRole: $userId');

    // 1. Initialize FCM
    await FCMService.initialize();

    // 2. Save FCM token to user's table
    await FCMService.saveUserToken(
      userId: userId,
      tableName: tableName,
      idColumn: idColumn,
    );

    // 3. Subscribe admin to topic if needed
    if (userRole == 'admin') {
      await FCMService.subscribeAdminToTopic();
    }

    // 4. Listen for system notifications
    if (context != null) {
      debugPrint(
          '🔔 [UnifiedNotificationService] Setting up system notification listener');
      _initializeSystemNotificationListener(context, userId, userRole);
    } else {
      debugPrint(
          '⚠️ [UnifiedNotificationService] No context provided, skipping listener');
    }

    // 5. Listen for message notifications specifically
    _initializeMessageNotificationListener(userId);

    debugPrint(
        '✅ [UnifiedNotificationService] Initialization complete for $userRole');
  }

  /// Initialize system notification listener for in-app notifications
  void _initializeSystemNotificationListener(
    BuildContext context,
    String userId,
    String userRole,
  ) {
    debugPrint(
        '🔔 [UnifiedNotificationService] Setting up realtime channel for: $userId');
    _notificationChannel?.unsubscribe();
    _notificationChannel = _supabase
        .channel('system_notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'system_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: userId,
          ),
          callback: (payload) {
            debugPrint(
                '🔔 [UnifiedNotificationService] Received notification: ${payload.newRecord}');
            final notification = payload.newRecord;
            _showInAppNotification(context, notification);
            _markNotificationAsRead(notification['id']);
          },
        )
        .subscribe();
    debugPrint('✅ [UnifiedNotificationService] Realtime channel subscribed');
  }

  /// Initialize message-specific notification listener
  void _initializeMessageNotificationListener(String userId) {
    _messageNotificationSubscription?.cancel();
    _messageNotificationSubscription = _supabase
        .from('system_notifications')
        .stream(primaryKey: ['id']).listen((notifications) {
      // Filter for this user and chat messages
      final userNotifications = notifications
          .where((n) =>
              n['recipient_id'] == userId &&
              n['event_type'] == 'chat_message' &&
              n['is_read'] == false)
          .toList();

      // Handle real-time message notifications
      for (final notification in userNotifications) {
        debugPrint('New message notification: ${notification['title']}');
      }
    });
  }

  /// Show in-app notification as SnackBar
  void _showInAppNotification(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    debugPrint(
        '🔔 [UnifiedNotificationService] Showing in-app notification: $data');

    if (!context.mounted) {
      debugPrint(
          '⚠️ [UnifiedNotificationService] Context not mounted, skipping notification');
      return;
    }

    final title = data['title'] ?? 'Notification';
    final body = data['body'] ?? '';
    final eventType = data['event_type'] as String?;

    // Skip chat_message notifications - handled by InAppMessageNotificationService
    if (eventType == 'chat_message') {
      debugPrint(
          '🔔 [UnifiedNotificationService] Skipping chat_message - handled by InAppMessageNotificationService');
      return;
    }

    debugPrint('🔔 [UnifiedNotificationService] Displaying: $title - $body');

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
                color: Colors.white,
              ),
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(fontSize: 13, color: Colors.white),
              ),
            ],
          ],
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _getNotificationColor(eventType),
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

  /// Get notification color based on event type
  Color _getNotificationColor(String? eventType) {
    switch (eventType) {
      case 'chat_message':
        return const Color(0xFF9C27B0); // Purple
      case 'booking_confirmed':
        return const Color(0xFF0D2A7A); // Blue
      case 'clinic_approved':
        return const Color(0xFF4CAF50); // Green
      case 'clinic_application':
        return const Color(0xFFFF9800); // Orange
      case 'staff_leave_alert':
        return const Color(0xFFF44336); // Red
      default:
        return const Color(0xFF424242); // Grey
    }
  }

  /// Handle notification tap - navigate to relevant page
  void _handleNotificationTap(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final eventType = data['event_type'] as String?;
    final metadata = data['metadata'] as Map<String, dynamic>?;

    switch (eventType) {
      case 'chat_message':
        // Navigate to chat screen
        final conversationId = metadata?['conversation_id'] as String?;
        if (conversationId != null) {
          // TODO: Navigate to ChatScreen with conversationId
          debugPrint('Navigate to chat: $conversationId');
        }
        break;
      case 'booking_confirmed':
      case 'booking_cancelled':
        // Navigate to appointments
        debugPrint('Navigate to appointments');
        break;
      case 'clinic_approved':
        // Navigate to clinic dashboard
        debugPrint('Navigate to clinic dashboard');
        break;
      default:
        debugPrint('Unknown notification type: $eventType');
    }
  }

  /// Mark notification as read
  Future<void> _markNotificationAsRead(String? notificationId) async {
    if (notificationId == null) return;

    try {
      await _supabase
          .from('system_notifications')
          .update({'is_read': true}).eq('id', notificationId);
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Get unread notification count for a user
  Future<int> getUnreadNotificationCount(String userId) async {
    try {
      final response = await _supabase
          .from('system_notifications')
          .select('id')
          .eq('recipient_id', userId)
          .eq('is_read', false);

      return response.length;
    } catch (e) {
      debugPrint('Error fetching unread notification count: $e');
      return 0;
    }
  }

  /// Stream unread notification count
  Stream<int> streamUnreadNotificationCount(String userId) {
    return _supabase
        .from('system_notifications')
        .stream(primaryKey: ['id']).map((notifications) => notifications
            .where((n) => n['recipient_id'] == userId && n['is_read'] == false)
            .length);
  }

  /// Send a test notification (for debugging)
  Future<void> sendTestNotification({
    required String recipientId,
    required String recipientRole,
    String title = 'Test Notification',
    String body = 'This is a test notification',
  }) async {
    try {
      await _supabase.from('system_notifications').insert({
        'recipient_id': recipientId,
        'recipient_role': recipientRole,
        'event_type': 'test',
        'title': title,
        'body': body,
        'priority': 'normal',
        'metadata': {'test': true},
      });
    } catch (e) {
      debugPrint('Error sending test notification: $e');
    }
  }

  /// Cleanup and dispose
  void dispose() {
    _notificationChannel?.unsubscribe();
    _messageNotificationSubscription?.cancel();
  }

  /// Unsubscribe admin from topic (on logout)
  Future<void> unsubscribeAdmin() async {
    await FCMService.unsubscribeAdminFromTopic();
  }
}
