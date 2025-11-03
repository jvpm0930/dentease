import 'package:dentease/patients/patient_booking_details.dart';
import 'package:dentease/patients/patient_booking_pend.dart';
import 'package:dentease/patients/patient_booking_rej.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

String formatDateTime(String dateTime) {
  DateTime parsedDate = DateTime.parse(dateTime);
  return DateFormat('MMM d, y • h:mma').format(parsedDate).toLowerCase();
}

class PatientBookingApprv extends StatefulWidget {
  final String patientId;
  const PatientBookingApprv({super.key, required this.patientId});

  @override
  _PatientBookingApprvState createState() => _PatientBookingApprvState();
}

class _PatientBookingApprvState extends State<PatientBookingApprv> {
  final supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    setState(() {
      _bookingsFuture = supabase
          .from('bookings')
          .select('booking_id, patient_id, service_id, clinic_id, date, status, before_url, after_url, services(service_name, service_price), clinics(clinic_name), patients(firstname, lastname, email, phone)')
          .or('status.eq.approved, status.eq.completed')
          .eq('patient_id', widget.patientId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            "Approved Booking Request",
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
                      onPressed: null, // Disabled (Already on this page)
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.grey[600],
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
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
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

            // Booking list
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _bookingsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text("No approved bookings"));
                  }

                  final bookings = snapshot.data!;

                  return RefreshIndicator(
                    onRefresh: _fetchBookings,
                    child: ListView.builder(
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
                                Text(
                                    "Date: ${formatDateTime(booking['date'])}"),
                                Text(
                                    "Clinic: ${booking['clinics']['clinic_name']}"),
                                Text(
                                  "Status: ${booking['status']}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: booking['status'] == 'approved'
                                        ? Colors.blue
                                        : booking['status'] == 'completed'
                                            ? Colors.green
                                            : Colors.black, // default color
                                  ),
                                ),
                              ],
                            ),
                            trailing: GestureDetector(
                              onTap: () {
                                // Navigate to details page, passing the booking data
                                final clinicId = booking['clinic_id'];
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PatientBookingDetailsPage(
                                        booking: booking,
                                        clinicId: clinicId),
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
                    ),
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
