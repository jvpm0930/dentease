import 'dart:async';
import 'dart:math';

import 'package:dentease/clinic/models/clinicChat_support.dart';
import 'package:dentease/clinic/models/clinic_patientchat_list.dart';
import 'package:dentease/dentist/dentist_bookings_pend.dart';
import 'package:dentease/staff/staff_profile.dart';
import 'package:dentease/staff/staff_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings =
      InitializationSettings(android: androidInit);

  await flutterLocalNotificationsPlugin.initialize(initSettings);
}

Future<void> showLocalNotification(String title, String body) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'chat_channel',
    'Chat Notifications',
    channelDescription: 'Notifications for new chat messages and bookings',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    groupKey: 'dentease_notifications',
  );

  const NotificationDetails platformDetails =
      NotificationDetails(android: androidDetails);

  // Unique ID so notifications don't overwrite each other
  final int uniqueId = Random().nextInt(1 << 31);

  await flutterLocalNotificationsPlugin.show(
    uniqueId,
    title,
    body,
    platformDetails,
  );
}

// ================= Staff Footer =================

class StaffFooter extends StatefulWidget {
  final String staffId;
  final String clinicId;

  const StaffFooter({
    super.key,
    required this.staffId,
    required this.clinicId,
  });

  @override
  _StaffFooterState createState() => _StaffFooterState();
}

class _StaffFooterState extends State<StaffFooter> {
  final supabase = Supabase.instance.client;

  // UI badges
  bool hasUnreadMessages = false;
  bool hasNewBookings = false;
  bool hasNewSupports = false;

  // Polling
  Timer? refreshTimer;

  // Persistence for notified IDs (avoid duplicate notifications)
  final Set<String> notifiedBookingIds = {};
  final Set<String> notifiedMessageIds = {};
  final Set<String> notifiedSupportIds = {};

  @override
  void initState() {
    super.initState();
    initNotifications();
    _loadNotifiedIds();

    // Initial fetch
    _fetchUnreadMessages();
    _fetchNewBookings();
    _fetchNewSupports();

    // Poll every 3 seconds (same as dentist footer)
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    super.dispose();
  }

  void _startAutoRefresh() {
    refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchUnreadMessages();
      _fetchNewBookings();
      _fetchNewSupports();
    });
  }

  void _stopAutoRefresh() {
    refreshTimer?.cancel();
    refreshTimer = null;
  }

  Future<void> _loadNotifiedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBookings = prefs.getStringList('notifiedBookingIds') ?? [];
    final savedMessages = prefs.getStringList('notifiedMessageIds') ?? [];
    final savedSupports = prefs.getStringList('notifiedSupportIds') ?? [];

    setState(() {
      notifiedBookingIds.addAll(savedBookings);
      notifiedMessageIds.addAll(savedMessages);
      notifiedSupportIds.addAll(savedSupports);
    });
  }

  Future<void> _saveNotifiedIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'notifiedBookingIds', notifiedBookingIds.toList());
    await prefs.setStringList(
        'notifiedMessageIds', notifiedMessageIds.toList());
    await prefs.setStringList(
        'notifiedSupportIds', notifiedSupportIds.toList());
  }

  // ====== Data Fetchers (mirror dentist footer) ======

  Future<void> _fetchNewSupports() async {
    try {
      final response = await supabase
          .from('supports')
          .select('support_id, message, sender_id')
          .eq('receiver_id', widget.clinicId)
          .or('is_read.eq.false,is_read.eq.FALSE,is_read.is.null')
          .order('timestamp', ascending: true);

      if (response.isNotEmpty) {
        setState(() => hasNewSupports = true);

        // Persisted notified IDs
        final prefs = await SharedPreferences.getInstance();
        final savedIds = prefs.getStringList('notifiedSupportIds') ?? [];
        final localNotified = savedIds.toSet();

        for (final msg in response) {
          final supportId = msg['support_id'].toString();
          if (!localNotified.contains(supportId)) {
            localNotified.add(supportId);
            await prefs.setStringList(
                'notifiedSupportIds', localNotified.toList());

            await showLocalNotification(
              'New message from Support',
              msg['message'] ?? 'Sent you a message',
            );
          }
        }
      } else {
        setState(() => hasNewSupports = false);
      }
    } catch (e) {
      debugPrint('Error fetching supports: $e');
    }
  }

  Future<void> _fetchUnreadMessages() async {
    try {
      final response = await supabase
          .from('messages')
          .select('message_id, message, sender_id')
          .eq('receiver_id', widget.clinicId)
          .or('is_read.eq.false,is_read.eq.FALSE,is_read.is.null')
          .order('timestamp', ascending: true);

      if (response.isNotEmpty) {
        setState(() => hasUnreadMessages = true);

        final prefs = await SharedPreferences.getInstance();
        final savedIds = prefs.getStringList('notifiedMessageIds') ?? [];
        final localNotified = savedIds.toSet();

        for (final msg in response) {
          final messageId = msg['message_id'].toString();

          if (!localNotified.contains(messageId)) {
            localNotified.add(messageId);
            await prefs.setStringList(
                'notifiedMessageIds', localNotified.toList());

            // Fetch patient name
            final patientData = await supabase
                .from('patients')
                .select('firstname, lastname')
                .eq('patient_id', msg['sender_id'])
                .maybeSingle();

            final patientName =
                '${patientData?['firstname'] ?? ''} ${patientData?['lastname'] ?? ''}'
                    .trim();

            await showLocalNotification(
              'New message from $patientName',
              msg['message'] ?? 'Sent you a message',
            );
          }
        }
      } else {
        setState(() => hasUnreadMessages = false);
      }
    } catch (e) {
      debugPrint('Error fetching unread messages: $e');
    }
  }

  Future<void> _fetchNewBookings() async {
    try {
      final response = await supabase
          .from('bookings')
          .select('booking_id, patient_id, date, status')
          .eq('clinic_id', widget.clinicId)
          .eq('status', 'pending')
          .order('date', ascending: false);

      if (response.isNotEmpty) {
        setState(() => hasNewBookings = true);

        for (final booking in response) {
          final bookingId = booking['booking_id'].toString();

          if (!notifiedBookingIds.contains(bookingId)) {
            notifiedBookingIds.add(bookingId);
            await _saveNotifiedIds();

            // Get patient name
            final patientData = await supabase
                .from('patients')
                .select('firstname, lastname')
                .eq('patient_id', booking['patient_id'])
                .maybeSingle();

            final patientName =
                '${patientData?['firstname'] ?? ''} ${patientData?['lastname'] ?? ''}'
                    .trim();

            await showLocalNotification(
              'New Pending Booking',
              'From $patientName',
            );
          }
        }
      } else {
        setState(() => hasNewBookings = false);
      }
    } catch (e) {
      debugPrint('Error fetching pending bookings: $e');
    }
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 20,
      right: 20,
      bottom: 30,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF103D7E), // same solid blue as dentist
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              spreadRadius: 2,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavImage(
              'assets/icons/home.png',
              context,
              StaffPage(clinicId: widget.clinicId, staffId: widget.staffId),
            ),

            // Calendar icon with red dot if pending bookings exist
            Stack(
              alignment: Alignment.center,
              children: [
                _buildNavImage(
                  'assets/icons/calendar.png',
                  context,
                  DentistBookingPendPage(
                    clinicId: widget.clinicId,
                  ),
                ),
                if (hasNewBookings)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),

            // Chat with unread badge
            IconButton(
              iconSize: 35,
              icon: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    'assets/icons/chat.png',
                    width: 32,
                    height: 32,
                    color: Colors.white,
                  ),
                  if (hasUnreadMessages)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClinicPatientChatList(
                      clinicId: widget.clinicId,
                    ),
                  ),
                );
              },
            ),

            // Support with badge
            IconButton(
              iconSize: 35,
              icon: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    'assets/icons/customer-service.png',
                    width: 32,
                    height: 32,
                    color: Colors.white,
                  ),
                  if (hasNewSupports)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClinicChatPageforAdmin(
                      clinicId: widget.clinicId,
                      adminId: 'eee5f574-903b-4575-a9d9-2f69e58f1801',
                    ),
                  ),
                );
              },
            ),

            _buildNavImage(
              'assets/icons/profile.png',
              context,
              StaffProfile(staffId: widget.staffId),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavImage(String imagePath, BuildContext context, Widget page) {
    return IconButton(
      icon: Image.asset(
        imagePath,
        width: 30,
        height: 30,
        color: Colors.white,
      ),
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
    );
  }
}
