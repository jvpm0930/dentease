import 'package:dentease/patients/patient_booking_details.dart';
import 'package:dentease/patients/patient_rej-can.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

String _formatDateTime(String dateTime) {
  DateTime parsedDate = DateTime.parse(dateTime);
  return DateFormat('MMM d, y • h:mma').format(parsedDate).toLowerCase();
}

class PatientAppointments extends StatefulWidget {
  final String patientId;
  const PatientAppointments({super.key, required this.patientId});

  @override
  State<PatientAppointments> createState() => _PatientAppointmentsState();
}

class _PatientAppointmentsState extends State<PatientAppointments> {
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;

  // 0 = Approved, 1 = Pending, 2 = Rejected
  int _selectedTab = 1; // Default to Pending

  @override
  void initState() {
    super.initState();
  }

  // Simpler approach for this file: Use StreamBuilder on the TABLE events, then fetch data.
  // Actually, let's keep it simple. We will use a Stream of the TABLE and then map it to the full query.

  Stream<List<Map<String, dynamic>>> _buildBookingStream(
      List<String> statuses) {
    return supabase
        .from('bookings')
        .stream(primaryKey: ['booking_id'])
        .eq('patient_id', widget.patientId)
        .order('date', ascending: true) // Stream order constraint
        .asyncMap((_) async {
          // When any change happens to this user's bookings, fetch the specific status tab data with full joins
          final response = await supabase
              .from('bookings')
              .select('*, clinics(*), services(*), patients(*)')
              .eq('patient_id', widget.patientId)
              .inFilter('status', statuses)
              .order('date', ascending: false);
          return List<Map<String, dynamic>>.from(response);
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          "My Appointments",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Tab Buttons
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Row(
                children: [
                  Expanded(child: _segButton(label: "Approved", index: 0)),
                  const SizedBox(width: 10),
                  Expanded(child: _segButton(label: "Pending", index: 1)),
                  const SizedBox(width: 10),
                  Expanded(child: _segButton(label: "Rejected", index: 2)),
                ],
              ),
            ),
            // Content
            Expanded(
              child: IndexedStack(
                index: _selectedTab,
                children: [
                  _buildStreamList(
                      ['approved', 'completed'], _buildApprovedCard),
                  _buildStreamList(['pending'], _buildPendingCard),
                  _buildStreamList(
                      ['rejected', 'cancelled'], _buildRejectedCard),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segButton({required String label, required int index}) {
    final isActive = _selectedTab == index;
    return ElevatedButton(
      onPressed: isActive ? null : () => setState(() => _selectedTab = index),
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

  Widget _buildStreamList(List<String> statuses,
      Widget Function(Map<String, dynamic>) cardBuilder) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _buildBookingStream(statuses),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text("No bookings found",
                style: GoogleFonts.poppins(
                    color: AppTheme.textGrey,
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              // Triggering setState will rebuild the widget,
              // causing _buildBookingStream to be called again,
              // establishing a fresh stream and fetching the latest data.
            });
          },
          color: AppTheme.primaryBlue,
          child: ListView.builder(
            itemCount: snapshot.data!.length,
            // Always scrollable to ensure pull-to-refresh works even with few items
            physics: const AlwaysScrollableScrollPhysics(),
            itemBuilder: (context, index) => cardBuilder(snapshot.data![index]),
          ),
        );
      },
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> booking) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                    color: AppTheme.warningColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.schedule_rounded,
                      color: AppTheme.warningColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    booking['services']['service_name'],
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppTheme.errorColor),
                  tooltip: 'Cancel Booking',
                  onPressed: () => _cancelBooking(booking['booking_id']),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.calendar_today_rounded,
                  size: 16, color: AppTheme.textGrey),
              const SizedBox(width: 8),
              Text(_formatDateTime(booking['date']),
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: AppTheme.textGrey)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.local_hospital_rounded,
                  size: 16, color: AppTheme.textGrey),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(booking['clinics']['clinic_name'],
                      style: GoogleFonts.poppins(
                          fontSize: 14, color: AppTheme.textGrey))),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Pending Approval',
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warningColor)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovedCard(Map<String, dynamic> booking) {
    final isCompleted = booking['status'] == 'completed';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                    color: (isCompleted
                            ? AppTheme.tealAccent
                            : AppTheme.primaryBlue)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.event_available_rounded,
                    color: isCompleted
                        ? AppTheme.tealAccent
                        : AppTheme.primaryBlue,
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
                        color: AppTheme.textDark),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded,
                      color: AppTheme.primaryBlue),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PatientBookingDetailsPage(
                          booking: booking,
                          clinicId: booking['clinic_id'],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.calendar_today_rounded,
                  size: 16, color: AppTheme.textGrey),
              const SizedBox(width: 8),
              Text(_formatDateTime(booking['date']),
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: AppTheme.textGrey)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.local_hospital_rounded,
                  size: 16, color: AppTheme.textGrey),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(booking['clinics']['clinic_name'],
                      style: GoogleFonts.poppins(
                          fontSize: 14, color: AppTheme.textGrey))),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:
                    (isCompleted ? AppTheme.tealAccent : AppTheme.primaryBlue)
                        .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isCompleted ? 'Completed' : 'Approved',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isCompleted
                        ? AppTheme.tealAccent
                        : AppTheme.primaryBlue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectedCard(Map<String, dynamic> booking) {
    final isCancelled = booking['status'] == 'cancelled';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isCancelled ? Icons.cancel_rounded : Icons.close_rounded,
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
                        color: AppTheme.textDark),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded,
                      color: AppTheme.primaryBlue),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
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
            Row(children: [
              Icon(Icons.calendar_today_rounded,
                  size: 16, color: AppTheme.textGrey),
              const SizedBox(width: 8),
              Text(_formatDateTime(booking['date']),
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: AppTheme.textGrey)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.local_hospital_rounded,
                  size: 16, color: AppTheme.textGrey),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(booking['clinics']['clinic_name'],
                      style: GoogleFonts.poppins(
                          fontSize: 14, color: AppTheme.textGrey))),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isCancelled ? 'Cancelled' : 'Rejected',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.errorColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelBooking(String bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Appointment?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to cancel this appointment?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await supabase
          .from('bookings')
          .update({'status': 'cancelled'}).eq('booking_id', bookingId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment cancelled')),
        );
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
