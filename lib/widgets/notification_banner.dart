import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Notification Banner Widget
/// Shows persistent notification banners at the bottom of the screen
/// Similar to admin's "Message from Dentist" banner
class NotificationBanner extends StatefulWidget {
  final String userId;
  final String userRole;
  final String? clinicId;
  final VoidCallback? onTap;

  const NotificationBanner({
    super.key,
    required this.userId,
    required this.userRole,
    this.clinicId,
    this.onTap,
  });

  @override
  State<NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<NotificationBanner>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? _notificationTitle;
  String? _notificationBody;
  String? _notificationType;
  bool _isVisible = false;

  StreamSubscription? _messageSubscription;
  StreamSubscription? _bookingSubscription;
  AnimationController? _animationController;
  Animation<double>? _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _setupNotificationListeners();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _bookingSubscription?.cancel();
    _animationController?.dispose();
    super.dispose();
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    ));
  }

  void _setupNotificationListeners() {
    if (widget.userRole == 'dentist') {
      _setupDentistNotifications();
    } else if (widget.userRole == 'staff') {
      _setupStaffNotifications();
    }
  }

  void _setupDentistNotifications() {
    // Listen for new messages from patients or staff
    _messageSubscription = _supabase
        .from('messages')
        .stream(primaryKey: ['message_id']).listen((messages) {
      _checkForNewMessages(messages, 'patient');
    });

    // Listen for new booking requests
    _bookingSubscription = _supabase
        .from('bookings')
        .stream(primaryKey: ['booking_id']).listen((bookings) {
      // Filter for this clinic's pending bookings
      final clinicBookings = bookings
          .where((booking) =>
              booking['clinic_id'] == widget.clinicId &&
              booking['status'] == 'pending')
          .toList();
      _checkForNewBookings(clinicBookings);
    });
  }

  void _setupStaffNotifications() {
    // Listen for new messages from patients
    _messageSubscription = _supabase
        .from('messages')
        .stream(primaryKey: ['message_id']).listen((messages) {
      _checkForNewMessages(messages, 'patient');
    });

    // Listen for urgent booking updates
    _bookingSubscription = _supabase
        .from('bookings')
        .stream(primaryKey: ['booking_id']).listen((bookings) {
      // Filter for this clinic's bookings
      final clinicBookings = bookings
          .where((booking) => booking['clinic_id'] == widget.clinicId)
          .toList();
      _checkForUrgentBookings(clinicBookings);
    });
  }

  void _checkForNewMessages(
      List<Map<String, dynamic>> messages, String fromRole) {
    // Get recent unread messages from the specified role
    final recentMessages = messages
        .where((msg) =>
            msg['sender_role'] == fromRole &&
            msg['created_at'] != null &&
            DateTime.parse(msg['created_at'])
                .isAfter(DateTime.now().subtract(const Duration(minutes: 5))))
        .toList();

    if (recentMessages.isNotEmpty && mounted) {
      final senderName = recentMessages.first['sender_name'] ?? 'Unknown';
      _showNotification(
        'Message from ${fromRole.capitalize()}',
        senderName,
        'message',
      );
    }
  }

  void _checkForNewBookings(List<Map<String, dynamic>> bookings) {
    // Check for recent pending bookings
    final recentBookings = bookings
        .where((booking) =>
            booking['created_at'] != null &&
            DateTime.parse(booking['created_at'])
                .isAfter(DateTime.now().subtract(const Duration(minutes: 5))))
        .toList();

    if (recentBookings.isNotEmpty && mounted) {
      _showNotification(
        'New Appointment Request',
        '${recentBookings.length} pending request${recentBookings.length > 1 ? 's' : ''}',
        'booking',
      );
    }
  }

  void _checkForUrgentBookings(List<Map<String, dynamic>> bookings) {
    // Check for urgent or same-day bookings
    final today = DateTime.now();
    final urgentBookings = bookings
        .where((booking) =>
            booking['date'] != null &&
            DateTime.parse(booking['date']).day == today.day &&
            booking['status'] == 'approved')
        .toList();

    if (urgentBookings.isNotEmpty && mounted) {
      _showNotification(
        'Today\'s Appointments',
        '${urgentBookings.length} appointment${urgentBookings.length > 1 ? 's' : ''} today',
        'urgent',
      );
    }
  }

  void _showNotification(String title, String body, String type) {
    if (mounted) {
      setState(() {
        _notificationTitle = title;
        _notificationBody = body;
        _notificationType = type;
        _isVisible = true;
      });
      _animationController?.forward();

      // Auto-hide after 10 seconds
      Timer(const Duration(seconds: 10), () {
        _hideNotification();
      });
    }
  }

  void _hideNotification() {
    if (mounted) {
      _animationController?.reverse().then((_) {
        if (mounted) {
          setState(() {
            _isVisible = false;
            _notificationTitle = null;
            _notificationBody = null;
            _notificationType = null;
          });
        }
      });
    }
  }

  Color _getNotificationColor() {
    switch (_notificationType) {
      case 'message':
        return const Color(0xFF9C27B0); // Purple
      case 'booking':
        return const Color(0xFF0D2A7A); // Blue
      case 'urgent':
        return const Color(0xFFFF9800); // Orange
      default:
        return const Color(0xFF424242); // Grey
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible || _notificationTitle == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _slideAnimation!,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation!.value * 100),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getNotificationColor(),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _hideNotification();
                  widget.onTap?.call();
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _notificationTitle!,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _notificationBody!,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'View',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
