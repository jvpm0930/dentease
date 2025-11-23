import 'package:dentease/dentist/dentist_bookings_apprv.dart';
import 'package:dentease/dentist/dentist_bookings_pend.dart';
import 'package:dentease/dentist/dentist_rej-can.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

String formatDateTime(String dateTime) {
  DateTime parsedDate = DateTime.parse(dateTime);
  return DateFormat('MMM d, y • h:mma').format(parsedDate).toLowerCase();
}

class DentistBookingRejPage extends StatefulWidget {
  final String clinicId;
  const DentistBookingRejPage({
    super.key,
    required this.clinicId,
  });

  @override
  _DentistBookingRejPageState createState() => _DentistBookingRejPageState();
}

class _DentistBookingRejPageState extends State<DentistBookingRejPage> {
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
          'booking_id, patient_id, service_id, clinic_id, date, status, '
          'patients(firstname, lastname), clinics(clinic_name), services(service_name)',
        )
        .or('status.eq.rejected, status.eq.cancelled')
        .eq('clinic_id', widget.clinicId);
    return response;
  }

  // Fade-only transition (match Patient UI)
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
            "Rejected/Cancelled Appointments",
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
            // Segmented navigation (Approved, Pending, Rejected) — match Patient UI
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: _segButton(
                      label: "Approved",
                      isActive: false,
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          _fadeRoute(DentistBookingApprvPage(
                            clinicId: widget.clinicId,
                          )),
                        );
                      },
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
                          _fadeRoute(DentistBookingPendPage(
                            clinicId: widget.clinicId,
                          )),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _segButton(
                      label: "Rejected",
                      isActive: true, // current page
                      onPressed: null,
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
                    return const Center(
                      child: Text("No rejected/cancelled bookings"),
                    );
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
                            booking['services']?['service_name'] ?? 'Service',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Date: ${formatDateTime(booking['date'])}"),
                              if (booking['clinics'] != null &&
                                  booking['clinics']['clinic_name'] != null)
                                Text(
                                    "Clinic: ${booking['clinics']['clinic_name']}"),
                              Text(
                                "Status: ${booking['status']}",
                                style: const TextStyle(
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
                                _fadeRoute(
                                  DentistRejectedCancelledBookingsPage(
                                    booking: booking,
                                  ),
                                ),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(right: 10),
                              child: Icon(Icons.info, color: Color(0xFF103D7E)),
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
  final inactiveBg = const Color.fromARGB(0, 255, 255, 255);
  final inactiveFg = const Color.fromARGB(74, 0, 0, 0);

  return ElevatedButton(
    onPressed: isActive ? null : onPressed,
    style: ElevatedButton.styleFrom(
      disabledBackgroundColor: isActive ? activeBg : null,
      disabledForegroundColor: isActive ? activeFg : null,
      backgroundColor: isActive ? null : inactiveBg,
      foregroundColor: isActive ? null : inactiveFg,
    ),
    child: Text(label),
  );
}
