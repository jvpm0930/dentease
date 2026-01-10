import 'package:dentease/patients/patient_booking_apprv.dart';
import 'package:dentease/patients/patient_booking_rej.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

String formatDateTime(String dateTime) {
  DateTime parsedDate = DateTime.parse(dateTime);
  return DateFormat('MMM d, y • h:mma').format(parsedDate).toLowerCase();
}

class PatientBookingPend extends StatefulWidget {
  final String patientId;
  const PatientBookingPend({super.key, required this.patientId});

  @override
  PatientBookingPendState createState() => PatientBookingPendState();
}

class PatientBookingPendState extends State<PatientBookingPend> {
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;
  RealtimeChannel? _statusChannel;
  Set<String> _knownBookingIds = {};

  @override
  void initState() {
    super.initState();
    _setupStatusListener();
  }

  @override
  void dispose() {
    _statusChannel?.unsubscribe();
    super.dispose();
  }

  void _setupStatusListener() {
    // Listen for any booking updates for this patient
    _statusChannel = supabase
        .channel('patient_booking_updates_${widget.patientId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'patient_id',
            value: widget.patientId,
          ),
          callback: (payload) {
            final newStatus = payload.newRecord['status'] as String?;
            final oldStatus = payload.oldRecord['status'] as String?;
            
            // Only notify if status actually changed
            if (oldStatus != newStatus && mounted) {
              _showStatusChangeNotification(newStatus, oldStatus);
            }
          },
        )
        .subscribe();
  }

  void _showStatusChangeNotification(String? newStatus, String? oldStatus) {
    if (!mounted) return;
    
    String message;
    Color backgroundColor;
    IconData icon;
    
    switch (newStatus) {
      case 'approved':
        message = '🎉 Your appointment has been approved!';
        backgroundColor = Colors.green.shade600;
        icon = Icons.check_circle;
        break;
      case 'rejected':
        message = '❌ Your appointment was rejected';
        backgroundColor = Colors.red.shade600;
        icon = Icons.cancel;
        break;
      case 'completed':
        message = '✓ Your appointment has been completed';
        backgroundColor = Colors.blue.shade600;
        icon = Icons.done_all;
        break;
      default:
        return; // Don't show notification for other statuses
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: newStatus == 'approved' ? SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            Navigator.pushReplacement(
              context,
              _fadeRoute(PatientBookingApprv(patientId: widget.patientId)),
            );
          },
        ) : (newStatus == 'rejected' ? SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            Navigator.pushReplacement(
              context,
              _fadeRoute(PatientBookingRej(patientId: widget.patientId)),
            );
          },
        ) : null),
      ),
    );
  }

  Stream<List<Map<String, dynamic>>> _getBookingsStream() {
    return supabase
        .from('bookings')
        .stream(primaryKey: ['booking_id'])
        .eq('patient_id', widget.patientId)
        .map((data) =>
            data.where((booking) => booking['status'] == 'pending').toList());
  }

  Future<List<Map<String, dynamic>>> _enrichBookingsWithDetails(
      List<Map<String, dynamic>> bookings) async {
    List<Map<String, dynamic>> enrichedBookings = [];

    for (var booking in bookings) {
      // Fetch clinic details
      final clinic = await supabase
          .from('clinics')
          .select('clinic_name')
          .eq('clinic_id', booking['clinic_id'])
          .maybeSingle();

      // Fetch service details
      final service = await supabase
          .from('services')
          .select('service_name')
          .eq('service_id', booking['service_id'])
          .maybeSingle();

      enrichedBookings.add({
        ...booking,
        'clinics': clinic ?? {'clinic_name': 'Unknown Clinic'},
        'services': service ?? {'service_name': 'Unknown Service'},
      });
    }

    return enrichedBookings;
  }

  // Fade-only transition
  Route<T> _fadeRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fade =
            CurvedAnimation(parent: animation, curve: Curves.easeInOut);
        return FadeTransition(opacity: fade, child: child);
      },
    );
  }

  Future<void> _cancelBooking(String bookingId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('bookings').delete().eq('booking_id', bookingId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking cancelled successfully.')),
          );
          setState(() {
            _bookingsFuture = _fetchBookings();
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error cancelling booking: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                "My Appointments",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 22,
                ),
              ),
            ),
            // Navigation Buttons
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: _segButton(
                      label: "Approved",
                      isActive: false,
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          _fadeRoute(
                              PatientBookingApprv(patientId: widget.patientId)),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _segButton(
                      label: "Pending",
                      isActive: true, // current page
                      onPressed: null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _segButton(
                      label: "Rejected",
                      isActive: false,
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          _fadeRoute(
                              PatientBookingRej(patientId: widget.patientId)),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Booking List
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _getBookingsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Text(
                        "No pending bookings",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }

                  final bookings = snapshot.data!;

                  return FutureBuilder<List<Map<String, dynamic>>>(
                    future: _enrichBookingsWithDetails(bookings),
                    builder: (context, enrichedSnapshot) {
                      if (!enrichedSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final enrichedBookings = enrichedSnapshot.data!;

                      return ListView.builder(
                        itemCount: enrichedBookings.length,
                        itemBuilder: (context, index) {
                          final booking = enrichedBookings[index];

                          return Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBackground,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: AppTheme.cardShadow,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.warningColor
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.schedule_rounded,
                                          color: AppTheme.warningColor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          booking['services']['service_name'],
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textDark,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: AppTheme.errorColor),
                                        tooltip: 'Cancel Booking',
                                        onPressed: () => _cancelBooking(
                                            booking['booking_id']),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today_rounded,
                                          size: 16, color: AppTheme.textGrey),
                                      const SizedBox(width: 8),
                                      Text(
                                        formatDateTime(booking['date']),
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: AppTheme.textGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.local_hospital_rounded,
                                          size: 16, color: AppTheme.textGrey),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          booking['clinics']['clinic_name'],
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: AppTheme.textGrey,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.warningColor
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Pending Approval',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.warningColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segButton({
    required String label,
    required bool isActive,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: isActive ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isActive ? AppTheme.primaryBlue : AppTheme.cardBackground,
        foregroundColor: isActive ? Colors.white : AppTheme.textGrey,
        disabledBackgroundColor: AppTheme.primaryBlue,
        disabledForegroundColor: Colors.white,
        elevation: isActive ? 2 : 0,
        shadowColor: AppTheme.shadowMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isActive ? AppTheme.primaryBlue : AppTheme.dividerColor,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        textStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      child: Text(label),
    );
  }
}
