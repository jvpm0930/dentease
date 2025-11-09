import 'package:dentease/clinic/models/clinicChat_support.dart';
import 'package:dentease/dentist/dentist_bookings_pend.dart';
import 'package:dentease/dentist/dentist_profile.dart';
import 'package:dentease/dentist/dentist_page.dart';
import 'package:dentease/clinic/models/clinic_patientchat_list.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';


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
    channelDescription: 'Notifications for new chat messages and bookings',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    groupKey: 'dentease_notifications',
  );

  const NotificationDetails platformDetails =
      NotificationDetails(android: androidDetails);

  // Generate a truly unique ID so multiple notifications appear together
  final int uniqueId = Random().nextInt(1 << 31);

  await flutterLocalNotificationsPlugin.show(
    uniqueId, //  different each time
    title,
    body,
    platformDetails,
  );
}


class DentistFooter extends StatefulWidget {
  final String dentistId;
  final String clinicId;

  const DentistFooter({
    super.key,
    required this.dentistId,
    required this.clinicId,
  });

  @override
  _DentistFooterState createState() => _DentistFooterState();
}

class _DentistFooterState extends State<DentistFooter> {
  final supabase = Supabase.instance.client;

  bool hasUnreadMessages = false;
  bool hasNewBookings = false;
  Timer? refreshTimer;

  String? lastNotifiedMessageId;
  String? lastNotifiedBookingId;

  final Set<String> notifiedBookingIds = {};
  final Set<String> notifiedMessageIds = {};


  @override
  void initState() {
    super.initState();
    initNotifications();
    fetchUnreadMessages();
    loadNotifiedIds();
    notifiedMessageIds.clear();
    notifiedBookingIds.clear();
    fetchNewBookings();
    startAutoRefresh();
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }

  void startAutoRefresh() {
    refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      fetchUnreadMessages();
      fetchNewBookings();
    });
  }

  void stopAutoRefresh() {
    refreshTimer?.cancel();
    refreshTimer = null;
  }

  Future<void> loadNotifiedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final notifiedBookings = prefs.getStringList('notifiedBookingIds') ?? [];
    final notifiedMessages = prefs.getStringList('notifiedMessageIds') ?? [];

    setState(() {
      notifiedBookingIds.addAll(notifiedBookings);
      notifiedMessageIds.addAll(notifiedMessages);
    });
  }

  Future<void> saveNotifiedIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'notifiedBookingIds', notifiedBookingIds.toList());
    await prefs.setStringList(
        'notifiedMessageIds', notifiedMessageIds.toList());
  }

  Future<void> fetchUnreadMessages() async {
    try {
      final response = await supabase
          .from('messages')
          .select('message_id, message, sender_id')
          .eq('receiver_id', widget.clinicId)
          .or('is_read.eq.false,is_read.eq.FALSE,is_read.is.null')
          .order('timestamp', ascending: true);

      if (response.isNotEmpty) {
        setState(() => hasUnreadMessages = true);

        // 🔹 Load saved notified message IDs (persistent)
        final prefs = await SharedPreferences.getInstance();
        final savedIds = prefs.getStringList('notifiedMessageIds') ?? [];
        final notifiedMessageIds = savedIds.toSet();

        for (var msg in response) {
          final messageId = msg['message_id'].toString();

          // Only notify if not already notified
          if (!notifiedMessageIds.contains(messageId)) {
            notifiedMessageIds.add(messageId);

            // Save updated set persistently
            await prefs.setStringList(
                'notifiedMessageIds', notifiedMessageIds.toList());

            // Fetch sender (patient) name
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
      debugPrint('Error fetching unread messages');
    }
  }


  // Check for new pending bookings
  Future<void> fetchNewBookings() async {
    try {
      final response = await supabase
          .from('bookings')
          .select('booking_id, patient_id, date, status')
          .eq('clinic_id', widget.clinicId)
          .eq('status', 'pending')
          .order('date', ascending: false);

      if (response.isNotEmpty) {
        setState(() => hasNewBookings = true);

        for (var booking in response) {
          final bookingId = booking['booking_id'].toString();

          if (!notifiedBookingIds.contains(bookingId)) {
            notifiedBookingIds.add(bookingId);
            await saveNotifiedIds();

            // Get patient name
            final patientData = await supabase
                .from('patients')
                .select('firstname, lastname')
                .eq('patient_id', booking['patient_id'])
                .maybeSingle();

            final patientName =
                '${patientData?['firstname'] ?? ''} ${patientData?['lastname'] ?? ''}'
                    .trim();

            final bookingDate = booking['date'] ?? 'Unknown date';

            await showLocalNotification(
              'New Pending Booking',
              'From $patientName on $bookingDate',
            );
          }
        }
      } else {
        setState(() => hasNewBookings = false);
      }
    } catch (e) {
      debugPrint('Error fetching pending bookings');
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
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavImage(
              'assets/icons/home.png',
              context,
              DentistPage(
                  clinicId: widget.clinicId, dentistId: widget.dentistId),
            ),

            //  Calendar icon with red dot if pending bookings exist
            Stack(
              alignment: Alignment.center,
              children: [
                _buildNavImage(
                  'assets/icons/calendar.png',
                  context,
                  DentistBookingPendPage(
                    clinicId: widget.clinicId,
                    dentistId: widget.dentistId,
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

            // Chat icon with unread badge
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
              'assets/icons/customer-service.png',
              context,
              ClinicChatPageforAdmin(
                clinicId: widget.clinicId,
                adminId: 'eee5f574-903b-4575-a9d9-2f69e58f1801',
              ),
            ),
            _buildNavImage(
              'assets/icons/profile.png',
              context,
              DentistProfile(dentistId: widget.dentistId),
            ),
          ],
        ),
      ),
    );
  }

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
              Navigator.push(context, MaterialPageRoute(builder: (_) => page));
            }
          : null,
    );
  }
}
