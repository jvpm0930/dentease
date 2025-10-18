import 'package:dentease/clinic/dentease_bills_page.dart';
import 'package:dentease/clinic/dentease_edit_bills.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'dart:async';

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

  Map<String, dynamic>? bill;
  bool loading = true;
  bool uploading = false;


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

  Future<void> _beforeImageandUpload() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);

    if (image == null) return; // user cancelled

    setState(() => uploading = true);

    try {
      final fileExt = path.extension(image.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$fileExt';
      final bookingId = widget.booking['booking_id'];
      final filePath = 'before/$bookingId/$fileName';

      // Upload to Supabase Storage (bucket name must exist)
      await supabase.storage.from('before').upload(filePath, File(image.path));

      // Get public URL
      final publicUrl = supabase.storage.from('before').getPublicUrl(filePath);

      // Update the bookings table with URL
      await supabase.from('bookings').update({
        'before_url': publicUrl,
      }).eq('booking_id', bookingId);

      // Refresh booking data
      final updatedBooking = await supabase
          .from('bookings')
          .select('before_url')
          .eq('booking_id', bookingId)
          .single();

      setState(() {
        widget.booking['before_url'] = updatedBooking['before_url'];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Photo uploaded successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error uploading photo: $e")),
      );
    } finally {
      setState(() => uploading = false);
    }
  }

  Future<void> _afterImageandUpload() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);

    if (image == null) return; // user cancelled

    setState(() => uploading = true);

    try {
      final fileExt = path.extension(image.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$fileExt';
      final bookingId = widget.booking['booking_id'];
      final filePath = 'after/$bookingId/$fileName';

      // Upload to Supabase Storage (bucket name must exist)
      await supabase.storage.from('after').upload(filePath, File(image.path));

      // Get public URL
      final publicUrl = supabase.storage.from('after').getPublicUrl(filePath);

      // Update the bookings table with URL
      await supabase.from('bookings').update({
        'after_url': publicUrl,
      }).eq('booking_id', bookingId);

      // Refresh booking data
      final updatedBooking = await supabase
          .from('bookings')
          .select('after_url')
          .eq('booking_id', bookingId)
          .single();

      setState(() {
        widget.booking['after_url'] = updatedBooking['after_url'];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Photo uploaded successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error uploading photo: $e")),
      );
    } finally {
      setState(() => uploading = false);
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
                _buildDetailRow(
                  "Service name:",
                  booking['services']['service_name'],
                  labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                _buildDetailRow("Service price:",
                    "${booking['services']['service_price']} php"),
                _buildDetailRow("Patient name:",
                    "${booking['patients']['firstname']} ${booking['patients']['lastname']}"),
                _buildDetailRow("Patient email:", booking['patients']['email']),
                _buildDetailRow(
                    "Patient phone number:", booking['patients']['phone']),
                _buildDetailRow(
                    "Service date booked:", formatDateTime(booking['date'])),
                const SizedBox(height: 20),
                const Divider(thickness: 1.5, color: Colors.blueGrey),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final patientId = booking['patient_id'];
                          final serviceId = booking['service_id'];
                          final bookingId = booking['booking_id'];

                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BillCalculatorPage(
                                clinicId: widget.clinicId,
                                patientId: patientId,
                                serviceId: serviceId,
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
                const Divider(thickness: 1.5, color: Colors.blueGrey),
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
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Each label/value pair is a Row
                            _buildDetailRow("Service name:", booking['services']['service_name']),
                            _buildDetailRow("Service Price:", "${bill!['service_price']}"),
                            _buildDetailRow("Medicine fee:", "${bill!['medicine_fee']}"),
                            _buildDetailRow("Additional fee:", "${bill!['doctor_fee']}"),
                            _buildDetailRow("Payment Method:", "${bill!['payment_mode']}"),
                            _buildDetailRow("Total Amount:", "${bill!['total_amount']}"),
                            _buildDetailRow("Received:", "${bill!['recieved_money']}"),
                            _buildDetailRow("Change:", "${bill?['bill_change'] ?? 'None'}"),
                          ],
                        )
                        : const Text(
                            "No bill found for this booking.",
                            style: TextStyle(color: Colors.white),
                          ),
                const SizedBox(height: 20),
                const Divider(thickness: 1.5, color: Colors.blueGrey),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _beforeImageandUpload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                        ),
                        child: Text("Before Service Photo"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:  _afterImageandUpload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                        ),
                        child: Text("After Service Photo"),
                      ),
                    ),
                  ],
                ),                
                const SizedBox(height: 20),
                const Divider(thickness: 1.5, color: Colors.blueGrey),
                const SizedBox(height: 20),
                const Text(
                  'Before Service Image:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                if (booking['before_url'] != null &&
                    (booking['before_url'] as String).isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FullScreenImage(
                                imageUrl: booking['before_url'],
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            booking['before_url'],
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  const Text(
                    "No before services image is available.",
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                const SizedBox(height: 20),
                const Divider(thickness: 1.5, color: Colors.blueGrey),
                const SizedBox(height: 20),
                const Text(
                  'After Service Image:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                if (booking['after_url'] != null &&
                    (booking['after_url'] as String).isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FullScreenImage(
                                imageUrl: booking['after_url'],
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            booking['after_url'],
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  const Text(
                    "No after services image is available.",
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildDetailRow(
  String label,
  String value, {
  TextStyle? labelStyle,
  TextStyle? valueStyle,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: labelStyle ??
                const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: valueStyle ??
                const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    ),
  );
}

class FullScreenImage extends StatelessWidget {
  final String imageUrl;
  const FullScreenImage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(imageUrl, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

