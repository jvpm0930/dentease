import 'package:dentease/patients/patient_booking_apprv.dart';
import 'package:dentease/patients/patient_booking_pend.dart';
import 'package:dentease/patients/patient_rej-can.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

String formatDateTime(String dateTime) {
  DateTime parsedDate = DateTime.parse(dateTime);
  return DateFormat('MMM d, y • h:mma').format(parsedDate).toLowerCase();
}

class PatientBookingRej extends StatefulWidget {
  final String patientId;
  const PatientBookingRej({super.key, required this.patientId});

  @override
  _PatientBookingRejState createState() => _PatientBookingRejState();
}

class _PatientBookingRejState extends State<PatientBookingRej> {
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
            'booking_id, patient_id, service_id, clinic_id, date, status, patients(firstname, lastname), clinics(clinic_name), services(service_name)')
        .or('status.eq.rejected, status.eq.cancelled') // Alternative for filtering multiple statuses
        .eq('patient_id', widget.patientId);
    return response;
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
        child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          "Rejected/Cancelled Booking",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Buttons for switching between Approved & Pending
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
                          builder: (context) =>
                              PatientBookingApprv(patientId: widget.patientId),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue, // Active color
                      foregroundColor: Colors.white, // Active text color
                    ),
                    child: const Text("Approved"),
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
                              PatientBookingPend(patientId: widget.patientId),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue, // Active color
                      foregroundColor: Colors.white, // Active text color
                    ),
                    child: const Text("Pending"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        null, // Disable the "Approved" button in this page
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300], // Disabled background
                      foregroundColor: Colors.grey[600], // Disabled text color
                    ),
                    child: const Text("Rejected"),
                  ),
                ),
              ],
            ),
          ),

          // Booking list
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _bookingsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No rejected/cancelled bookings"));
                }

                final bookings = snapshot.data!;

                return ListView.builder(
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final booking = bookings[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(10),
                        title: Text(
                          booking['services']['service_name'],
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Date: ${formatDateTime(booking['date'])}"),
                            Text(
                                "Clinic: ${booking['clinics']['clinic_name']}"),
                            Text(
                              "Status: ${booking['status']}",
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        trailing: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PatientRejectedCancelledBookingsPage(  
                                    booking: booking,
                                    patientId: widget.patientId
                                ),
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.only(right: 10),
                            child: Icon(Icons.info, color: Colors.blue),
                          ),
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
    ));
  }
}
