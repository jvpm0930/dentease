import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:dentease/clinic/dentease_bills_page.dart';
import 'package:dentease/utils/currency_formatter.dart';

/// Dentist Patient Details Page - Shows full patient booking details
/// With option to mark as completed
class DentistPatientDetailsPage extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final String clinicId;

  const DentistPatientDetailsPage({
    super.key,
    required this.bookingData,
    required this.clinicId,
  });

  @override
  State<DentistPatientDetailsPage> createState() =>
      _DentistPatientDetailsPageState();
}

class _DentistPatientDetailsPageState extends State<DentistPatientDetailsPage> {
  final supabase = Supabase.instance.client;

  static const kPrimaryBlue = Color(0xFF0D2A7A);
  static const kTealAccent = Color(0xFF00BFA5);
  static const kBackground = Color(0xFFF5F7FA);

  Map<String, dynamic>? fullPatientData;
  Map<String, dynamic>? serviceData;
  Map<String, dynamic>? billData;
  bool isLoading = true;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadFullDetails();
  }

  Future<void> _loadFullDetails() async {
    try {
      final serviceId = widget.bookingData['service_id'];
      final bookingId = widget.bookingData['booking_id'];

      // Fetch full patient data via bookings to ensure RLS access
      final bookingPatientResult = await supabase
          .from('bookings')
          .select('patients(*)')
          .eq('booking_id', bookingId)
          .maybeSingle();

      final patientResult = bookingPatientResult?['patients'];

      // Fetch service data
      final serviceResult = await supabase
          .from('services')
          .select('*')
          .eq('service_id', serviceId)
          .maybeSingle();

      // Fetch bill if exists
      final billResult = await supabase
          .from('bills')
          .select('*')
          .eq('booking_id', bookingId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          fullPatientData = patientResult;
          serviceData = serviceResult;
          billData = billResult;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading patient details: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _markAsCompleted() async {
    // Navigate to Bill Page instead of showing dialog
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BillCalculatorPage(
          clinicId: widget.clinicId,
          patientId: widget.bookingData['patient_id'],
          bookingId: widget.bookingData['booking_id'],
          serviceId: widget.bookingData['service_id'],
        ),
      ),
    );

    // If bill was submitted successfully (result == true), refresh details
    if (result == true) {
      _loadFullDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.bookingData['status'] ?? 'pending';
    final canComplete = status == 'approved' || status == 'accepted';

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kPrimaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Patient Details',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient Header Card
                  _buildPatientHeaderCard(),

                  const SizedBox(height: 20),

                  // Appointment Details Card
                  _buildAppointmentCard(),

                  const SizedBox(height: 20),

                  // Service Details Card
                  _buildServiceCard(),

                  const SizedBox(height: 20),

                  // Contact Details Card
                  _buildContactCard(),

                  if (billData != null) ...[
                    const SizedBox(height: 20),
                    _buildBillCard(),
                  ],

                  // Mark as Completed Button
                  if (canComplete) ...[
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isProcessing ? null : _markAsCompleted,
                        icon: isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.receipt_long,
                                color: Colors.white),
                        label: Text(
                          isProcessing ? 'Processing...' : 'Send Billing Now',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildPatientHeaderCard() {
    final patientName =
        '${fullPatientData?['firstname'] ?? 'Unknown'} ${fullPatientData?['lastname'] ?? ''}'
            .trim();
    final profileUrl = fullPatientData?['profile_url'] as String?;
    final email = fullPatientData?['email'] ?? 'No email';
    final status = widget.bookingData['status'] ?? 'pending';

    Color statusColor;
    String statusText;
    switch (status) {
      case 'approved':
      case 'accepted':
        statusColor = Colors.green.shade600;
        statusText = 'Approved';
        break;
      case 'pending':
        statusColor = Colors.orange.shade600;
        statusText = 'Pending Request';
        break;
      case 'rejected':
        statusColor = Colors.red.shade600;
        statusText = 'Rejected';
        break;
      case 'completed':
        statusColor = Colors.blue.shade600;
        statusText = 'Completed';
        break;
      default:
        statusColor = Colors.grey.shade600;
        statusText = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimaryBlue, kPrimaryBlue.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kPrimaryBlue.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            backgroundImage:
                profileUrl != null ? NetworkImage(profileUrl) : null,
            child: profileUrl == null
                ? const Icon(Icons.person, size: 40, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patientName,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard() {
    // Handle both field names for compatibility
    final appointmentDate = (widget.bookingData['appointment_date'] ??
        widget.bookingData['date']) as String?;
    final createdAt = widget.bookingData['created_at'] as String?;

    final dateFormatted = appointmentDate != null
        ? DateFormat('EEEE, MMMM d, yyyy')
            .format(DateTime.parse(appointmentDate))
        : 'Not scheduled';
    final timeFormatted = appointmentDate != null
        ? DateFormat('h:mm a').format(DateTime.parse(appointmentDate))
        : 'Not scheduled';
    final bookedOn = createdAt != null
        ? DateFormat('MMM d, yyyy').format(DateTime.parse(createdAt))
        : 'Unknown';

    return _buildSectionCard(
      title: 'Appointment Details',
      icon: Icons.calendar_today_rounded,
      iconColor: kPrimaryBlue,
      children: [
        _buildDetailRow(
            Icons.calendar_month, 'Date', dateFormatted, kPrimaryBlue),
        _buildDetailRow(Icons.access_time, 'Time', timeFormatted, kTealAccent),
        _buildDetailRow(Icons.history, 'Booked On', bookedOn, Colors.grey),
      ],
    );
  }

  Widget _buildServiceCard() {
    final serviceName = serviceData?['service_name'] ?? 'Unknown Service';
    final serviceDetail = serviceData?['service_detail'] ?? '';
    final servicePrice = serviceData?['service_price']?.toString() ?? '0';

    return _buildSectionCard(
      title: 'Service Information',
      icon: Icons.medical_services_rounded,
      iconColor: Colors.purple,
      children: [
        _buildDetailRow(
            Icons.local_hospital, 'Service', serviceName, Colors.purple),
        if (serviceDetail.isNotEmpty)
          _buildDetailRow(Icons.description, 'Details', serviceDetail,
              Colors.grey.shade600),
        _buildDetailRow(Icons.payments, 'Price',
            CurrencyFormatter.formatPeso(servicePrice), kTealAccent),
      ],
    );
  }

  Widget _buildContactCard() {
    final phone = fullPatientData?['phone'] ?? 'No phone';
    final gender = fullPatientData?['gender'] ?? 'Not specified';
    final age = fullPatientData?['age']?.toString() ?? 'Not specified';

    return _buildSectionCard(
      title: 'Patient Information',
      icon: Icons.person_rounded,
      iconColor: kTealAccent,
      children: [
        _buildDetailRow(Icons.phone, 'Phone', phone, Colors.green),
        _buildDetailRow(Icons.wc, 'Gender', gender, Colors.indigo),
        _buildDetailRow(Icons.cake, 'Age', age, Colors.pink),
      ],
    );
  }

  Widget _buildBillCard() {
    // Handle Medicine Fee
    final medFeeVal = billData?['medicine_fee'];
    String displayMedFee = '0.00';
    if (medFeeVal != null && medFeeVal.toString().trim().isNotEmpty) {
      // If it looks like a number, use it. Otherwise 0.
      if (double.tryParse(medFeeVal.toString()) != null) {
        displayMedFee = medFeeVal.toString();
      }
    }

    // Handle Doctor Fee / Additional Details
    // We repurposed 'doctor_fee' to store "Additional Items / Details" text.
    final docFeeVal = billData?['doctor_fee'];
    String additionalDetails = '';

    if (docFeeVal != null) {
      final valStr = docFeeVal.toString();
      final asNum = double.tryParse(valStr);
      if (asNum == null) {
        // It's text, so it's details
        additionalDetails = valStr;
      }
    }

    // Get receipt image URL
    final receiptImageUrl = billData?['image_url'] as String?;

    return _buildSectionCard(
      title: 'Bill Details',
      icon: Icons.receipt_long_rounded,
      iconColor: Colors.orange,
      children: [
        _buildDetailRow(
            Icons.medical_services,
            'Service Price',
            CurrencyFormatter.formatPesoWithText(
                billData?['service_price'] ?? 0),
            Colors.grey),
        _buildDetailRow(Icons.add_circle, 'Additional Fees',
            CurrencyFormatter.formatPesoWithText(displayMedFee), Colors.grey),

        // If there are text details, show them
        if (additionalDetails.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.list, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Additional Items:',
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        additionalDetails,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        const Divider(height: 24),
        _buildDetailRow(
            Icons.account_balance_wallet,
            'Total',
            CurrencyFormatter.formatPesoWithText(
                billData?['total_amount'] ?? 0),
            kPrimaryBlue,
            isBold: true),
        _buildDetailRow(Icons.payment, 'Payment Method',
            billData?['payment_mode'] ?? 'N/A', Colors.grey),

        const SizedBox(height: 8),
        _buildDetailRow(
            Icons.input,
            'Received',
            CurrencyFormatter.formatPesoWithText(
                billData?['recieved_money'] ?? 0),
            Colors.green),
        _buildDetailRow(
            Icons.change_circle,
            'Change',
            CurrencyFormatter.formatPesoWithText(_calculateChange()),
            Colors.orange),

        // Receipt Image
        if (receiptImageUrl != null && receiptImageUrl.isNotEmpty) ...[
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.image, size: 18, color: Colors.purple.shade600),
                    const SizedBox(width: 12),
                    Text(
                      'Receipt Image',
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _showFullScreenImage(receiptImageUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      receiptImageUrl,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 200,
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 100,
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Tap to view full size',
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(
      IconData icon, String label, String value, Color iconColor,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.roboto(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: isBold ? kPrimaryBlue : const Color(0xFF1E293B),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _calculateChange() {
    if (billData == null) return '0.00';

    final received =
        double.tryParse(billData!['recieved_money']?.toString() ?? '0') ?? 0;
    final total =
        double.tryParse(billData!['total_amount']?.toString() ?? '0') ?? 0;
    final change = received - total;

    return change.toStringAsFixed(2);
  }
}
