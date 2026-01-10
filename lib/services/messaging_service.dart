import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Messaging Service for Real-time Chat
/// Handles conversations, messages, and unread counts using the new schema
class MessagingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================
  // CONVERSATION MANAGEMENT
  // ============================================

  /// Get all conversations for the current user with real-time streaming
  Stream<List<Map<String, dynamic>>> streamUserConversations(String userId) {
    return _supabase
        .from('conversation_participants')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((participants) async {
          if (participants.isEmpty) return <Map<String, dynamic>>[];

          // Get conversation IDs
          final conversationIds = participants
              .where((p) => p['is_active'] == true)
              .map((p) => p['conversation_id'] as String)
              .toList();

          if (conversationIds.isEmpty) return <Map<String, dynamic>>[];

          // Fetch full conversation details
          final conversations = await _supabase
              .from('conversations')
              .select()
              .inFilter('conversation_id', conversationIds)
              .order('last_message_at', ascending: false);

          // Merge with participant data (unread counts, etc.)
          return conversations.map((conv) {
            final participant = participants.firstWhere(
              (p) => p['conversation_id'] == conv['conversation_id'],
              orElse: () => {},
            );
            return {
              ...conv,
              'unread_count': participant['unread_count'] ?? 0,
              'last_read_at': participant['last_read_at'],
            };
          }).toList();
        })
        .asyncMap((future) => future);
  }

  /// Get conversations for a user (one-time fetch)
  Future<List<Map<String, dynamic>>> getUserConversations(String userId) async {
    try {
      // Use the database function for efficient fetching
      final result = await _supabase.rpc(
        'get_user_conversations',
        params: {'p_user_id': userId},
      );
      return List<Map<String, dynamic>>.from(result ?? []);
    } catch (e) {
      debugPrint('Error fetching conversations: $e');
      return [];
    }
  }

  /// Get total unread count for a user
  Future<int> getTotalUnreadCount(String userId) async {
    try {
      final result = await _supabase
          .from('conversation_participants')
          .select('unread_count')
          .eq('user_id', userId)
          .eq('is_active', true);

      return result.fold<int>(
          0, (sum, p) => sum + (p['unread_count'] as int? ?? 0));
    } catch (e) {
      debugPrint('Error fetching unread count: $e');
      return 0;
    }
  }

  /// Stream total unread count for badge display
  Stream<int> streamTotalUnreadCount(String userId) {
    return _supabase
        .from('conversation_participants')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((participants) {
          return participants
              .where((p) => p['is_active'] == true)
              .fold<int>(0, (sum, p) => sum + (p['unread_count'] as int? ?? 0));
        });
  }

  /// Get conversation participants with role info
  Future<List<Map<String, dynamic>>> getConversationParticipants(
    String conversationId,
  ) async {
    try {
      return await _supabase
          .from('conversation_participants')
          .select()
          .eq('conversation_id', conversationId)
          .eq('is_active', true);
    } catch (e) {
      debugPrint('Error fetching participants: $e');
      return [];
    }
  }

  /// Create or get existing direct conversation between two users
  Future<String?> getOrCreateDirectConversation({
    required String user1Id,
    required String user1Role,
    required String user1Name,
    required String user2Id,
    required String user2Role,
    required String user2Name,
    String? clinicId,
  }) async {
    try {
      // Try RPC first
      final result = await _supabase.rpc(
        'create_direct_conversation',
        params: {
          'p_user1_id': user1Id,
          'p_user1_role': user1Role,
          'p_user1_name': user1Name,
          'p_user2_id': user2Id,
          'p_user2_role': user2Role,
          'p_user2_name': user2Name,
          'p_clinic_id': clinicId,
        },
      );
      if (result != null) return result as String;
    } catch (e) {
      debugPrint('RPC failed, using fallback: $e');
    }

    // Fallback: Create conversation directly
    return _createConversationDirectly(
      user1Id: user1Id,
      user1Role: user1Role,
      user1Name: user1Name,
      user2Id: user2Id,
      user2Role: user2Role,
      user2Name: user2Name,
      clinicId: clinicId,
    );
  }

  /// Fallback method to create conversation directly without RPC
  Future<String?> _createConversationDirectly({
    required String user1Id,
    required String user1Role,
    required String user1Name,
    required String user2Id,
    required String user2Role,
    required String user2Name,
    String? clinicId,
  }) async {
    try {
      // Check if conversation already exists between these two users
      final existingParticipant = await _supabase
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', user1Id)
          .limit(100);

      for (final p in existingParticipant) {
        final convId = p['conversation_id'] as String;
        // Check if user2 is also in this conversation
        final otherParticipant = await _supabase
            .from('conversation_participants')
            .select('user_id')
            .eq('conversation_id', convId)
            .eq('user_id', user2Id)
            .maybeSingle();

        if (otherParticipant != null) {
          // Found existing conversation
          return convId;
        }
      }

      // Create new conversation
      final convResult = await _supabase
          .from('conversations')
          .insert({
            'type': 'direct',
            'clinic_id': clinicId,
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'last_message_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single();

      // Handle both possible column names for the primary key
      final conversationId =
          (convResult['conversation_id'] ?? convResult['id']) as String;

      // Add participants
      await _supabase.from('conversation_participants').insert([
        {
          'conversation_id': conversationId,
          'user_id': user1Id,
          'role': user1Role,
          'display_name': user1Name,
          'unread_count': 0,
          'is_active': true,
        },
        {
          'conversation_id': conversationId,
          'user_id': user2Id,
          'role': user2Role,
          'display_name': user2Name,
          'unread_count': 0,
          'is_active': true,
        },
      ]);

      return conversationId;
    } catch (e) {
      debugPrint('Error in fallback conversation creation: $e');
      return null;
    }
  }

  // ============================================
  // MESSAGE MANAGEMENT
  // ============================================

  /// Stream messages for a conversation (real-time)
  Stream<List<Map<String, dynamic>>> streamMessages(String conversationId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['message_id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
  }

  /// Fetch messages for a conversation (one-time)
  Future<List<Map<String, dynamic>>> getMessages(
    String conversationId, {
    int limit = 50,
    String? beforeMessageId,
  }) async {
    try {
      var query = _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .eq('is_deleted', false)
          .order('created_at', ascending: false)
          .limit(limit);

      final result = await query;

      // Return in ascending order for display
      return List<Map<String, dynamic>>.from(result.reversed);
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      return [];
    }
  }

  /// Send a message
  Future<Map<String, dynamic>?> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderRole,
    required String senderName,
    required String content,
    String messageType = 'text',
    String? attachmentUrl,
  }) async {
    try {
      final result = await _supabase
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': senderId,
            'sender_role': senderRole,
            'sender_name': senderName,
            'content': content,
            'message_type': messageType,
            'attachment_url': attachmentUrl,
          })
          .select()
          .single();

      return result;
    } catch (e) {
      debugPrint('Error sending message: $e');
      return null;
    }
  }

  /// Mark conversation as read for a user
  Future<void> markConversationAsRead(
    String conversationId,
    String userId,
  ) async {
    try {
      // Call the RPC function
      await _supabase.rpc(
        'mark_conversation_read',
        params: {
          'p_conversation_id': conversationId,
          'p_user_id': userId,
        },
      );
    } catch (e) {
      // Fallback to direct update if RPC fails
      try {
        await _supabase
            .from('conversation_participants')
            .update({
              'unread_count': 0,
              'last_read_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('conversation_id', conversationId)
            .eq('user_id', userId);
      } catch (e2) {
        debugPrint('Error marking as read: $e2');
      }
    }
  }

  /// Update participant display name in conversation
  Future<void> updateParticipantDisplayName(
    String conversationId,
    String userId,
    String newDisplayName,
  ) async {
    try {
      await _supabase
          .from('conversation_participants')
          .update({'display_name': newDisplayName})
          .eq('conversation_id', conversationId)
          .eq('user_id', userId);

      debugPrint(
          'Updated display name for $userId in conversation $conversationId to: $newDisplayName');
    } catch (e) {
      debugPrint('Error updating participant display name: $e');
    }
  }

  /// Refresh participant display names for a conversation
  /// This helps fix conversations where display names are generic
  Future<void> refreshConversationDisplayNames(String conversationId) async {
    try {
      final participants = await _supabase
          .from('conversation_participants')
          .select('user_id, role, display_name')
          .eq('conversation_id', conversationId);

      for (final participant in participants) {
        final userId = participant['user_id'] as String;
        final role = participant['role'] as String;
        final currentDisplayName = participant['display_name'] as String?;

        // Skip if already has a good display name
        if (currentDisplayName != null &&
            currentDisplayName.isNotEmpty &&
            currentDisplayName != 'Clinic' &&
            currentDisplayName != 'clinic') {
          continue;
        }

        String? newDisplayName;

        // Fetch proper name based on role
        switch (role) {
          case 'dentist':
            final dentistData = await _supabase
                .from('dentists')
                .select('firstname, lastname')
                .eq('dentist_id', userId)
                .maybeSingle();

            if (dentistData != null) {
              final name =
                  '${dentistData['firstname'] ?? ''} ${dentistData['lastname'] ?? ''}'
                      .trim();
              if (name.isNotEmpty) {
                newDisplayName = 'Dr. $name';
              }
            }
            break;

          case 'staff':
            final staffData = await _supabase
                .from('staffs')
                .select('firstname, lastname')
                .eq('staff_id', userId)
                .maybeSingle();

            if (staffData != null) {
              final name =
                  '${staffData['firstname'] ?? ''} ${staffData['lastname'] ?? ''}'
                      .trim();
              if (name.isNotEmpty) {
                newDisplayName = name;
              }
            }
            break;

          case 'patient':
            final patientData = await _supabase
                .from('patients')
                .select('firstname, lastname')
                .eq('patient_id', userId)
                .maybeSingle();

            if (patientData != null) {
              final name =
                  '${patientData['firstname'] ?? ''} ${patientData['lastname'] ?? ''}'
                      .trim();
              if (name.isNotEmpty) {
                newDisplayName = name;
              }
            }
            break;
        }

        // Update if we found a better name
        if (newDisplayName != null) {
          await updateParticipantDisplayName(
              conversationId, userId, newDisplayName);
        }
      }
    } catch (e) {
      debugPrint('Error refreshing conversation display names: $e');
    }
  }

  // ============================================
  // STAFF AVAILABILITY MANAGEMENT
  // ============================================

  /// Get staff availability status
  Future<bool> getStaffOnLeaveStatus(String staffId) async {
    try {
      final result = await _supabase
          .from('staffs')
          .select('is_on_leave')
          .eq('staff_id', staffId)
          .single();
      return result['is_on_leave'] as bool? ?? false;
    } catch (e) {
      debugPrint('Error fetching staff status: $e');
      return false;
    }
  }

  /// Update staff availability status
  Future<bool> setStaffOnLeaveStatus(String staffId, bool isOnLeave) async {
    try {
      await _supabase
          .from('staffs')
          .update({'is_on_leave': isOnLeave}).eq('staff_id', staffId);
      return true;
    } catch (e) {
      debugPrint('Error updating staff status: $e');
      return false;
    }
  }

  /// Get all staff with their leave status for a clinic
  Future<List<Map<String, dynamic>>> getClinicStaffWithStatus(
    String clinicId,
  ) async {
    try {
      return await _supabase
          .from('staffs')
          .select('staff_id, firstname, lastname, role, is_on_leave')
          .eq('clinic_id', clinicId);
    } catch (e) {
      debugPrint('Error fetching clinic staff: $e');
      return [];
    }
  }

  // ============================================
  // DENTIST-SPECIFIC: VIEW STAFF CONVERSATIONS
  // ============================================

  /// Get all conversations involving staff from a clinic (for dentist oversight)
  Future<List<Map<String, dynamic>>> getClinicConversations(
    String clinicId,
  ) async {
    try {
      // Get all conversations linked to this clinic
      final conversations = await _supabase
          .from('conversations')
          .select('''
            *,
            conversation_participants (
              user_id,
              role,
              display_name,
              unread_count
            )
          ''')
          .eq('clinic_id', clinicId)
          .order('last_message_at', ascending: false);

      return List<Map<String, dynamic>>.from(conversations);
    } catch (e) {
      debugPrint('Error fetching clinic conversations: $e');
      return [];
    }
  }

  /// Check if a conversation has unanswered patient messages
  /// (Last message was from a patient)
  Future<bool> hasUnansweredPatientMessage(String conversationId) async {
    try {
      final lastMessage = await _supabase
          .from('messages')
          .select('sender_role')
          .eq('conversation_id', conversationId)
          .eq('is_deleted', false)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return lastMessage?['sender_role'] == 'patient';
    } catch (e) {
      debugPrint('Error checking unanswered status: $e');
      return false;
    }
  }

  /// Get conversations grouped by status for dentist view
  Future<Map<String, List<Map<String, dynamic>>>>
      getConversationsGroupedByStatus(
    String clinicId,
    String dentistId,
  ) async {
    try {
      final conversations = await getClinicConversations(clinicId);

      final Map<String, List<Map<String, dynamic>>> grouped = {
        'unanswered': [],
        'handled_by_staff': [],
        'my_conversations': [],
      };

      for (final conv in conversations) {
        final participants = conv['conversation_participants'] as List? ?? [];
        final hasPatient = participants.any((p) => p['role'] == 'patient');
        final hasStaff = participants.any((p) => p['role'] == 'staff');
        final hasDentist = participants.any((p) => p['user_id'] == dentistId);

        // Check last message sender
        final lastMessageRole =
            await _getLastMessageRole(conv['conversation_id']);

        if (hasDentist) {
          grouped['my_conversations']!.add(conv);
        } else if (hasPatient && lastMessageRole == 'patient') {
          grouped['unanswered']!.add(conv);
        } else if (hasStaff) {
          grouped['handled_by_staff']!.add(conv);
        }
      }

      return grouped;
    } catch (e) {
      debugPrint('Error grouping conversations: $e');
      return {'unanswered': [], 'handled_by_staff': [], 'my_conversations': []};
    }
  }

  Future<String?> _getLastMessageRole(String conversationId) async {
    try {
      final result = await _supabase
          .from('messages')
          .select('sender_role')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return result?['sender_role'];
    } catch (e) {
      return null;
    }
  }
}
