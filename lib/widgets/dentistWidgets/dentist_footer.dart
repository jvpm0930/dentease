import 'package:dentease/chat/chat_screen.dart';
import 'package:dentease/services/messaging_service.dart';
import 'package:dentease/dentist/dentist_bookings_pend.dart';
import 'package:dentease/dentist/dentist_profile.dart';
import 'package:dentease/dentist/dentist_main_layout.dart';
import 'package:dentease/dentist/chat/dentist_chat_hub.dart';
import 'package:dentease/theme/app_theme.dart';

import 'package:dentease/logic/safe_navigator.dart';
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
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;

  bool hasUnreadMessages = false;
  bool hasNewBookings = false;
  bool hasNewSupports = false;

  final MessagingService _messagingService = MessagingService();
  StreamSubscription? _unreadSubscription;
  Timer? refreshTimer;

  String? lastNotifiedMessageId;
  String? lastNotifiedBookingId;
  String? lastNotifiedSupportId;

  final Set<String> notifiedBookingIds = {};
  final Set<String> notifiedMessageIds = {};
  final Set<String> notifiedSupportIds = {};

  @override
  void initState() {
    super.initState();
    initNotifications();
    loadNotifiedIds();

    // Use Stream for chat badges
    _unreadSubscription = _messagingService
        .streamTotalUnreadCount(widget.clinicId)
        .listen((count) {
      if (mounted) {
        setState(() {
          hasUnreadMessages = count > 0;
        });
      }
    });

    fetchNewBookings();
    startAutoRefresh();
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }

  void startAutoRefresh() {
    refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
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
    final notifiedSupports = prefs.getStringList('notifiedSupportIds') ?? [];

    setState(() {
      notifiedBookingIds.addAll(notifiedBookings);
      notifiedMessageIds.addAll(notifiedMessages);
      notifiedSupportIds.addAll(notifiedSupports);
    });
  }

  Future<void> saveNotifiedIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'notifiedBookingIds', notifiedBookingIds.toList());
    await prefs.setStringList(
        'notifiedMessageIds', notifiedMessageIds.toList());
    await prefs.setStringList(
        'notifiedSupportIds', notifiedSupportIds.toList());
  }

  Future<void> fetchNewSupports() async {
    try {
      final response = await supabase
          .from('supports')
          .select('support_id, message, sender_id')
          .eq('receiver_id', widget.clinicId)
          .eq('is_read', false)
          .order('timestamp', ascending: true);

      if (response.isNotEmpty) {
        setState(() => hasNewSupports = true);
        final prefs = await SharedPreferences.getInstance();
        final savedIds = prefs.getStringList('notifiedSupportIds') ?? [];
        final notifiedSupportIds = savedIds.toSet();

        for (var msg in response) {
          final supportId = msg['support_id'].toString();
          if (!notifiedSupportIds.contains(supportId)) {
            notifiedSupportIds.add(supportId);
            await prefs.setStringList(
                'notifiedSupportIds', notifiedSupportIds.toList());
            await showLocalNotification('New message from Support',
                msg['message'] ?? 'Sent you a message');
          }
        }
      } else {
        setState(() => hasNewSupports = false);
      }
    } catch (e) {
      debugPrint('Error fetching support dots: $e');
    }
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
          color: AppTheme.primaryBlue, // solid blue (#103D7E)
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
            // Home button - uses pushAndRemoveUntil to clear stack
            _buildHomeButton(
              'assets/icons/home.png',
              context,
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
                SafeNavigator.push(
                  context,
                  DentistChatHub(clinicId: widget.clinicId),
                );
              },
            ),
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
              onPressed: () async {
                // Fetch first admin ID
                final adminRes = await supabase
                    .from('profiles')
                    .select('id')
                    .eq('role', 'admin')
                    .limit(1)
                    .maybeSingle();
                if (adminRes == null) return;
                final adminId = adminRes['id'] as String;

                // Get or Create Convo
                final convoId =
                    await _messagingService.getOrCreateDirectConversation(
                  user1Id: widget.clinicId,
                  user1Role: 'dentist',
                  user1Name: 'Clinic',
                  user2Id: adminId,
                  user2Role: 'admin',
                  user2Name: 'Admin Support',
                  clinicId: widget.clinicId,
                );

                if (convoId != null && mounted) {
                  SafeNavigator.push(
                    context,
                    ChatScreen(
                      conversationId: convoId,
                      userId: widget.clinicId,
                      userRole: 'dentist',
                      userName: 'Clinic',
                      otherUserName: 'Admin Support',
                      otherUserRole: 'admin',
                    ),
                  );
                }
              },
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
              SafeNavigator.push(context, page);
            }
          : null,
    );
  }

  /// Special home button that clears navigation stack
  Widget _buildHomeButton(String imagePath, BuildContext context) {
    return IconButton(
      icon: Image.asset(
        imagePath,
        width: 30,
        height: 30,
        color: Colors.white,
      ),
      onPressed: () {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => DentistMainLayout(
              clinicId: widget.clinicId,
              dentistId: widget.dentistId,
            ),
          ),
          (route) => false,
        );
      },
    );
  }
}
