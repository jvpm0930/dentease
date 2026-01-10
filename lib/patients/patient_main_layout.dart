import 'package:dentease/clinic/scanner/imangeScanner.dart';
import 'package:dentease/patients/patient_appointments.dart';
import 'package:dentease/patients/patient_home.dart';
import 'package:dentease/patients/patient_profile.dart';
import 'package:dentease/patients/patient_chat_list_page.dart';
import 'package:dentease/services/inapp_message_notification_service.dart';
import 'package:dentease/services/messaging_service.dart';
import 'package:dentease/services/unified_notification_service.dart';
import 'package:dentease/layouts/master_layout.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

/// Master Layout for Patient Dashboard
/// Uses IndexedStack to prevent navigation stacking bug
/// Implements double-back-to-exit pattern
class PatientMainLayout extends StatefulWidget {
  const PatientMainLayout({super.key});

  @override
  State<PatientMainLayout> createState() => _PatientMainLayoutState();
}

class _PatientMainLayoutState extends State<PatientMainLayout> {
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;
  final MessagingService _messagingService = MessagingService();
  final UnifiedNotificationService _unifiedNotificationService =
      UnifiedNotificationService();
  final InAppMessageNotificationService _inAppMessageNotificationService =
      InAppMessageNotificationService();

  int _selectedIndex = 0;
  DateTime? _lastBackPressed;
  String? patientId;
  bool isLoading = true;

  late List<Widget> _pages;

  // Badge States
  int _upcomingBookingsCount = 0;
  int _unreadMessagesCount = 0;
  Timer? _badgeTimer;
  StreamSubscription<int>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    debugPrint('🎬 [PatientLayout] Initializing...');
    _fetchPatientId();
  }

  @override
  void dispose() {
    _badgeTimer?.cancel();
    _messageSubscription?.cancel();
    _unifiedNotificationService.dispose();
    _inAppMessageNotificationService.dispose();
    super.dispose();
  }

  void _startBadgeTimer() {
    // Poll for bookings count (could be real-time but low priority)
    _badgeTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _fetchBookingCount());
  }

  Future<void> _fetchBookingCount() async {
    if (!mounted || patientId == null) return;
    try {
      debugPrint(
          '📡 [PatientLayout] Fetching booking count for patient: $patientId');
      // 1. Upcoming Bookings (approved + pending)
      final bookingsCount = await supabase
          .from('bookings')
          .count(CountOption.exact)
          .eq('patient_id', patientId!)
          .inFilter('status', ['approved', 'pending']);

      if (mounted) {
        setState(() {
          _upcomingBookingsCount = bookingsCount;
        });
        debugPrint(
            '📅 [PatientLayout] Upcoming bookings count: $_upcomingBookingsCount');
      }
    } catch (e) {
      debugPrint("❌ [PatientLayout] Error fetching bookings badge: $e");
    }
  }

  /// Subscribe to new messages for real-time badge updates using MessagingService
  void _startMessageSubscription() {
    if (patientId == null) return;

    debugPrint('Testing [PatientLayout] Starting message subscription...');

    // Initial fetch
    _messagingService.getTotalUnreadCount(patientId!).then((count) {
      debugPrint('💬 [PatientLayout] Initial unread messages: $count');
      if (mounted) setState(() => _unreadMessagesCount = count);
    });

    // Real-time stream
    _messageSubscription =
        _messagingService.streamTotalUnreadCount(patientId!).listen((count) {
      if (mounted) {
        debugPrint('💬 [PatientLayout] Updated unread messages stream: $count');
        setState(() {
          _unreadMessagesCount = count;
        });
      }
    });
  }

  Future<void> _fetchPatientId() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user != null) {
      patientId = user.id;
      debugPrint('👤 [PatientLayout] Current User ID: $patientId');
      _initPages();
      _fetchBookingCount();
      _startBadgeTimer();
      _startMessageSubscription(); // Real-time message updates

      // Initialize unified notification service
      _unifiedNotificationService.initialize(
        userId: patientId!,
        userRole: 'patient',
        tableName: 'patients',
        idColumn: 'patient_id',
        context: context,
      );

      // Initialize in-app message notification service
      debugPrint(
          '🔔 [PatientLayout] Initializing InAppMessageNotificationService...');
      _inAppMessageNotificationService.initialize(
        userId: patientId!,
        userRole: 'patient',
        context: context,
        onMessageReceived: () {
          // Refresh badge counts when new message arrives
          _fetchBookingCount();
        },
      );
    } else {
      debugPrint('⚠️ [PatientLayout] No current user found in auth!');
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  void _initPages() {
    _pages = [
      PatientHomePage(patientId: patientId!),
      PatientAppointments(patientId: patientId!),
      const ImageClassifierScreen(),
      PatientChatListPage(patientId: patientId!),
      PatientProfile(patientId: patientId!),
    ];
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      debugPrint('🔄 [PatientLayout] Switching to tab: $index');
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
        backgroundColor: AppTheme.primaryBlue,
        textColor: Colors.white,
      );
      return false;
    }

    SystemNavigator.pop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || patientId == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryBlue),
        ),
      );
    }

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
        title: 'Patient Dashboard',
        showAppBar: false,
        currentIndex: _selectedIndex,
        onNavTap: _onItemTapped,
        userId: patientId,
        userRole: 'patient',
        navItems: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _upcomingBookingsCount > 0,
              label: Text('$_upcomingBookingsCount'),
              child: const Icon(Icons.calendar_month_rounded),
            ),
            activeIcon: Badge(
              isLabelVisible: _upcomingBookingsCount > 0,
              label: Text('$_upcomingBookingsCount'),
              child: const Icon(Icons.calendar_month_rounded),
            ),
            label: 'Bookings',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.document_scanner_rounded),
            activeIcon: Icon(Icons.document_scanner_rounded),
            label: 'Scan',
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
