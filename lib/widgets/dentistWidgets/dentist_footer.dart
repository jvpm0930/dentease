import 'package:dentease/clinic/models/clinicChat_support.dart';
import 'package:dentease/dentist/dentist_bookings_pend.dart';
import 'package:dentease/dentist/dentist_profile.dart';
import 'package:dentease/dentist/dentist_page.dart';
import 'package:dentease/clinic/models/clinic_patientchat_list.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
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

class DentistFooter extends StatefulWidget {
  final String dentistId;
  final String clinicId;

  const DentistFooter(
      {super.key, required this.dentistId, required this.clinicId});

  @override
  _DentistFooterState createState() => _DentistFooterState();
}

class _DentistFooterState extends State<DentistFooter> {
  final supabase = Supabase.instance.client;
  bool hasUnreadMessages = false;
  Timer? refreshTimer;
  String? lastNotifiedMessageId;
  String? patientId;

  @override
  void initState() {
    super.initState();
    fetchPatientId();
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
          .eq('receiver_id', widget.clinicId)
          .or('is_read.eq.false,is_read.eq.FALSE,is_read.is.null')
          .order('timestamp');

      if (response.isNotEmpty) {
        setState(() => hasUnreadMessages = true);

        // Get the latest unread message
        final latestUnread = response.last;

        // Only trigger a notification for new messages
        if (latestUnread['message_id'] != lastNotifiedMessageId) {
          lastNotifiedMessageId = latestUnread['message_id'].toString();

          // Fetch patient name (optional)
          final patientData = await supabase
              .from('patients')
              .select('lastname')
              .eq('patient_id', latestUnread['sender_id'])
              .maybeSingle();

          final patientName = patientData?['lastname'] ?? 'Patient';

          await showLocalNotification(
            'New message from $patientName',
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

  /// Fetch patientId from bookings where clinicId matches
  Future<void> fetchPatientId() async {
    final response = await supabase
        .from('bookings')
        .select('patient_id')
        .eq('clinic_id', widget.clinicId)
        .maybeSingle(); // Fetch a single patient (modify as needed)

    if (response != null && response['patient_id'] != null) {
      setState(() {
        patientId = response['patient_id'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 20,
      right: 20,
      bottom: 30,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavImage(
                'assets/icons/home.png',
                context,
                DentistPage(
                    clinicId: widget.clinicId, dentistId: widget.dentistId)),
            _buildNavImage('assets/icons/calendar.png', context,
                DentistBookingPendPage(clinicId: widget.clinicId, dentistId: widget.dentistId)),
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
                        ClinicPatientChatList(clinicId: widget.clinicId),
                  ),
                );
              },
            ),
            _buildNavImage(
                'assets/icons/customer-service.png', context, ClinicChatPageforAdmin(clinicId: widget.clinicId, adminId: 'eee5f574-903b-4575-a9d9-2f69e58f1801')),
            _buildNavImage('assets/icons/profile.png', context,
                DentistProfile(dentistId: widget.dentistId)),
          ],
        ),
      ),
    );
  }

  /// Builds a navigation button with an image
  Widget _buildNavImage(String imagePath, BuildContext context, Widget? page) {
    return IconButton(
      icon: Image.asset(
        imagePath,
        width: 30,
        height: 30,
        color: Colors.white,
      ),
      onPressed: page != null
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => page),
              );
            }
          : null, // Disable button if page is null
    );
  }

}
