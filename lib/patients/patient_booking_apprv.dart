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
          .select(
              'booking_id, patient_id, service_id, clinic_id, date, status, before_url, after_url, services(service_name, service_price), clinics(clinic_name), patients(firstname, lastname, email, phone)')
          .or('status.eq.approved, status.eq.completed')
          .eq('patient_id', widget.patientId);
    });
  }

  // Fade-only transition route
  Route<T> _fadeRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fade =
            CurvedAnimation(parent: animation, curve: Curves.easeInOut);
        return FadeTransition(opacity: fade, child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            "Approved Appointments",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Column(
          children: [
            // Buttons for switching between Approved, Pending, Rejected
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: _segButton(
                      label: "Approved",
                      isActive: true, // current page
                      onPressed: null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _segButton(
                      label: "Pending",
                      isActive: false,
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          _fadeRoute(
                              PatientBookingPend(patientId: widget.patientId)),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _segButton(
                      label: "Rejected",
                      isActive: false,
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          _fadeRoute(
                              PatientBookingRej(patientId: widget.patientId)),
                        );
                      },
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
                                        ? const Color(0xFF103D7E)
                                        : booking['status'] == 'completed'
                                            ? Colors.green
                                            : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            trailing: GestureDetector(
                              onTap: () {
                                final clinicId = booking['clinic_id'];
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        PatientBookingDetailsPage(
                                      booking: booking,
                                      clinicId: clinicId,
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
Widget _segButton({
  required String label,
  required bool isActive,
  required VoidCallback? onPressed,
}) {
  const activeBg = Color(0xFF103D7E);
  const activeFg = Colors.white;
  final inactiveBg = const Color.fromARGB(0, 255, 255, 255)!;
  final inactiveFg = const Color.fromARGB(74, 0, 0, 0)!;

  return ElevatedButton(
    onPressed: isActive ? null : onPressed,
    style: ElevatedButton.styleFrom(
      // When active (current page), we disable the button but style it as active
      disabledBackgroundColor: isActive ? activeBg : null,
      disabledForegroundColor: isActive ? activeFg : null,
      // When inactive (other pages), make it look like a disabled/grey button but clickable
      backgroundColor: isActive ? null : inactiveBg,
      foregroundColor: isActive ? null : inactiveFg,
    ),
    child: Text(label),
  );
}
