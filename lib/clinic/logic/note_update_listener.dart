// lib/clinic/logic/note_update_listener.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NoteUpdateListener {
  final String clinicId;
  final FlutterLocalNotificationsPlugin notifier;

  NoteUpdateListener({
    required this.clinicId,
    required this.notifier,
  });

  SharedPreferences? _prefs;
  String _lastNotifiedNote = '';
  RealtimeChannel? _channel;

  String get _prefKeyLastNote => 'clinic_${clinicId}_last_note';

  /// Call once from DentClinicPage.initState()
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _lastNotifiedNote = _prefs!.getString(_prefKeyLastNote) ?? '';
  }

  Future<void> _saveLastNote(String note) async {
    _lastNotifiedNote = note;
    await _prefs?.setString(_prefKeyLastNote, note);
  }

  Future<void> _showNoteNotification(String body) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'clinic_note_channel',
      'Clinic Notes',
      channelDescription: 'Notifications for clinic note updates',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    final int id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await notifier.show(
      id,
      'Clinic Application Note Updated',
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  /// Listen for NOTE changes & call [onNoteChanged] + local notif
  void subscribe(void Function(String note) onNoteChanged) {
    final supabase = Supabase.instance.client;

    _channel = supabase.channel('clinics-note-$clinicId')
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
          final newNote = (payload.newRecord['note'] ?? '').toString();
          final oldNote = (payload.oldRecord['note'] ?? '').toString();

          if (newNote == oldNote) return;

          // Avoid empty spam
          if (newNote.isEmpty) {
            onNoteChanged(newNote);
            return;
          }

          // Only notify if really new for this device
          if (newNote != _lastNotifiedNote) {
            final preview = newNote.length > 80
                ? '${newNote.substring(0, 80)}...'
                : newNote;

            await _showNoteNotification(preview);
            await _saveLastNote(newNote);
          }

          onNoteChanged(newNote);
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
