import 'package:dentease/theme/app_theme.dart';
import 'package:dentease/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

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
  // Use getter to avoid race condition with Supabase initialization
  SupabaseClient get supabase => Supabase.instance.client;

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
      if (mounted) {
        setState(() {
          loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading bill: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          "Booking Details",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Service Details Card
              _buildSectionCard(
                title: "Service Information",
                icon: Icons.medical_services_rounded,
                children: [
                  _buildDetailRow(
                      "Service Name", booking['services']['service_name']),
                  _buildDetailRow(
                      "Service Price",
                      CurrencyFormatter.formatPesoWithText(
                          booking['services']['service_price'])),
                  _buildDetailRow("Clinic", booking['clinics']['clinic_name']),
                  _buildDetailRow("Date", formatDateTime(booking['date'])),
                  _buildDetailRow("Status", booking['status'],
                      valueColor: booking['status'] == 'completed'
                          ? AppTheme.tealAccent
                          : AppTheme.primaryBlue),
                ],
              ),

              const SizedBox(height: 20),

              // Patient Details Card
              _buildSectionCard(
                title: "Patient Information",
                icon: Icons.person_rounded,
                children: [
                  _buildDetailRow("Name",
                      "${booking['patients']['firstname']} ${booking['patients']['lastname']}"),
                  _buildDetailRow("Email", booking['patients']['email']),
                  _buildDetailRow("Phone", booking['patients']['phone']),
                ],
              ),

              const SizedBox(height: 20),

              // Bill Details Card
              loading
                  ? Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.primaryBlue)),
                    )
                  : bill != null
                      ? Builder(
                          builder: (context) {
                            final currency = 'PHP';
                            // Handle Medicine Fee
                            final medFeeVal = bill!['medicine_fee'];
                            String displayMedFee = '0.00';
                            if (medFeeVal != null &&
                                medFeeVal.toString().trim().isNotEmpty) {
                              if (double.tryParse(medFeeVal.toString()) !=
                                  null) {
                                displayMedFee = medFeeVal.toString();
                              }
                            }

                            // Handle Doctor Fee / Additional Details
                            // We repurposed 'doctor_fee' to store "Additional Items / Details" text.
                            final docFeeVal = bill!['doctor_fee'];
                            String additionalDetails = '';

                            if (docFeeVal != null) {
                              final valStr = docFeeVal.toString();
                              final asNum = double.tryParse(valStr);
                              if (asNum == null) {
                                additionalDetails = valStr;
                              }
                            }

                            return _buildSectionCard(
                              title: "Bill Details",
                              icon: Icons.receipt_rounded,
                              children: [
                                _buildDetailRow(
                                    "Service Price",
                                    CurrencyFormatter.formatPesoWithText(
                                        bill!['service_price'] ?? 0)),
                                _buildDetailRow(
                                    "Additional Fees",
                                    CurrencyFormatter.formatPesoWithText(
                                        displayMedFee)),

                                // If there are text details, show them nicely
                                if (additionalDetails.isNotEmpty)
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.list,
                                            size: 18, color: AppTheme.textGrey),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Additional Items:',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppTheme.textGrey,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                additionalDetails,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.textDark,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                _buildDetailRow("Payment Method",
                                    bill!['payment_mode'] ?? 'N/A'),
                                const Divider(color: AppTheme.dividerColor),
                                _buildDetailRow(
                                  "Total Amount",
                                  "$currency ${bill!['total_amount'] ?? 0}",
                                  labelStyle: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textDark,
                                  ),
                                  valueStyle: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                                _buildDetailRow("Received",
                                    "$currency ${bill!['recieved_money'] ?? 0}"),
                                _buildDetailRow("Change",
                                    "$currency ${_calculateChange()}"),
                              ],
                            );
                          },
                        )
                      : _buildSectionCard(
                          title: "Bill Details",
                          icon: Icons.receipt_rounded,
                          children: [
                            Center(
                              child: Text(
                                "No bill found for this booking.",
                                style: GoogleFonts.poppins(
                                  color: AppTheme.textGrey,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),

              const SizedBox(height: 20),

              // Receipt Image Card (only show if bill exists with image)
              if (bill != null &&
                  bill!['image_url'] != null &&
                  (bill!['image_url'] as String).isNotEmpty)
                _buildSectionCard(
                  title: "Receipt Image",
                  icon: Icons.image_rounded,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FullScreenImage(
                              imageUrl: bill!['image_url'],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            bill!['image_url'],
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                      color: AppTheme.primaryBlue),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  color: AppTheme.errorColor
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.error_outline,
                                          color: AppTheme.errorColor, size: 40),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Failed to load image",
                                        style: GoogleFonts.poppins(
                                          color: AppTheme.errorColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Tap to view full size',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.textGrey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
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
    String label,
    String value, {
    TextStyle? labelStyle,
    TextStyle? valueStyle,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: labelStyle ??
                  GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textGrey,
                  ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: valueStyle ??
                  GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? AppTheme.textDark,
                  ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _calculateChange() {
    if (bill == null) return '0.00';

    final received =
        double.tryParse(bill!['recieved_money']?.toString() ?? '0') ?? 0;
    final total =
        double.tryParse(bill!['total_amount']?.toString() ?? '0') ?? 0;
    final change = received - total;

    return change.toStringAsFixed(2);
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.white, size: 60),
                    const SizedBox(height: 16),
                    Text(
                      "Failed to load image",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
