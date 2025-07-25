import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

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
        .eq('booking_id', widget.booking['booking_id']) // FIXED
        .or('status.eq.rejected,status.eq.cancelled');

    setState(() {
      bookings = List<Map<String, dynamic>>.from(response);
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rejected & Cancelled Reason')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : bookings.isEmpty
              ? const Center(child: Text('No rejected or cancelled bookings.'))
              : ListView.builder(
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final booking = bookings[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              title: Text('Reason: ${booking['reason'] ?? 'None'}',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold // You can change this to any color you like
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'Patient: ${booking['patients']['firstname']} ${booking['patients']['lastname']}' ??
                                          'None'),
                                  Text(
                                      "Date booked: ${formatDateTime(booking['date'])}"),
                                  Text('Status: ${booking['status']}',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors
                                          .redAccent, // You can change this to any color you like
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8)
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
