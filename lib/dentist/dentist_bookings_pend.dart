import 'package:dentease/dentist/dentist_bookings_apprv.dart';
import 'package:dentease/dentist/dentist_bookings_rej.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

String formatDateTime(String dateTime) {
  DateTime parsedDate = DateTime.parse(dateTime);
  return DateFormat('MMM d, y • h:mma').format(parsedDate).toLowerCase();
}

class DentistBookingPendPage extends StatefulWidget {
  final String dentistId;
  final String clinicId;
  const DentistBookingPendPage({super.key,  required this.dentistId, required this.clinicId});

  @override
  _DentistBookingPendPageState createState() => _DentistBookingPendPageState();
}

class _DentistBookingPendPageState extends State<DentistBookingPendPage> {
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
            'booking_id, patient_id, service_id, clinic_id, date, status, patients(firstname), services(service_name)')
        .or('status.eq.pending')
        .eq('clinic_id', widget.clinicId); // Filters bookings by clinicId

    return response;
  }


  Future<void> _updateBookingStatus(String bookingId, String newStatus) async {
    await supabase
        .from('bookings')
        .update({'status': newStatus}).eq('booking_id', bookingId);

    // Refresh bookings list after update
    setState(() {
      _bookingsFuture = _fetchBookings();
    });
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
        backgroundColor: Colors.transparent, // Transparent AppBar
        elevation: 0, // Remove shadow
        iconTheme: const IconThemeData(color: Colors.white), // White icons
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
                          builder: (context) => DentistBookingApprvPage(
                              clinicId: widget.clinicId,
                              dentistId: widget.dentistId),
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
                    onPressed:
                        null, // 🔹 Disable the "Pending" button in this page
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300], // Disabled background
                      foregroundColor: Colors.white, // Disabled text color
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
                          builder: (context) => DentistBookingRejPage(
                              clinicId: widget.clinicId,
                              dentistId: widget.dentistId),
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
                  return const Center(child: Text("No pending bookings"));
                }

                final bookings = snapshot.data!;

                return ListView.builder(
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final booking = bookings[index];
                    String currentStatus = booking['status'];

                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking['services']['service_name'],
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 5),
                            Text(
                                "Patient: ${booking['patients']['firstname']}"),
                            Text("Date: ${formatDateTime(booking['date'])}"),
                            const SizedBox(height: 5),

                            // Status dropdown & update button
                            Row(
                              children: [
                                const Text("Status: "),
                                DropdownButton<String>(
                                  value: currentStatus,
                                  onChanged: (newStatus) {
                                    if (newStatus != null) {
                                      setState(() {
                                        booking['status'] = newStatus;
                                      });
                                    }
                                  },
                                  items: ["pending", "approved", "rejected"]
                                      .map<DropdownMenuItem<String>>(
                                          (String status) {
                                    return DropdownMenuItem<String>(
                                      value: status,
                                      child: Text(status),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: () {
                                    _updateBookingStatus(
                                        booking['booking_id'].toString(),
                                        booking['status']);
                                  },
                                  child: const Text(
                                    "Update",
                                    style: TextStyle(color: Colors.blue),
                                  ),
                                ),
                              ],
                            ),
                          ],
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
