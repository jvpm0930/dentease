import 'dart:async';
import 'package:dentease/clinic/models/patient_clinicchat_list.dart';
import 'package:dentease/clinic/scanner/imangeScanner.dart';
import 'package:dentease/patients/patient_booking_pend.dart';
import 'package:dentease/patients/patient_pagev2.dart';
import 'package:dentease/patients/patient_profile.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
    channelDescription: 'Notifications for new chat messages',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
  );

  const NotificationDetails platformDetails =
      NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000, // unique id
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
  Timer? refreshTimer;
  String? lastNotifiedMessageId;

  @override
  void initState() {
    super.initState();
    initNotifications();
    fetchUnreadMessages();
    startAutoRefresh();
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }

  void startAutoRefresh() {
    refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      fetchUnreadMessages();
    });
  }

  void stopAutoRefresh() {
    refreshTimer?.cancel();
    refreshTimer = null;
  }

  Future<void> fetchUnreadMessages() async {
    try {
      // Get all unread messages (clinic → patient)
      final response = await supabase
          .from('messages')
          .select('message_id, message, sender_id')
          .eq('receiver_id', widget.patientId)
          .or('is_read.eq.false,is_read.eq.FALSE,is_read.is.null')
          .order('timestamp');

      if (response.isNotEmpty) {
        setState(() => hasUnreadMessages = true);

        // Get the latest unread message
        final latestUnread = response.last;

        // Only trigger a notification for new messages
        if (latestUnread['message_id'] != lastNotifiedMessageId) {
          lastNotifiedMessageId = latestUnread['message_id'].toString();

          // Fetch clinic name (optional)
          final clinicData = await supabase
              .from('clinics')
              .select('clinic_name')
              .eq('clinic_id', latestUnread['sender_id'])
              .maybeSingle();

          final clinicName = clinicData?['clinic_name'] ?? 'Clinic';

          await showLocalNotification(
            'New message from $clinicName',
            latestUnread['message'] ?? '',
          );
        }
      } else {
        setState(() => hasUnreadMessages = false);
      }
    } catch (e) {
      debugPrint('Error fetching unread messages: $e');
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
              color: Colors.blue,
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
                _buildNavImage('assets/icons/calendar.png', context,
                    PatientBookingPend(patientId: widget.patientId)),
                _buildNavImage('assets/icons/scan.png', context,
                    const ImageClassifierScreen()),

                // Custom Chat Icon with unread indicator
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
