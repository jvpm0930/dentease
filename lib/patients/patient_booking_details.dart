import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String formatDateTime(String dateTime) {
  DateTime parsedDate = DateTime.parse(dateTime);
  return DateFormat('MMM d, y • h:mma').format(parsedDate).toLowerCase();
}

class PatientBookingDetailsPage extends StatefulWidget {
  final Map<String, dynamic> booking;
  final String clinicId;

  const PatientBookingDetailsPage({
    super.key,
    required this.booking,
    required this.clinicId,
  });

  @override
  State<PatientBookingDetailsPage> createState() =>
      _PatientBookingDetailsPageState();
}

class _PatientBookingDetailsPageState extends State<PatientBookingDetailsPage> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? bill;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadBill();
  }

  Future<void> _loadBill() async {
    try {
      final result = await supabase
          .from('bills')
          .select()
          .eq('booking_id', widget.booking['booking_id'])
          .maybeSingle();

      if (mounted) {
        setState(() {
          bill = result;
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading bill: $e")),
      );
    }
  }

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
                Text("Clinic name: ${booking['clinics']['clinic_name']}"),
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
                loading
                    ? const Center(child: CircularProgressIndicator())
                    : bill != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Bill Details:",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                  "Service Price: ${bill!['service_price']} php"),
                              const SizedBox(height: 4),
                              Text("Received: ${bill!['recieved_money']} php"),
                              const SizedBox(height: 4),
                              Text("Change: ${bill!['bill_change']} php"),
                            ],
                          )
                        : const Text(
                            "No bill found for this booking.",
                            style: TextStyle(color: Colors.white),
                          ),
                const SizedBox(height: 20),
                const Divider(thickness: 1.5, color: Colors.white),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
