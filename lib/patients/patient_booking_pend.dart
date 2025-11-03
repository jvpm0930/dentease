import 'package:dentease/patients/patient_booking_apprv.dart';
import 'package:dentease/patients/patient_booking_rej.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

String formatDateTime(String dateTime) {
  DateTime parsedDate = DateTime.parse(dateTime);
  return DateFormat('MMM d, y • h:mma').format(parsedDate).toLowerCase();
}

class PatientBookingPend extends StatefulWidget {
  final String patientId;
  const PatientBookingPend({super.key, required this.patientId});

  @override
  _PatientBookingPendState createState() => _PatientBookingPendState();
}

class _PatientBookingPendState extends State<PatientBookingPend> {
  final supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _bookingsFuture = _fetchBookings();
  }

  Future<List<Map<String, dynamic>>> _fetchBookings() async {
    final response = await supabase
        .from('bookings')
        .select(
            'booking_id, patient_id, service_id, clinic_id, date, status, clinics(clinic_name), services(service_name)')
        .eq('status', 'pending')
        .eq('patient_id', widget.patientId);
    return response;
  }

  /// 🗑️ Cancel (Delete) Booking
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking cancelled successfully.')),
        );

        // Refresh the booking list
        setState(() {
          _bookingsFuture = _fetchBookings();
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling booking: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            "Pending Booking Request",
            style: TextStyle(color: Colors.white),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Column(
          children: [
            // Navigation Buttons
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PatientBookingApprv(
                                patientId: widget.patientId),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Approved"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.grey[600],
                      ),
                      child: const Text("Pending"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                PatientBookingRej(patientId: widget.patientId),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Rejected"),
                    ),
                  ),
                ],
              ),
            ),

            // Booking List
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _bookingsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                        child: Text("No pending bookings",
                            style: TextStyle(color: Colors.white)));
                  }

                  final bookings = snapshot.data!;

                  return ListView.builder(
                    itemCount: bookings.length,
                    itemBuilder: (context, index) {
                      final booking = bookings[index];

                      return Card(
                        margin: const EdgeInsets.all(10),
                        child: ListTile(
                          title: Text(
                            booking['services']['service_name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Date: ${formatDateTime(booking['date'])}"),
                              Text(
                                  "Clinic: ${booking['clinics']['clinic_name']}"),
                              Text(
                                "Status: ${booking['status']}",
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Cancel Booking',
                            onPressed: () =>
                                _cancelBooking(booking['booking_id']),
                          ),
                        ),
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
}
