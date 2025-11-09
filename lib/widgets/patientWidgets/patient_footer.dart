import 'dart:async';
import 'package:dentease/clinic/models/patient_clinicchat_list.dart';
import 'package:dentease/clinic/scanner/imangeScanner.dart';
import 'package:dentease/patients/patient_booking_pend.dart';
import 'package:dentease/patients/patient_pagev2.dart';
import 'package:dentease/patients/patient_profile.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 🟢 Added

// Initialize notifications
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
    channelDescription:
        'Notifications for new chat messages or booking updates',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
  );

  const NotificationDetails platformDetails =
      NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000, // unique ID
    title,
    body,
    platformDetails,
  );
}

class PatientFooter extends StatefulWidget {
  final String patientId;

  const PatientFooter({super.key, required this.patientId});

  @override
  State<PatientFooter> createState() => _PatientFooterState();
}

class _PatientFooterState extends State<PatientFooter> {
  final supabase = Supabase.instance.client;
  bool hasUnreadMessages = false;
  bool hasApprovedBookings = false;
  Timer? refreshTimer;

  Set<String> notifiedMessageIds = {};
  Set<String> notifiedApprovedBookingIds = {};

  @override
  void initState() {
    super.initState();
    initNotifications();
    _loadNotifiedIds(); // 🟢 Load saved IDs on startup
    fetchUnreadMessages();
    fetchApprovedBookings();
    startAutoRefresh();
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }

  //  Save IDs persistently
  Future<void> _saveNotifiedIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'notifiedMessageIds', notifiedMessageIds.toList());
    await prefs.setStringList(
        'notifiedApprovedBookingIds', notifiedApprovedBookingIds.toList());
  }

  //  Load saved IDs persistently
  Future<void> _loadNotifiedIds() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      notifiedMessageIds =
          prefs.getStringList('notifiedMessageIds')?.toSet() ?? {};
      notifiedApprovedBookingIds =
          prefs.getStringList('notifiedApprovedBookingIds')?.toSet() ?? {};
    });
  }

  void startAutoRefresh() {
    refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await fetchUnreadMessages();
      await fetchApprovedBookings();
    });
  }

  void stopAutoRefresh() {
    refreshTimer?.cancel();
    refreshTimer = null;
  }

  /// FETCH UNREAD MESSAGES
  Future<void> fetchUnreadMessages() async {
    try {
      final response = await supabase
          .from('messages')
          .select('message_id, message, sender_id')
          .eq('receiver_id', widget.patientId)
          .or('is_read.eq.false,is_read.eq.FALSE,is_read.is.null')
          .order('timestamp', ascending: true);

      if (response.isEmpty) {
        if (mounted) setState(() => hasUnreadMessages = false);
        return;
      }

      if (mounted) setState(() => hasUnreadMessages = true);

      for (var msg in response) {
        final messageId = msg['message_id'].toString();
        if (!notifiedMessageIds.contains(messageId)) {
          notifiedMessageIds.add(messageId);
          await _saveNotifiedIds(); // Save updates

          final clinicData = await supabase
              .from('clinics')
              .select('clinic_name')
              .eq('clinic_id', msg['sender_id'])
              .maybeSingle();

          final clinicName = clinicData?['clinic_name'] ?? 'Clinic';

          await showLocalNotification(
            'New message from $clinicName',
            msg['message'] ?? 'Sent you a message',
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching unread messages');
    }
  }

  ///  FETCH APPROVED BOOKINGS
  Future<void> fetchApprovedBookings() async {
    try {
      final response = await supabase
          .from('bookings')
          .select('booking_id, clinic_id, status')
          .eq('patient_id', widget.patientId)
          .eq('status', 'approved');

      if (response.isNotEmpty) {
        if (mounted) setState(() => hasApprovedBookings = true);
      } else {
        if (mounted) setState(() => hasApprovedBookings = false);
      }

      for (var booking in response) {
        final bookingId = booking['booking_id'].toString();
        if (!notifiedApprovedBookingIds.contains(bookingId)) {
          notifiedApprovedBookingIds.add(bookingId);
          await _saveNotifiedIds(); // Save updates

          final clinicData = await supabase
              .from('clinics')
              .select('clinic_name')
              .eq('clinic_id', booking['clinic_id'])
              .maybeSingle();

          final clinicName = clinicData?['clinic_name'] ?? 'Your Clinic';

          await showLocalNotification(
            'Booking Approved!',
            'Your booking has been approved by $clinicName.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching approved bookings');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 20,
          right: 20,
          bottom: 30,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF103D7E), // solid blue (#103D7E)
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavImage(
                    'assets/icons/home.png', context, const PatientPage()),

                // Booking icon with red dot if approved
                IconButton(
                  iconSize: 35,
                  icon: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/icons/calendar.png',
                        width: 32,
                        height: 32,
                        color: Colors.white,
                      ),
                      if (hasApprovedBookings)
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
                        builder: (_) =>
                            PatientBookingPend(patientId: widget.patientId),
                      ),
                    );
                  },
                ),

                _buildNavImage('assets/icons/scan.png', context,
                    const ImageClassifierScreen()),

                // Chat icon with unread indicator
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
                        builder: (_) =>
                            PatientClinicChatList(patientId: widget.patientId),
                      ),
                    );
                  },
                ),

                _buildNavImage('assets/icons/profile.png', context,
                    PatientProfile(patientId: widget.patientId)),
              ],
            ),
          ),
        ),
      ],
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
