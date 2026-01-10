import 'package:dentease/services/inapp_message_notification_service.dart';
import 'package:dentease/services/messaging_service.dart';
import 'package:dentease/services/unified_notification_service.dart';
import 'package:dentease/staff/staff_appointments.dart';
import 'package:dentease/staff/staff_home.dart';
import 'package:dentease/staff/staff_profile.dart';
import 'package:dentease/staff/staff_chat_list.dart';
import 'package:dentease/layouts/master_layout.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

/// Master Layout for Staff Dashboard
/// Uses IndexedStack to prevent navigation stacking bug
/// Implements double-back-to-exit pattern
class StaffMainLayout extends StatefulWidget {
  final String clinicId;
  final String staffId;

  const StaffMainLayout({
    super.key,
    required this.clinicId,
    required this.staffId,
  });

  @override
  State<StaffMainLayout> createState() => _StaffMainLayoutState();
}

class _StaffMainLayoutState extends State<StaffMainLayout> {
  int _selectedIndex = 0;
  DateTime? _lastBackPressed;
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;
  final MessagingService _messagingService = MessagingService();
  final UnifiedNotificationService _unifiedNotificationService =
      UnifiedNotificationService();
  final InAppMessageNotificationService _inAppMessageNotificationService =
      InAppMessageNotificationService();

  // Badge counts
  int pendingBookingsCount = 0;
  int unreadMessagesCount = 0;
  StreamSubscription<int>? _messageSubscription;
  StreamSubscription? _bookingSubscription;
  Timer? _pendingTimer;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    debugPrint('🎬 [StaffLayout] Initializing for staff: ${widget.staffId}');
    _pages = [
      StaffHomePage(
        clinicId: widget.clinicId,
        staffId: widget.staffId,
      ), // index 0 - Dashboard
      StaffAppointments(
        clinicId: widget.clinicId,
        staffId: widget.staffId,
      ), // index 1 - Appointments
      StaffChatList(
        clinicId: widget.clinicId,
        staffId: widget.staffId,
      ), // index 2 - Chat
      StaffProfile(
        staffId: widget.staffId,
      ), // index 3 - Profile
    ];
    _fetchBadgeCounts();
    _subscribeToBadges();
    _subscribeToBookings();

    // Initialize unified notification service for in-app notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        debugPrint(
            '🔔 [StaffLayout] Initializing UnifiedNotificationService...');
        _unifiedNotificationService.initialize(
          userId: widget.staffId,
          userRole: 'staff',
          tableName: 'staffs',
          idColumn: 'staff_id',
          context: context,
        );

        // Initialize in-app message notification service
        debugPrint(
            '🔔 [StaffLayout] Initializing InAppMessageNotificationService...');
        debugPrint('   - Using staffId: ${widget.staffId}');
        _inAppMessageNotificationService.initialize(
          userId: widget.staffId,
          userRole: 'staff',
          context: context,
          onMessageReceived: () {
            // Refresh badge counts when new message arrives
            _fetchBadgeCounts();
          },
        );
      }
    });

    // Periodically refresh pending count as backup
    _pendingTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _fetchBadgeCounts());
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _bookingSubscription?.cancel();
    _pendingTimer?.cancel();
    _unifiedNotificationService.dispose();
    _inAppMessageNotificationService.dispose();
    super.dispose();
  }

  /// Fetch badge counts for navigation items
  Future<void> _fetchBadgeCounts() async {
    try {
      // Fetch pending bookings count
      final pendingResponse = await supabase
          .from('bookings')
          .select('booking_id')
          .eq('clinic_id', widget.clinicId)
          .eq('status', 'pending');

      // Fetch unread messages count using MessagingService
      final unreadCount =
          await _messagingService.getTotalUnreadCount(widget.staffId);

      if (mounted) {
        setState(() {
          pendingBookingsCount = pendingResponse.length;
          unreadMessagesCount = unreadCount;
        });
      }
    } catch (e) {
      debugPrint('Error fetching badge counts: $e');
    }
  }

  void _subscribeToBadges() {
    debugPrint('📡 [StaffLayout] Starting message subscription...');
    // Stream unread messages
    _messageSubscription = _messagingService
        .streamTotalUnreadCount(widget.staffId)
        .listen((count) {
      if (mounted) {
        debugPrint('💬 [StaffLayout] Unread messages updated: $count');
        setState(() => unreadMessagesCount = count);
      }
    });
  }

  void _subscribeToBookings() {
    debugPrint('📡 [StaffLayout] Starting booking subscription...');
    // Real-time subscription to bookings for pending count
    _bookingSubscription = supabase
        .from('bookings')
        .stream(primaryKey: ['booking_id'])
        .eq('clinic_id', widget.clinicId)
        .listen((data) {
          if (mounted) {
            final pendingCount =
                data.where((b) => b['status'] == 'pending').length;
            debugPrint(
                '📅 [StaffLayout] Pending bookings updated: $pendingCount');
            setState(() => pendingBookingsCount = pendingCount);
          }
        });
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
      // Refresh badge counts when switching tabs
      if (index == 1 || index == 2) {
        _fetchBadgeCounts(); // For bookings
      }
    }
  }

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

  /// Build navigation item with badge
  BottomNavigationBarItem _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    int badgeCount = 0,
  }) {
    return BottomNavigationBarItem(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon),
          if (badgeCount > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      activeIcon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(activeIcon),
          if (badgeCount > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      label: label,
    );
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
        currentIndex: _selectedIndex,
        onNavTap: _onItemTapped,
        showAppBar: false, // Remove the AppBar
        navItems: [
          _buildNavItem(
            icon: Icons.dashboard_rounded,
            activeIcon: Icons.dashboard_rounded,
            label: 'Dashboard',
          ),
          _buildNavItem(
            icon: Icons.calendar_month_rounded,
            activeIcon: Icons.calendar_month_rounded,
            label: 'Appointments',
            badgeCount: pendingBookingsCount,
          ),
          _buildNavItem(
            icon: Icons.chat_rounded,
            activeIcon: Icons.chat_rounded,
            label: 'Chat',
            badgeCount: unreadMessagesCount,
          ),
          _buildNavItem(
            icon: Icons.person_rounded,
            activeIcon: Icons.person_rounded,
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
