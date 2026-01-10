import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin Notification Service for real-time in-app notifications
/// Listens to:
/// 1. New clinic registrations (clinics table)
/// 2. New support messages from dentists (supports table)
class AdminNotificationService {
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;
  RealtimeChannel? _clinicChannel;
  RealtimeChannel? _supportChannel;

  final void Function(
          String title, String body, String type, Map<String, dynamic>? data)?
      onNotification;

  AdminNotificationService({this.onNotification});

  /// Initialize real-time listeners for admin notifications
  void initializeListeners(BuildContext context, String adminId) {
    _initClinicListener(context);
    _initSupportMessageListener(context, adminId);
  }

  /// Listen for new clinic registrations
  void _initClinicListener(BuildContext context) {
    _clinicChannel = supabase
        .channel('admin_clinics')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'clinics',
          callback: (payload) {
            final clinic = payload.newRecord;
            final clinicName = clinic['clinic_name'] ?? 'Unknown Clinic';

            _showInAppNotification(
              context,
              'New Clinic Application',
              '$clinicName has applied for verification',
              'clinic_application',
              {'clinic_id': clinic['clinic_id']},
            );

            onNotification?.call(
              'New Clinic Application',
              '$clinicName has applied for verification',
              'clinic_application',
              {'clinic_id': clinic['clinic_id']},
            );
          },
        )
        .subscribe();
  }

  /// Listen for new support messages to admin
  void _initSupportMessageListener(BuildContext context, String adminId) {
    _supportChannel = supabase
        .channel('admin_supports')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'supports',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: adminId,
          ),
          callback: (payload) async {
            final message = payload.newRecord;
            final senderId = message['sender_id'];

            // Fetch clinic name
            String clinicName = 'Unknown Clinic';
            try {
              final clinicData = await supabase
                  .from('clinics')
                  .select('clinic_name')
                  .eq('clinic_id', senderId)
                  .maybeSingle();

              if (clinicData != null) {
                clinicName = clinicData['clinic_name'] ?? 'Unknown Clinic';
              }
            } catch (e) {
              debugPrint('Error fetching clinic name: $e');
            }

            _showInAppNotification(
              context,
              'New Support Message',
              'Message from $clinicName',
              'support_message',
              {'sender_id': senderId, 'clinic_name': clinicName},
            );

            onNotification?.call(
              'New Support Message',
              'Message from $clinicName',
              'support_message',
              {'sender_id': senderId, 'clinic_name': clinicName},
            );
          },
        )
        .subscribe();
  }

  /// Show in-app SnackBar notification
  void _showInAppNotification(
    BuildContext context,
    String title,
    String body,
    String type,
    Map<String, dynamic>? data,
  ) {
    if (!context.mounted) return;

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
            // Navigation will be handled by the callback
          },
        ),
      ),
    );
  }

  /// Get color based on notification type
  Color _getNotificationColor(String type) {
    switch (type) {
      case 'clinic_application':
        return const Color(0xFFFF9800); // Orange
      case 'support_message':
        return const Color(0xFF0D2A7A); // Blue
      default:
        return const Color(0xFF424242); // Grey
    }
  }

  /// Dispose and cleanup
  void dispose() {
    _clinicChannel?.unsubscribe();
    _supportChannel?.unsubscribe();
  }
}
