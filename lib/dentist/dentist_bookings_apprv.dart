import 'package:dentease/clinic/dentease_booking_details.dart';
import 'package:dentease/dentist/dentist_bookings_pend.dart';
import 'package:dentease/dentist/dentist_bookings_rej.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

String formatDateTime(String dateTime) {
  DateTime parsedDate = DateTime.parse(dateTime);
  return DateFormat('MMM d, y • h:mma').format(parsedDate).toLowerCase();
}

class DentistBookingApprvPage extends StatefulWidget {
  final String dentistId;
  final String clinicId;
  const DentistBookingApprvPage({
    super.key,
    required this.dentistId,
    required this.clinicId,
  });

  @override
  _DentistBookingApprvPageState createState() =>
      _DentistBookingApprvPageState();
}

class _DentistBookingApprvPageState extends State<DentistBookingApprvPage> {
  final supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  // Keep this as Future<void> so RefreshIndicator can call it
  Future<void> _fetchBookings() async {
    setState(() {
      _bookingsFuture = supabase
          .from('bookings')
          .select(
              'booking_id, patient_id, service_id, clinic_id, date, status, before_url, after_url, '
              'services(service_name, service_price), '
              'clinics(clinic_name), '
              'patients(firstname, lastname, email, phone)')
          .or('status.eq.approved, status.eq.completed')
          .eq('clinic_id', widget.clinicId);
    });
  }

  Future<void> _updateBookingStatus(String bookingId, String newStatus) async {
    await supabase
        .from('bookings')
        .update({'status': newStatus}).eq('booking_id', bookingId);
    // Refresh bookings list after update
    if (mounted) {
      setState(() {
        _bookingsFuture = supabase
            .from('bookings')
            .select(
                'booking_id, patient_id, service_id, clinic_id, date, status, before_url, after_url, '
                'services(service_name, service_price), '
                'clinics(clinic_name), '
                'patients(firstname, lastname, email, phone)')
            .or('status.eq.approved, status.eq.completed')
            .eq('clinic_id', widget.clinicId);
      });
    }
  }

  // Fade-only transition route (optional nicer nav)
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
    const kPrimary = Color(0xFF103D7E);

    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            "Approved Appointments",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Column(
          children: [
            // Segmented navigation (keep your page flow)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              child: Row(
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
                            DentistBookingPendPage(
                              clinicId: widget.clinicId,
                              dentistId: widget.dentistId,
                            ),
                          ),
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
                            DentistBookingRejPage(
                              clinicId: widget.clinicId,
                              dentistId: widget.dentistId,
                            ),
                          ),
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
                        String currentStatus = booking['status'];

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
                                Text(
                                    "Patient: ${(booking['patients']?['firstname'] ?? '')} ${(booking['patients']?['lastname'] ?? '')}"),
                                Text(
                                    "Date: ${formatDateTime(booking['date'])}"),
                                if (booking['clinics'] != null &&
                                    booking['clinics']['clinic_name'] != null)
                                  Text(
                                      "Clinic: ${booking['clinics']['clinic_name']}"),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Text("Status: "),
                                    DropdownButton<String>(
                                      value: currentStatus,
                                      onChanged: (newStatus) {
                                        if (newStatus != null) {
                                          setState(() {
                                            booking['status'] = newStatus;
                                            currentStatus = newStatus;
                                          });
                                        }
                                      },
                                      items: const ["approved", "completed"]
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
                                          booking['status'],
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: kPrimary,
                                        side: const BorderSide(color: kPrimary),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                      ),
                                      child: const Text("Update"),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: GestureDetector(
                              onTap: () {
                                final clinicId = booking['clinic_id'];
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => BookingDetailsPage(
                                      booking: booking,
                                      clinicId: clinicId,
                                    ),
                                  ),
                                );
                              },
                              child: const Padding(
                                padding: EdgeInsets.only(right: 10),
                                child:
                                    Icon(Icons.info, color: Color(0xFF103D7E)),
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
