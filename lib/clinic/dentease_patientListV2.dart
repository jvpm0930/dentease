import 'package:dentease/clinic/dentease_booking_details.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

String formatDateTime(String dateTime) {
  DateTime parsedDate = DateTime.parse(dateTime);
  return DateFormat('MMM d, y • h:mma').format(parsedDate).toLowerCase();
}

class DentistBookingPatientPage extends StatefulWidget {
  final String clinicId;
  final String patientId;
  const DentistBookingPatientPage(
      {super.key, required this.clinicId, required this.patientId});

  @override
  _DentistBookingPatientPageState createState() =>
      _DentistBookingPatientPageState();
}

class _DentistBookingPatientPageState extends State<DentistBookingPatientPage> {
  final supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _bookingsFuture = _fetchBookings();
  }

  Future<List<Map<String, dynamic>>> _fetchBookings() async {

    // Now fetch all bookings that match patient_id + clinic_id
    final response = await supabase
        .from('bookings')
        .select(
            'booking_id, patient_id, service_id, clinic_id, date, status, before_url, after_url, '
            'patients(firstname, lastname, email, phone), '
            'clinics(clinic_name),'
            'services(service_name, service_price)')
        .eq('clinic_id', widget.clinicId)
        .eq('patient_id', widget.patientId);

    return List<Map<String, dynamic>>.from(response);
  }


  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
        child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          "All Booked Appointments",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent, // Transparent AppBar
        elevation: 0, // Remove shadow
        iconTheme: const IconThemeData(color: Colors.white), // White icons
      ),
      body: Column(
        children: [
          // Booking list
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _bookingsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No bookings"));
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
                                  "Patient: ${booking['patients']['firstname']} ${booking['patients']['lastname']}"),
                              Text("Date: ${formatDateTime(booking['date'])}"),
                              if (booking['clinics'] != null)
                                Text(
                                    "Clinic: ${booking['clinics']['clinic_name']}"),
                              Text(
                                "Status: ${booking['status']}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: booking['status'] == 'approved'
                                      ? Colors.blueAccent
                                      : booking['status'] == 'pending'
                                          ? Colors.black
                                          : (booking['status'] == 'rejected' ||
                                                  booking['status'] ==
                                                      'cancelled')
                                              ? Colors.red
                                              : Colors.grey, // default fallback
                                ),
                              ),
                            ],
                          ),
                          trailing: GestureDetector(
                            onTap: () {
                              // Navigate to details page, passing the booking data
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BookingDetailsPage(
                                      booking: booking,
                                      clinicId: widget.clinicId),
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
          )
        ],
      ),
    ));
  }
}
