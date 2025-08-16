import 'package:dentease/clinic/dentease_booking_details.dart';
import 'package:dentease/staff/staff_bookings_pend.dart';
import 'package:dentease/staff/staff_bookings_rej.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

String formatDateTime(String dateTime) {
  DateTime parsedDate = DateTime.parse(dateTime);
  return DateFormat('MMM d, y • h:mma').format(parsedDate).toLowerCase();
}

class StaffBookingApprvPage extends StatefulWidget {
  final String staffId;
  final String clinicId;
  const StaffBookingApprvPage({super.key, required this.staffId, required this.clinicId});

  @override
  _StaffBookingApprvPageState createState() =>
      _StaffBookingApprvPageState();
}

class _StaffBookingApprvPageState extends State<StaffBookingApprvPage> {
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
        .select('booking_id, patient_id, service_id, clinic_id, date, status, patients(firstname, lastname, email, phone), services(service_name, service_price)')
        .eq('status', 'approved')
        .eq('clinic_id', widget.clinicId); // Filters bookings by clinicId

    return response;
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
                    onPressed:
                        null, //  Disable the "Approved" button in this page
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300], // Disabled background
                      foregroundColor: Colors.white, // Disabled text color
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
                          builder: (context) => StaffBookingPendPage(
                              clinicId: widget.clinicId,
                              staffId: widget.staffId),
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
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StaffBookingRejPage(
                              clinicId: widget.clinicId,
                              staffId: widget.staffId),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue, // Active color
                      foregroundColor: Colors.white, // Active text color
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
                                  "Patient: ${booking['patients']['firstname']}"),
                              Text("Date: ${formatDateTime(booking['date'])}"),
                              if (booking['clinics'] != null)
                                Text(
                                    "Clinic: ${booking['clinics']['clinic_name']}"),
                              Text("Status: ${booking['status']}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
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
