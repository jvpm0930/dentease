import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

class DentistNotificationsPage extends StatefulWidget {
  final String dentistId;
  final String clinicId;

  const DentistNotificationsPage({
    super.key,
    required this.dentistId,
    required this.clinicId,
  });

  @override
  State<DentistNotificationsPage> createState() =>
      _DentistNotificationsPageState();
}

class _DentistNotificationsPageState extends State<DentistNotificationsPage> {
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;
  StreamSubscription? _bookingsSubscription;

  static const kPrimaryBlue = Color(0xFF0D47A1);
  static const kTextPrimary = Color(0xFF1C1C1E);
  static const kTextSecondary = Color(0xFF8E8E93);

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _bookingsSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeListener() {
    // Listen for new bookings in real-time
    _bookingsSubscription = supabase
        .from('bookings')
        .stream(primaryKey: ['booking_id'])
        .eq('clinic_id', widget.clinicId)
        .listen((data) {
          if (mounted) {
            _fetchNotifications();
          }
        });
  }

  Future<void> _fetchNotifications() async {
    try {
      // Fetch clinic status notifications
      final clinicNotifications = await _fetchClinicNotifications();

      // Fetch booking notifications
      final bookingNotifications = await _fetchBookingNotifications();

      // Combine and sort by timestamp
      final allNotifications = [
        ...clinicNotifications,
        ...bookingNotifications
      ];
      allNotifications.sort((a, b) {
        final aTime = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime.now();
        final bTime = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime.now();
        return bTime.compareTo(aTime); // Newest first
      });

      setState(() {
        notifications = allNotifications;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      setState(() => isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchClinicNotifications() async {
    try {
      final clinicResponse = await supabase
          .from('clinics')
          .select('status, rejection_reason, updated_at')
          .eq('clinic_id', widget.clinicId)
          .maybeSingle();

      if (clinicResponse != null) {
        final status = clinicResponse['status'];

        // Create notification for clinic status
        if (status == 'approved') {
          return [
            {
              'type': 'clinic_approved',
              'title': '🎉 Clinic Approved!',
              'message': 'Your clinic has been approved by admin',
              'timestamp': clinicResponse['updated_at'],
            }
          ];
        } else if (status == 'rejected') {
          return [
            {
              'type': 'clinic_rejected',
              'title': '❌ Clinic Rejected',
              'message': clinicResponse['rejection_reason'] ??
                  'Your clinic application was rejected',
              'timestamp': clinicResponse['updated_at'],
            }
          ];
        }
      }
    } catch (e) {
      debugPrint('Error fetching clinic notifications: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> _fetchBookingNotifications() async {
    try {
      // Fetch recent bookings (last 7 days)
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

      final bookingsResponse = await supabase
          .from('bookings')
          .select('booking_id, patient_id, date, created_at, status')
          .eq('clinic_id', widget.clinicId)
          .gte('created_at', sevenDaysAgo.toIso8601String())
          .order('created_at', ascending: false)
          .limit(20);

      final bookingNotifications = <Map<String, dynamic>>[];

      for (var booking in bookingsResponse) {
        // Fetch patient name
        final patientResponse = await supabase
            .from('patients')
            .select('firstname, lastname')
            .eq('patient_id', booking['patient_id'])
            .maybeSingle();

        final patientName = patientResponse != null
            ? '${patientResponse['firstname']} ${patientResponse['lastname']}'
            : 'A patient';

        final status = booking['status'] as String?;
        String title = '📅 New Appointment';
        String message = '$patientName booked an appointment';

        // Customize notification based on status
        if (status == 'pending') {
          title = '🔔 Appointment Request';
          message = '$patientName requested an appointment';
        } else if (status == 'approved') {
          title = '✅ Appointment Confirmed';
          message = 'Appointment with $patientName confirmed';
        } else if (status == 'completed') {
          title = '🎉 Appointment Completed';
          message = 'Appointment with $patientName completed';
        }

        bookingNotifications.add({
          'type': 'booking_${status ?? 'new'}',
          'title': title,
          'message': message,
          'timestamp': booking['created_at'],
        });
      }

      return bookingNotifications;
    } catch (e) {
      debugPrint('Error fetching booking notifications: $e');
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          leading: const BackButton(color: Colors.black),
          title: Text(
            'Notifications',
            style: GoogleFonts.poppins(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF0D2A7A),
                ),
              )
            : notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: Colors.white54,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No notifications',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You\'re all caught up!',
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchNotifications,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final notification = notifications[index];
                        return _buildNotificationCard(notification);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final type = notification['type'] ?? '';
    final title = notification['title'] ?? '';
    final message = notification['message'] ?? '';
    final timestamp = notification['timestamp'];

    Color iconColor = kPrimaryBlue;
    IconData icon = Icons.info;

    if (type == 'clinic_approved') {
      iconColor = const Color(0xFF34C759);
      icon = Icons.check_circle;
    } else if (type == 'clinic_rejected') {
      iconColor = const Color(0xFFFF3B30);
      icon = Icons.cancel;
    } else if (type == 'new_booking') {
      iconColor = kPrimaryBlue;
      icon = Icons.calendar_today;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: kTextPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              message,
              style: GoogleFonts.roboto(
                fontSize: 14,
                color: kTextSecondary,
              ),
            ),
            if (timestamp != null) ...[
              const SizedBox(height: 4),
              Text(
                timeago.format(DateTime.parse(timestamp)),
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  color: kTextSecondary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
