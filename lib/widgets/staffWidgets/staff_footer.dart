import 'package:dentease/services/messaging_service.dart';
import 'package:dentease/staff/staff_chat_list.dart';
import 'package:dentease/dentist/dentist_bookings_pend.dart';
import 'package:dentease/logic/safe_navigator.dart';
import 'package:dentease/staff/staff_profile.dart';
import 'package:dentease/staff/staff_main_layout.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'dart:async';

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
  State<StaffFooter> createState() => _StaffFooterState();
}

class _StaffFooterState extends State<StaffFooter> {
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;

  // UI badges
  bool hasUnreadMessages = false;
  bool hasNewBookings = false;
  bool hasNewSupports = false;

  // Polling
  Timer? refreshTimer;
  final MessagingService _messagingService = MessagingService();
  StreamSubscription? _unreadSubscription;

  // Persistence for notified IDs (avoid duplicate notifications)
  final Set<String> notifiedBookingIds = {};
  final Set<String> notifiedMessageIds = {};
  final Set<String> notifiedSupportIds = {};

  @override
  void initState() {
    super.initState();
    initNotifications();
    _loadNotifiedIds();

    // Use Stream for chat badges
    _unreadSubscription = _messagingService
        .streamTotalUnreadCount(widget.staffId)
        .listen((count) {
      if (mounted) {
        setState(() {
          hasUnreadMessages = count > 0;
        });
      }
    });

    _fetchNewBookings();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _unreadSubscription?.cancel();
    _stopAutoRefresh();
    super.dispose();
  }

  void _startAutoRefresh() {
    refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchNewBookings();
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
          color: AppTheme.primaryBlue, // Clean primary blue background
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryBlue.withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 4),
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
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
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
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () {
                SafeNavigator.push(
                  context,
                  StaffChatList(
                    clinicId: widget.clinicId,
                    staffId: widget.staffId,
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
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () async {
                // This support button is deprecated - staff should use StaffChatList
                // which includes dentist messaging option
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Use Chat tab to contact support via dentist'),
                    duration: Duration(seconds: 2),
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
        SafeNavigator.push(context, page);
      },
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
            builder: (_) => StaffMainLayout(
              clinicId: widget.clinicId,
              staffId: widget.staffId,
            ),
          ),
          (route) => false,
        );
      },
    );
  }
}
