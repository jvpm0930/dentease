// lib/clinic/logic/resubmit_notify_listener.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ResubmitNotifyListener {
  final String clinicId;
  final FlutterLocalNotificationsPlugin notifier;

  ResubmitNotifyListener({
    required this.clinicId,
    required this.notifier,
  });

  RealtimeChannel? _channel;

  Future<void> _showResubmitNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'clinic_note_channel',
      'Clinic Notes',
      channelDescription: 'Notifications for clinic note & resubmit requests',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    final int id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await notifier.show(
      id,
      'Submission Sent',
      'Resubmit Clinic Detail Application',
      const NotificationDetails(android: androidDetails),
    );
  }

  /// Listen for NOTIFY column changes only, no note/status logic here
  void subscribe() {
    final supabase = Supabase.instance.client;

    _channel = supabase.channel('clinics-notify-$clinicId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'clinics',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'clinic_id',
          value: clinicId,
        ),
        callback: (payload) async {
          final newNotify = (payload.newRecord['notify'] ?? '').toString();
          final oldNotify = (payload.oldRecord['notify'] ?? '').toString();

          if (newNotify.isEmpty || newNotify == oldNotify) return;

          await _showResubmitNotification();
        },
      ).subscribe();
  }

  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
      _channel = null;
    }
  }
}
