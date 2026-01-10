import 'package:dentease/patients/patient_booking_apprv.dart';
import 'package:dentease/patients/patient_booking_pend.dart';
import 'package:dentease/patients/patient_rej-can.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

String formatDateTime(String dateTime) {
  DateTime parsedDate = DateTime.parse(dateTime);
  return DateFormat('MMM d, y • h:mma').format(parsedDate).toLowerCase();
}

class PatientBookingRej extends StatefulWidget {
  final String patientId;
  const PatientBookingRej({super.key, required this.patientId});

  @override
  PatientBookingRejState createState() => PatientBookingRejState();
}

class PatientBookingRejState extends State<PatientBookingRej> {
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
  }

  Stream<List<Map<String, dynamic>>> _getBookingsStream() {
    return supabase
        .from('bookings')
        .stream(primaryKey: ['booking_id'])
        .eq('patient_id', widget.patientId)
        .map((data) => data
            .where((booking) =>
                booking['status'] == 'rejected' ||
                booking['status'] == 'cancelled')
            .toList());
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
                      isActive: false,
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          _fadeRoute(
                              PatientBookingPend(patientId: widget.patientId)),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _segButton(
                      label: "Rejected",
                      isActive: true, // current page
                      onPressed: null,
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
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primaryBlue));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Text(
                        "No rejected/cancelled bookings",
                        style: GoogleFonts.poppins(
                          color: AppTheme.textGrey,
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
                        return const Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.primaryBlue));
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
                                          color: AppTheme.errorColor
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          booking['status'] == 'cancelled'
                                              ? Icons.cancel_rounded
                                              : Icons.close_rounded,
                                          color: AppTheme.errorColor,
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
                                            Icons.info_outline_rounded,
                                            color: AppTheme.primaryBlue),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            _fadeRoute(
                                              PatientRejectedCancelledBookingsPage(
                                                booking: booking,
                                                patientId: widget.patientId,
                                              ),
                                            ),
                                          );
                                        },
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
                                      color: AppTheme.errorColor
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      booking['status'] == 'cancelled'
                                          ? 'Cancelled'
                                          : 'Rejected',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.errorColor,
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
