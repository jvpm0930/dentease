import 'package:dentease/clinic/dentease_bills_page.dart';
import 'package:dentease/clinic/dentease_edit_bills.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

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
      if (!mounted) return;
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

    if (image == null) return;

    setState(() => uploading = true);

    try {
      final fileExt = path.extension(image.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$fileExt';
      final bookingId = widget.booking['booking_id'];
      final filePath = 'before/$bookingId/$fileName';

      await supabase.storage.from('before').upload(filePath, File(image.path));

      final publicUrl = supabase.storage.from('before').getPublicUrl(filePath);

      await supabase
          .from('bookings')
          .update({'before_url': publicUrl}).eq('booking_id', bookingId);

      final updatedBooking = await supabase
          .from('bookings')
          .select('before_url')
          .eq('booking_id', bookingId)
          .single();

      setState(() {
        widget.booking['before_url'] = updatedBooking['before_url'];
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Photo uploaded successfully!")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error uploading photo: $e")),
      );
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  // Reusable photo tile (Before/After)
  Widget _photoTile({
    required String title,
    required String? url,
    required VoidCallback onCapture,
  }) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(icon: Icons.photo_camera_outlined, title: title),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              height: 180,
              color: Colors.grey.shade100,
              child: (url != null && url.isNotEmpty)
                  ? GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FullScreenImage(imageUrl: url),
                          ),
                        );
                      },
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imagePlaceholder(),
                      ),
                    )
                  : _imagePlaceholder(),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: uploading ? null : onCapture,
              icon: const Icon(Icons.camera_alt, color: Colors.white),
              label: const Text('Take A Photo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppTheme.primaryBlue,
                side: const BorderSide(color: AppTheme.primaryBlue),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.image_not_supported_outlined, color: Colors.black38),
          SizedBox(height: 6),
          Text('No image', style: TextStyle(color: Colors.black45)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;

    final serviceName =
        booking['services']?['service_name']?.toString() ?? 'N/A';
    final servicePrice =
        booking['services']?['service_price']?.toString() ?? 'N/A';
    final patientName =
        "${booking['patients']?['firstname'] ?? ''} ${booking['patients']?['lastname'] ?? ''}"
            .trim();
    final patientEmail = booking['patients']?['email']?.toString() ?? 'N/A';
    final patientPhone = booking['patients']?['phone']?.toString() ?? 'N/A';
    final patientAge =
        booking['patients']?['age']?.toString() ?? 'Not specified';
    final dateBooked = booking['date']?.toString() ?? '';

    final beforeUrl = booking['before_url']?.toString();

    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            "Booking Details",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Appointment Summary
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle(
                          icon: Icons.event_note_rounded,
                          title: 'Appointment Summary',
                        ),
                        const SizedBox(height: 10),
                        _buildDetailRow(
                          "Service name:",
                          serviceName,
                          labelStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        _buildDetailRow("Service price:", servicePrice),
                        _buildDetailRow("Patient name:", patientName),
                        _buildDetailRow("Patient email:", patientEmail),
                        _buildDetailRow("Patient phone number:", patientPhone),
                        _buildDetailRow("Patient age:", patientAge),
                        if (dateBooked.isNotEmpty)
                          _buildDetailRow("Service date booked:",
                              formatDateTime(dateBooked)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Billing Actions
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle(
                          icon: Icons.request_page_outlined,
                          title: 'Billing',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
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
                                  backgroundColor: AppTheme.primaryBlue,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.receipt_long),
                                label: const Text("Send Billing Now"),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
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
                                  backgroundColor: AppTheme.primaryBlue,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.edit),
                                label: const Text("Edit Bill"),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Bill Details
                  _SectionCard(
                    child: loading
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : (bill != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _SectionTitle(
                                    icon: Icons.receipt_long_outlined,
                                    title: 'Bill Details',
                                  ),
                                  const SizedBox(height: 10),
                                  _buildDetailRow("Service name:", serviceName),
                                  _buildDetailRow("Service Price:",
                                      "${bill!['service_price']}"),
                                  _buildDetailRow("Additional Fees:",
                                      "${bill!['medicine_fee']}"),
                                  _buildDetailRow("Payment Method:",
                                      "${bill!['payment_mode']}"),
                                  _buildDetailRow("Total Amount:",
                                      "${bill!['total_amount']}"),
                                  _buildDetailRow("Received:",
                                      "${bill!['recieved_money']}"),
                                  _buildDetailRow("Change:",
                                      "${bill?['bill_change'] ?? 'None'}"),
                                ],
                              )
                            : const Text(
                                "No bill found for this booking.",
                                style: TextStyle(color: Colors.black54),
                              )),
                  ),
                  const SizedBox(height: 12),

                  // Bill Receipt Image - prioritize bill image_url over before_url
                  _photoTile(
                    title: 'Bill Receipt',
                    url: bill != null && bill!['image_url'] != null
                        ? bill!['image_url'].toString()
                        : beforeUrl,
                    onCapture: _beforeImageandUpload,
                  ),
                  const SizedBox(height: 54),
                ],
              ),
            ),

            // Uploading overlay
            if (uploading)
              Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
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
    padding: const EdgeInsets.symmetric(vertical: 6.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: labelStyle ??
                const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black54,
                ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: valueStyle ??
                const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    ),
  );
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryBlue),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textDark,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
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
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 3.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image,
              color: Colors.white70,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}
