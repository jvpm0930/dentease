import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:intl/intl.dart';

String formatDateTime(String dateTime) {
  DateTime parsedDate = DateTime.parse(dateTime);
  return DateFormat('MMM d, y • h:mma').format(parsedDate).toLowerCase();
}

class DentistRejectedCancelledBookingsPage extends StatefulWidget {
  final Map<String, dynamic> booking;

  const DentistRejectedCancelledBookingsPage(
      {super.key, required this.booking});

  @override
  State<DentistRejectedCancelledBookingsPage> createState() =>
      _DentistRejectedCancelledBookingsPageState();
}

class _DentistRejectedCancelledBookingsPageState
    extends State<DentistRejectedCancelledBookingsPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> bookings = [];
  bool isLoading = true;

  static const Color kPrimary = Color(0xFF103D7E);

  @override
  void initState() {
    super.initState();
    fetchBookings();
  }

  Future<void> fetchBookings() async {
    setState(() => isLoading = true);
    final response = await supabase
        .from('bookings')
        .select(
            'booking_id, patient_id, service_id, clinic_id, date, status, reason, '
            'patients(firstname, lastname), clinics(clinic_name), services(service_name)')
        .eq('booking_id', widget.booking['booking_id'])
        .or('status.eq.rejected,status.eq.cancelled');

    setState(() {
      bookings = List<Map<String, dynamic>>.from(response);
      isLoading = false;
    });
  }

  Future<void> submitReason(String bookingId, String reason) async {
    await supabase
        .from('bookings')
        .update({'reason': reason}).eq('booking_id', bookingId);
    await fetchBookings();
  }

  Future<void> _promptReasonUpdate({
    required String bookingId,
    required String currentReason,
  }) async {
    final controller = TextEditingController(text: currentReason);
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Reason'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter reason...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await submitReason(bookingId, result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reason updated')),
      );
    }
  }

  Widget _statusChip(String status) {
    final lower = status.toLowerCase();
    Color bg = Colors.red.withOpacity(0.12);
    Color fg = Colors.red.shade800;
    if (lower == 'cancelled') {
      bg = Colors.orange.withOpacity(0.12);
      fg = Colors.orange.shade800;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            "Rejected/Cancelled Reason",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : bookings.isEmpty
                ? const Center(
                    child: Text(
                      'No rejected or cancelled bookings.',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: fetchBookings,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: bookings.length,
                      itemBuilder: (context, index) {
                        final booking = bookings[index];

                        final serviceName =
                            booking['services']?['service_name']?.toString() ??
                                'Service';
                        final clinicName =
                            booking['clinics']?['clinic_name']?.toString() ??
                                'Clinic';
                        final patientFirst =
                            booking['patients']?['firstname']?.toString() ?? '';
                        final patientLast =
                            booking['patients']?['lastname']?.toString() ?? '';
                        final patientFull =
                            ('$patientFirst $patientLast').trim().isEmpty
                                ? 'Unknown patient'
                                : '$patientFirst $patientLast';
                        final dateStr = booking['date'] != null
                            ? formatDateTime(booking['date'])
                            : 'N/A';
                        final status = booking['status']?.toString() ?? 'N/A';
                        final reason = booking['reason']?.toString() ?? '';

                        return _SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header: Service and status chip
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Icon(Icons.event_busy_rounded,
                                      color: kPrimary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      serviceName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  _statusChip(status),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Details
                              _kv('Patient', patientFull),
                              _kv('Clinic', clinicName),
                              _kv('Date booked', dateStr),
                              const SizedBox(height: 6),

                              // Reason display
                              const Text(
                                'Reason:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  reason.isNotEmpty ? reason : 'None provided',
                                  style: TextStyle(
                                    color: reason.isNotEmpty
                                        ? Colors.black87
                                        : Colors.black45,
                                    fontStyle: reason.isNotEmpty
                                        ? FontStyle.normal
                                        : FontStyle.italic,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Update button
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  onPressed: () => _promptReasonUpdate(
                                    bookingId: booking['booking_id'].toString(),
                                    currentReason: reason,
                                  ),
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Edit Reason'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: kPrimary,
                                    side: const BorderSide(color: kPrimary),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$k:',
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(
                color: Colors.black87,
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

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.98),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
