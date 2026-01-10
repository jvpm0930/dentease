import 'package:dentease/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

String formatDateTime(String dateTime) {
  DateTime parsedDate = DateTime.parse(dateTime);
  return DateFormat('MMM d, y • h:mma').format(parsedDate).toLowerCase();
}

class PatientRejectedCancelledBookingsPage extends StatefulWidget {
  final Map<String, dynamic> booking;
  final String patientId;

  const PatientRejectedCancelledBookingsPage(
      {super.key, required this.booking, required this.patientId});

  @override
  State<PatientRejectedCancelledBookingsPage> createState() =>
      _PatientRejectedCancelledBookingsPageState();
}

class _PatientRejectedCancelledBookingsPageState
    extends State<PatientRejectedCancelledBookingsPage> {
  List<Map<String, dynamic>> bookings = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchBookings();
  }

  Future<void> fetchBookings() async {
    final response = await Supabase.instance.client
        .from('bookings')
        .select(
            'booking_id, patient_id, service_id, clinic_id, date, status, reason, patients(firstname, lastname), clinics(clinic_name), services(service_name)')
        .eq('booking_id', widget.booking['booking_id'])
        .or('status.eq.rejected,status.eq.cancelled');

    setState(() {
      bookings = List<Map<String, dynamic>>.from(response);
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          "Rejection/Cancellation Details",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue))
          : bookings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 60,
                        color: AppTheme.textGrey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No rejected or cancelled bookings found.',
                        style: GoogleFonts.poppins(
                          color: AppTheme.textGrey,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: ListView.builder(
                    itemCount: bookings.length,
                    itemBuilder: (context, index) {
                      final booking = bookings[index];
                      final isRejected = booking['status'] == 'rejected';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Status Header
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.errorColor
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      isRejected
                                          ? Icons.close_rounded
                                          : Icons.cancel_rounded,
                                      color: AppTheme.errorColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      isRejected
                                          ? 'Booking Rejected'
                                          : 'Booking Cancelled',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Reason Section
                              _buildDetailSection(
                                title: "Reason",
                                icon: Icons.info_outline_rounded,
                                content:
                                    booking['reason'] ?? 'No reason provided',
                                isHighlighted: true,
                              ),

                              const SizedBox(height: 16),

                              // Service Details
                              _buildDetailSection(
                                title: "Service Details",
                                icon: Icons.medical_services_rounded,
                                content: null,
                                children: [
                                  _buildDetailRow("Service",
                                      booking['services']['service_name']),
                                  _buildDetailRow("Clinic",
                                      booking['clinics']['clinic_name']),
                                  _buildDetailRow(
                                      "Date", formatDateTime(booking['date'])),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Patient Details
                              _buildDetailSection(
                                title: "Patient Information",
                                icon: Icons.person_rounded,
                                content: null,
                                children: [
                                  _buildDetailRow("Name",
                                      "${booking['patients']['firstname']} ${booking['patients']['lastname']}"),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.errorColor
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isRejected ? 'Rejected' : 'Cancelled',
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
                  ),
                ),
    );
  }

  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    String? content,
    List<Widget>? children,
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlighted
            ? AppTheme.errorColor.withValues(alpha: 0.05)
            : AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: isHighlighted
            ? Border.all(color: AppTheme.errorColor.withValues(alpha: 0.2))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  color: isHighlighted
                      ? AppTheme.errorColor
                      : AppTheme.primaryBlue,
                  size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isHighlighted
                      ? AppTheme.errorColor
                      : AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          if (content != null) ...[
            const SizedBox(height: 8),
            Text(
              content,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textDark,
                fontWeight: isHighlighted ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
          if (children != null) ...[
            const SizedBox(height: 8),
            ...children,
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textDark,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
