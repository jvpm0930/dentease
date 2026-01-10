import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// In-App Message Notification Service
/// Listens directly to the messages table and shows in-app notifications
/// when new messages arrive for the current user
class InAppMessageNotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  RealtimeChannel? _messageChannel;
  String? _currentUserId;
  BuildContext? _context;
  VoidCallback? _onMessageReceived;

  // Track last shown notification to avoid duplicates
  String? _lastShownMessageId;
  DateTime? _lastNotificationTime;

  // Track conversations user is currently viewing
  String? _activeConversationId;

  /// Initialize the service
  void initialize({
    required String userId,
    required String userRole,
    required BuildContext context,
    VoidCallback? onMessageReceived,
  }) {
    debugPrint(
        '🔔 [InAppMessageNotification] Initializing for $userRole: $userId');

    _currentUserId = userId;
    _context = context;
    _onMessageReceived = onMessageReceived;

    _subscribeToMessages();
  }

  /// Set the active conversation (to suppress notifications for it)
  void setActiveConversation(String? conversationId) {
    _activeConversationId = conversationId;
    debugPrint(
        '🔔 [InAppMessageNotification] Active conversation: $conversationId');
  }

  /// Subscribe to new messages
  void _subscribeToMessages() {
    debugPrint('🔔 [InAppMessageNotification] Setting up message listener...');

    _messageChannel?.unsubscribe();

    // Listen to all new messages
    _messageChannel = _supabase
        .channel('inapp_messages:${_currentUserId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            debugPrint(
                '🔔 [InAppMessageNotification] New message received: ${payload.newRecord}');
            _handleNewMessage(payload.newRecord);
          },
        )
        .subscribe((status, error) {
      debugPrint(
          '🔔 [InAppMessageNotification] Subscription status: $status, error: $error');
    });

    debugPrint('✅ [InAppMessageNotification] Message listener subscribed');
  }

  /// Handle incoming message
  Future<void> _handleNewMessage(Map<String, dynamic> message) async {
    final messageId = message['message_id'] as String?;
    final senderId = message['sender_id'] as String?;
    final senderRole = message['sender_role'] as String?;
    final senderName = message['sender_name'] as String?;
    final content = message['content'] as String?;
    final conversationId = message['conversation_id'] as String?;

    debugPrint('🔔 [InAppMessageNotification] Processing message:');
    debugPrint('   - messageId: $messageId');
    debugPrint('   - senderId: $senderId');
    debugPrint('   - currentUserId: $_currentUserId');
    debugPrint('   - conversationId: $conversationId');
    debugPrint('   - activeConversationId: $_activeConversationId');

    // Skip if message is from current user
    if (senderId == _currentUserId) {
      debugPrint('🔔 [InAppMessageNotification] Skipping - message from self');
      return;
    }

    // Skip if user is currently viewing this conversation
    if (conversationId == _activeConversationId) {
      debugPrint(
          '🔔 [InAppMessageNotification] Skipping - user viewing this conversation');
      return;
    }

    // Skip duplicate notifications
    if (messageId == _lastShownMessageId) {
      debugPrint('🔔 [InAppMessageNotification] Skipping - duplicate message');
      return;
    }

    // Rate limit notifications (max 1 per second)
    final now = DateTime.now();
    if (_lastNotificationTime != null &&
        now.difference(_lastNotificationTime!) < const Duration(seconds: 1)) {
      debugPrint('🔔 [InAppMessageNotification] Skipping - rate limited');
      return;
    }

    // Check if user is a participant in this conversation
    final isParticipant = await _isUserInConversation(conversationId);
    if (!isParticipant) {
      debugPrint(
          '🔔 [InAppMessageNotification] Skipping - user not in conversation');
      return;
    }

    _lastShownMessageId = messageId;
    _lastNotificationTime = now;

    // Show notification
    _showNotification(
      senderName: senderName ?? 'Someone',
      senderRole: senderRole ?? 'user',
      content: content ?? 'New message',
      conversationId: conversationId,
    );

    // Trigger callback
    _onMessageReceived?.call();
  }

  /// Check if current user is a participant in the conversation
  Future<bool> _isUserInConversation(String? conversationId) async {
    if (conversationId == null || _currentUserId == null) return false;

    try {
      final result = await _supabase
          .from('conversation_participants')
          .select('id')
          .eq('conversation_id', conversationId)
          .eq('user_id', _currentUserId!)
          .eq('is_active', true)
          .maybeSingle();

      return result != null;
    } catch (e) {
      debugPrint('Error checking conversation participation: $e');
      return false;
    }
  }

  /// Show in-app notification
  void _showNotification({
    required String senderName,
    required String senderRole,
    required String content,
    String? conversationId,
  }) {
    if (_context == null || !_context!.mounted) {
      debugPrint(
          '⚠️ [InAppMessageNotification] Context not available, skipping notification');
      return;
    }

    debugPrint(
        '🔔 [InAppMessageNotification] Showing notification from $senderName');

    final roleLabel = _getRoleLabel(senderRole);
    final roleColor = _getRoleColor(senderRole);

    ScaffoldMessenger.of(_context!).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.chat_bubble_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          senderName,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          roleLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    content,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        backgroundColor: roleColor,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            // Navigate to chat - handled by parent
            debugPrint(
                '🔔 [InAppMessageNotification] View tapped for conversation: $conversationId');
          },
        ),
      ),
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'patient':
        return 'PATIENT';
      case 'staff':
        return 'STAFF';
      case 'dentist':
        return 'DENTIST';
      case 'admin':
        return 'ADMIN';
      default:
        return role.toUpperCase();
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'patient':
        return const Color(0xFF0D2A7A); // Blue
      case 'staff':
        return const Color(0xFF00897B); // Teal
      case 'dentist':
        return const Color(0xFF9C27B0); // Purple
      case 'admin':
        return const Color(0xFFFF9800); // Orange
      default:
        return const Color(0xFF424242); // Grey
    }
  }

  /// Dispose the service
  void dispose() {
    debugPrint('🔔 [InAppMessageNotification] Disposing...');
    _messageChannel?.unsubscribe();
    _context = null;
    _onMessageReceived = null;
  }
}
