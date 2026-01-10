import 'package:dentease/dentist/chat/dentist_chat_hub.dart';
import 'package:dentease/dentist/dentist_appointments.dart';
import 'package:dentease/dentist/dentist_page.dart';
import 'package:dentease/dentist/dentist_profile.dart';
import 'package:dentease/layouts/master_layout.dart';
import 'package:dentease/services/inapp_message_notification_service.dart';
import 'package:dentease/services/messaging_service.dart';
import 'package:dentease/services/unified_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

/// Master Layout for Dentist Dashboard
/// Uses IndexedStack to prevent navigation stacking bug
/// Implements double-back-to-exit pattern
class DentistMainLayout extends StatefulWidget {
  final String clinicId;
  final String dentistId;

  const DentistMainLayout({
    super.key,
    required this.clinicId,
    required this.dentistId,
  });

  @override
  State<DentistMainLayout> createState() => _DentistMainLayoutState();
}

class _DentistMainLayoutState extends State<DentistMainLayout> {
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;
  int _selectedIndex = 0;
  DateTime? _lastBackPressed;

  // Pages held in IndexedStack - they stay alive and don't rebuild
  late final List<Widget> _pages;

  // Badge States
  int _pendingAppointmentsCount = 0;
  int _unreadMessagesCount = 0;
  Timer? _badgeTimer;

  // Subscriptions
  StreamSubscription? _bookingSubscription;
  StreamSubscription? _messageSubscription;

  // Services
  late final MessagingService _messagingService;
  final UnifiedNotificationService _unifiedNotificationService =
      UnifiedNotificationService();
  final InAppMessageNotificationService _inAppMessageNotificationService =
      InAppMessageNotificationService();

  @override
  void initState() {
    super.initState();

    // Initialize messaging service
    _messagingService = MessagingService();

    _pages = [
      DentistPage(
        clinicId: widget.clinicId,
        dentistId: widget.dentistId,
        onTabChange: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ), // index 0 - Home
      DentistAppointmentsPage(
        clinicId: widget.clinicId,
      ), // index 1 - Appointments
      DentistChatHub(
        clinicId: widget.clinicId,
      ), // index 2 - Chat
      DentistProfile(
        dentistId: widget.dentistId,
      ), // index 3 - Profile
    ];

    _fetchBadgeCounts();
    _startBadgeTimer();
    _subscribeToNotifications();

    // Initialize unified notification service for in-app notifications
    // Use auth user id (not dentist_id) since conversation_participants uses auth user id
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authUserId = supabase.auth.currentUser?.id;
        debugPrint(
            '🔔 [DentistLayout] Initializing UnifiedNotificationService');
        debugPrint('   - dentistId (dentist_id): ${widget.dentistId}');
        debugPrint('   - authUserId (id): $authUserId');

        // Use auth user id for notifications since that's what conversation_participants uses
        final notificationUserId = authUserId ?? widget.dentistId;

        _unifiedNotificationService.initialize(
          userId: notificationUserId,
          userRole: 'dentist',
          tableName: 'dentists',
          idColumn: 'id', // Use 'id' column (auth user id) not 'dentist_id'
          context: context,
        );

        // Initialize in-app message notification service
        // Use clinicId since that's what's used in conversation_participants for dentist
        debugPrint(
            '🔔 [DentistLayout] Initializing InAppMessageNotificationService');
        debugPrint('   - Using clinicId: ${widget.clinicId}');
        _inAppMessageNotificationService.initialize(
          userId: widget.clinicId,
          userRole: 'dentist',
          context: context,
          onMessageReceived: () {
            // Refresh badge counts when new message arrives
            _fetchBadgeCounts();
          },
        );
      }
    });
  }

  @override
  void dispose() {
    _badgeTimer?.cancel();
    _bookingSubscription?.cancel();
    _messageSubscription?.cancel();
    _unifiedNotificationService.dispose();
    _inAppMessageNotificationService.dispose();
    super.dispose();
  }

  void _startBadgeTimer() {
    _badgeTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _fetchBadgeCounts());
  }

  void _subscribeToNotifications() {
    // 1. Subscribe to appointment updates
    _bookingSubscription?.cancel();
    _bookingSubscription = supabase
        .from('bookings')
        .stream(primaryKey: ['booking_id'])
        .eq('clinic_id', widget.clinicId)
        .listen((data) {
          if (mounted) _fetchBadgeCounts();
        });

    // 2. Subscribe to message updates using MessagingService
    _messageSubscription?.cancel();
    _messageSubscription = _messagingService
        .streamTotalUnreadCount(widget.dentistId)
        .listen((count) {
      if (mounted) {
        setState(() {
          _unreadMessagesCount = count;
        });
      }
    });
  }

  Future<void> _fetchBadgeCounts() async {
    if (!mounted) return;
    try {
      // 1. Pending Appointments (status = 'pending')
      final pendingCount = await supabase
          .from('bookings')
          .count(CountOption.exact)
          .eq('clinic_id', widget.clinicId)
          .eq('status', 'pending');

      // 2. Unread Messages using MessagingService
      // The clinic's ID is used as the user_id in the messaging system for the dentist/clinic side
      // The unread count is now handled by a stream in _subscribeToNotifications,
      // but we keep this for initial fetch or if stream fails.
      final unreadCount =
          await _messagingService.getTotalUnreadCount(widget.clinicId);

      if (mounted) {
        setState(() {
          _pendingAppointmentsCount = pendingCount;
          _unreadMessagesCount = unreadCount;
        });
      }
    } catch (e) {
      debugPrint("Error fetching badges: $e");
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
    }
  }

  /// Handle back button press - double tap to exit
  Future<bool> _onWillPop() async {
    final now = DateTime.now();

    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
      return false;
    }

    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      Fluttertoast.showToast(
        msg: "Press back again to exit",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: MasterLayout.primaryBlue,
        textColor: Colors.white,
      );
      return false;
    }

    SystemNavigator.pop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: MasterLayout(
        title: 'Dentist Dashboard',
        showAppBar: false,
        currentIndex: _selectedIndex,
        onNavTap: _onItemTapped,
        navItems: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _pendingAppointmentsCount > 0,
              label: Text('$_pendingAppointmentsCount'),
              child: const Icon(Icons.event_note_rounded),
            ),
            activeIcon: Badge(
              isLabelVisible: _pendingAppointmentsCount > 0,
              label: Text('$_pendingAppointmentsCount'),
              child: const Icon(Icons.event_note_rounded),
            ),
            label: 'Appointments',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _unreadMessagesCount > 0,
              label: Text('$_unreadMessagesCount'),
              child: const Icon(Icons.chat_rounded),
            ),
            activeIcon: Badge(
              isLabelVisible: _unreadMessagesCount > 0,
              label: Text('$_unreadMessagesCount'),
              child: const Icon(Icons.chat_rounded),
            ),
            label: 'Chat',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
        body: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
      ),
    );
  }
}
