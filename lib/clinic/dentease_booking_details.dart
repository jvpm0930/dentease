import 'package:dentease/clinic/dentease_bills_page.dart';
import 'package:dentease/clinic/dentease_edit_bills.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String formatDateTime(String dateTime) {
  DateTime parsedDate = DateTime.parse(dateTime);
  return DateFormat('MMM d, y • h:mma').format(parsedDate).toLowerCase();
}

class BookingDetailsPage extends StatefulWidget {
  final Map<String, dynamic> booking;
  final String clinicId;

  const BookingDetailsPage({
    super.key,
    required this.booking,
    required this.clinicId,
  });

  @override
  State<BookingDetailsPage> createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  final supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;

    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            "Booking Details",
            style: TextStyle(color: Colors.white),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Service name: ${booking['services']['service_name']}",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text("Service price: ${booking['services']['service_price']} php"),
                const SizedBox(height: 8),
                Text(
                    "Patient name: ${booking['patients']['firstname']} ${booking['patients']['lastname']}"),
                const SizedBox(height: 8),
                Text("Patient email: ${booking['patients']['email']}"),
                const SizedBox(height: 8),
                Text("Patient phone #: ${booking['patients']['phone']}"),
                const SizedBox(height: 8),
                Text("Service date booked: ${formatDateTime(booking['date'])}"),
                const SizedBox(height: 20),
                const Divider(thickness: 1.5, color: Colors.white),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final patientId = booking['patient_id'];
                          final bookingId = booking['booking_id'];

                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BillCalculatorPage(
                                clinicId: widget.clinicId,
                                patientId: patientId,
                                bookingId: bookingId,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Send Bill"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final patientId = booking['patient_id'];
                          final bookingId = booking['booking_id'];

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditBillPage(
                                clinicId: widget.clinicId,
                                patientId: patientId,
                                bookingId: bookingId,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Edit Bill"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(thickness: 1.5, color: Colors.white),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, // Make the button full width
                  child: ElevatedButton(
                    onPressed: () {
                      final patientId = booking['patient_id'];
                      final bookingId = booking['booking_id'];
                      /*
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BillCalculatorPage(
                            clinicId: widget.clinicId,
                            patientId: patientId,
                            bookingId: bookingId,
                          ),
                        ),
                      );
                      */
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Receipt"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
