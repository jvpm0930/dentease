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
  final String clinicId;
  const DentistBookingPendPage({
    super.key,
    required this.clinicId,
  });

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
          'booking_id, patient_id, service_id, clinic_id, date, status, '
          'patients(firstname, lastname), services(service_name)',
        )
        .eq('status', 'pending')
        .eq('clinic_id', widget.clinicId);

    return response;
  }

  Future<void> _updateBookingStatus(String bookingId, String newStatus) async {
    await supabase
        .from('bookings')
        .update({'status': newStatus}).eq('booking_id', bookingId);

    setState(() {
      _bookingsFuture = _fetchBookings();
    });
  }

  // Helper for pull-to-refresh
  Future<void> _reload() async {
    setState(() {
      _bookingsFuture = _fetchBookings();
    });
    await _bookingsFuture;
  }

  // Smooth fade transition
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
            "Pending Appointments",
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
            // Segmented navigation (Approved, Pending, Rejected)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              child: Row(
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
                      isActive: true,
                      onPressed: null,
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
                          _fadeRoute(DentistBookingRejPage(
                            clinicId: widget.clinicId,
                          )),
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
                    return const Center(
                      child: Text(
                        "No pending bookings",
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  final bookings = snapshot.data!;

                  return RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: bookings.length,
                      itemBuilder: (context, index) {
                        final booking = bookings[index];
                        String currentStatus = booking['status'];

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title: Service name
                                Text(
                                  booking['services']?['service_name'] ??
                                      'Service',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Patient name and Date
                                Text(
                                  "Patient: ${(booking['patients']?['firstname'] ?? '')} ${(booking['patients']?['lastname'] ?? '')}"
                                      .trim(),
                                ),
                                Text(
                                    "Date: ${formatDateTime(booking['date'])}"),
                                const SizedBox(height: 8),

                                // Status dropdown & update button
                                Row(
                                  children: [
                                    const Text(
                                      "Status: ",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
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
                                      items: const [
                                        "pending",
                                        "approved",
                                        "rejected",
                                        "cancelled",
                                      ].map<DropdownMenuItem<String>>(
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

// Segmented button helper (consistent look)
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
