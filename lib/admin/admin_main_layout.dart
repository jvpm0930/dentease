import 'package:dentease/admin/pages/clinics/admin_dashboard.dart';
import 'package:dentease/admin/pages/clinics/admin_dentease_pending.dart';
import 'package:dentease/admin/pages/admin_chat_list.dart';
import 'package:dentease/admin/pages/admin_profile_page.dart';
import 'package:dentease/layouts/master_layout.dart';
import 'package:dentease/services/admin_notification_service.dart';
import 'package:dentease/services/messaging_service.dart';
import 'package:dentease/services/unified_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

/// Master Layout for Admin Dashboard
/// Uses IndexedStack to prevent navigation stacking bug
/// Implements double-back-to-exit pattern
class AdminMainLayout extends StatefulWidget {
  const AdminMainLayout({super.key});

  @override
  State<AdminMainLayout> createState() => _AdminMainLayoutState();
}

class _AdminMainLayoutState extends State<AdminMainLayout> {
  int _selectedIndex = 0;
  DateTime? _lastBackPressed;

  // Notification service for real-time alerts
  AdminNotificationService? _notificationService;
  final MessagingService _messagingService = MessagingService();
  final UnifiedNotificationService _unifiedNotificationService =
      UnifiedNotificationService();

  int _pendingCount = 0;
  int _unreadMessageCount = 0;
  StreamSubscription<int>? _messageSubscription;
  Timer? _pendingTimer;

  // Pages held in IndexedStack - they stay alive and don't rebuild
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const AdminDashboardPage(), // index 0 - Dashboard
      const AdminPendingPage(), // index 1 - Pending Requests
      const AdminChatListPage(), // index 2 - Chat
      const AdminProfilePage(), // index 3 - Profile
    ];

    // Initialize notification service
    _initNotificationService();
    _fetchBadgeCounts();
    _subscribeToMessages();

    // Initialize unified notification service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final adminId = Supabase.instance.client.auth.currentUser?.id;
      if (adminId != null && mounted) {
        _unifiedNotificationService.initialize(
          userId: adminId,
          userRole: 'admin',
          tableName: 'admins',
          idColumn: 'admin_id',
          context: context,
        );
      }
    });

    // Periodically refresh pending count
    _pendingTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => _fetchPendingCount());
  }

  @override
  void dispose() {
    _notificationService?.dispose();
    _messageSubscription?.cancel();
    _pendingTimer?.cancel();
    _unifiedNotificationService.dispose();
    super.dispose();
  }

  void _initNotificationService() {
    final adminId = Supabase.instance.client.auth.currentUser?.id;
    if (adminId == null) return;

    _notificationService = AdminNotificationService(
      onNotification: (title, body, type, data) {
        // Refresh counts when notification received
        _fetchBadgeCounts();
      },
    );

    // Initialize listeners after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _notificationService?.initializeListeners(context, adminId);
      }
    });
  }

  void _subscribeToMessages() {
    final adminId = Supabase.instance.client.auth.currentUser?.id;
    if (adminId == null) return;

    // Stream unread count for real-time navbar update
    _messageSubscription =
        _messagingService.streamTotalUnreadCount(adminId).listen((count) {
      if (mounted) {
        setState(() {
          _unreadMessageCount = count;
        });
      }
    });
  }

  Future<void> _fetchBadgeCounts() async {
    await _fetchPendingCount();

    final adminId = Supabase.instance.client.auth.currentUser?.id;
    if (adminId != null) {
      final count = await _messagingService.getTotalUnreadCount(adminId);
      if (mounted) {
        setState(() {
          _unreadMessageCount = count;
        });
      }
    }
  }

  Future<void> _fetchPendingCount() async {
    final supabase = Supabase.instance.client;
    try {
      final pendingClinics = await supabase
          .from('clinics')
          .count(CountOption.exact)
          .eq('status', 'pending');

      if (mounted) {
        setState(() {
          _pendingCount = pendingClinics;
        });
      }
    } catch (e) {
      debugPrint('Error fetching pending clinic count: $e');
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
      // Refresh pending count when navigating to pending tab
      if (index == 1) {
        _fetchPendingCount();
      }
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
        title: 'Admin Dashboard',
        showAppBar: false,
        currentIndex: _selectedIndex,
        onNavTap: _onItemTapped,
        navItems: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            activeIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _pendingCount > 0,
              label: Text('$_pendingCount'),
              child: const Icon(Icons.pending_actions_rounded),
            ),
            activeIcon: Badge(
              isLabelVisible: _pendingCount > 0,
              label: Text('$_pendingCount'),
              child: const Icon(Icons.pending_actions_rounded),
            ),
            label: 'Pending',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _unreadMessageCount > 0,
              label: Text('$_unreadMessageCount'),
              child: const Icon(Icons.chat_rounded),
            ),
            activeIcon: Badge(
              isLabelVisible: _unreadMessageCount > 0,
              label: Text('$_unreadMessageCount'),
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
