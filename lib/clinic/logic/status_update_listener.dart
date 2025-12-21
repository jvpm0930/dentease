// lib/clinic/logic/status_update_listener.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StatusUpdateListener {
  final String clinicId;
  final FlutterLocalNotificationsPlugin notifier;

  StatusUpdateListener({
    required this.clinicId,
    required this.notifier,
  });

  SharedPreferences? _prefs;
  String _lastNotifiedStatus = '';
  RealtimeChannel? _channel;

  String get _prefKeyLastStatus => 'clinic_${clinicId}_last_status';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _lastNotifiedStatus = _prefs!.getString(_prefKeyLastStatus) ?? '';
  }

  Future<void> _saveLastStatus(String status) async {
    _lastNotifiedStatus = status;
    await _prefs?.setString(_prefKeyLastStatus, status);
  }

  Future<void> _showStatusNotification(String status) async {
    String body = switch (status.toLowerCase()) {
      'approved' => '🎉 Your clinic has been APPROVED!',
      'pending' => '⏳ Your clinic application is currently under review.',
      'rejected' =>
        '⚠ Your clinic was rejected. Please review the note for details.',
      _ => 'Status updated → $status',
    };

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'clinic_note_channel',
      'Clinic Notes',
      channelDescription: 'Notifications for clinic note & status updates',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    final int id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await notifier.show(
      id,
      'Application Status Update',
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  /// Listen for STATUS changes & call [onStatusChanged] + local notif
  void subscribe(void Function(String status) onStatusChanged) {
    final supabase = Supabase.instance.client;

    _channel = supabase.channel('clinics-status-$clinicId')
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
          final newStatus = (payload.newRecord['status'] ?? '').toString();
          final oldStatus = (payload.oldRecord['status'] ?? '').toString();

          if (newStatus == oldStatus) return;

          if (newStatus.isNotEmpty && newStatus != _lastNotifiedStatus) {
            await _showStatusNotification(newStatus);
            await _saveLastStatus(newStatus);
          }

          onStatusChanged(newStatus);
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
