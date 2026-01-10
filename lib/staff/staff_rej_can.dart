import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

String formatDateTime(String dateTime) {
  DateTime parsedDate = DateTime.parse(dateTime);
  return DateFormat('MMM d, y • h:mma').format(parsedDate).toLowerCase();
}

class StaffRejectedCancelledBookingsPage extends StatefulWidget {
  final Map<String, dynamic> booking;

  const StaffRejectedCancelledBookingsPage({super.key, required this.booking});

  @override
  State<StaffRejectedCancelledBookingsPage> createState() =>
      _StaffRejectedCancelledBookingsPageState();
}

class _StaffRejectedCancelledBookingsPageState
    extends State<StaffRejectedCancelledBookingsPage> {
  List<Map<String, dynamic>> bookings = [];
  final TextEditingController _reasonController = TextEditingController();
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

  Future<void> submitReason(String bookingId, String reason) async {
    await Supabase.instance.client
        .from('bookings')
        .update({'reason': reason}).eq('booking_id', bookingId);

    _reasonController.clear();
    fetchBookings(); // refresh
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(
            "Booking Details",
            style: GoogleFonts.poppins(
              color: AppTheme.textDark,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: AppTheme.textDark),
        ),
        body: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryBlue),
              )
            : bookings.isEmpty
                ? _buildEmptyState()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: bookings
                          .map((booking) => _buildBookingCard(booking))
                          .toList(),
                    ),
                  ),
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final status = booking['status'] ?? 'unknown';
    final isRejected = status == 'rejected';
    final statusColor = isRejected ? AppTheme.errorColor : AppTheme.textGrey;
    final patientName =
        '${booking['patients']['firstname'] ?? ''} ${booking['patients']['lastname'] ?? ''}'
            .trim();
    final serviceName =
        booking['services']['service_name'] ?? 'Unknown Service';
    final reason = booking['reason'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor, width: 2),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              children: [
                Expanded(
                  child: Text(
                    serviceName,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Patient info
            _buildInfoRow(Icons.person_outline, 'Patient', patientName),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.calendar_today_outlined, 'Date',
                formatDateTime(booking['date'])),
            const SizedBox(height: 12),
            _buildInfoRow(
                Icons.medical_services_outlined, 'Service', serviceName),

            if (reason.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(Icons.info_outline, 'Reason', reason),
            ],

            const SizedBox(height: 20),

            // Update reason section
            Text(
              'Update Reason',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: TextField(
                controller: _reasonController,
                maxLines: 3,
                style: GoogleFonts.poppins(
                  color: AppTheme.textDark,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter reason for ${status}...',
                  hintStyle: GoogleFonts.poppins(
                    color: AppTheme.textGrey,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_reasonController.text.trim().isNotEmpty) {
                    submitReason(
                      booking['booking_id'].toString(),
                      _reasonController.text.trim(),
                    );
                  }
                },
                icon: const Icon(Icons.save_outlined, size: 20),
                label: Text(
                  'Update Reason',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryBlue, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value.isNotEmpty ? value : 'N/A',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            size: 64,
            color: AppTheme.textGrey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No booking details found',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textGrey,
            ),
          ),
        ],
      ),
    );
  }
}
