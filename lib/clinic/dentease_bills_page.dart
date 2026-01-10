import 'dart:io';
import 'package:dentease/widgets/background_cont.dart';
import 'package:dentease/theme/app_theme.dart';
import 'package:dentease/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

class BillCalculatorPage extends StatefulWidget {
  final String clinicId;
  final String patientId;
  final String bookingId;
  final String serviceId;

  const BillCalculatorPage({
    super.key,
    required this.clinicId,
    required this.patientId,
    required this.bookingId,
    required this.serviceId,
  });

  @override
  State<BillCalculatorPage> createState() => _BillCalculatorPageState();
}

class _BillCalculatorPageState extends State<BillCalculatorPage> {
  final supabase = Supabase.instance.client;

  // Form
  final _formKey = GlobalKey<FormState>();

  // Controllers
  // Controllers
  final TextEditingController serviceNameController = TextEditingController();
  final TextEditingController servicePriceController = TextEditingController();
  final TextEditingController doctorFeeController =
      TextEditingController(); // Re-purposed for "Additional Items / Details"
  final TextEditingController additionalPriceController =
      TextEditingController(); // "Additional Item Price" (Number)
  // final TextEditingController medicineFeeController = TextEditingController(); // Removed
  final TextEditingController totalAmountController = TextEditingController();
  final TextEditingController receivedMoneyController = TextEditingController();

  double? change;
  bool loading = true;
  String? patientName;
  String? patientPhone;
  String? patientAge;
  File? _billImage;
  String? _uploadedImageUrl;
  bool _isSubmitting = false;

  String? selectedPaymentMode = 'Cash'; // Set Cash as default
  final List<String> paymentModes = [
    'Cash',
    'GCash',
    'PayMaya',
    'Go Tyme',
    'Bank Transfer',
    'Others'
  ];

  bool _hasShownWarning = false;

  @override
  void initState() {
    super.initState();
    _loadBill();
    _loadPatientName();
    receivedMoneyController.addListener(_calculateChange);
    additionalPriceController.addListener(_calculateTotal);
  }

  void _calculateTotal() {
    final sPrice = double.tryParse(servicePriceController.text) ?? 0;
    final addPrice = double.tryParse(additionalPriceController.text) ?? 0;
    final total = sPrice + addPrice;

    // Update total text
    if (double.tryParse(totalAmountController.text) != total) {
      totalAmountController.text = total.toStringAsFixed(2);
    }
    _calculateChange();
  }

  void _calculateChange() {
    final total = double.tryParse(totalAmountController.text) ?? 0;
    final received = double.tryParse(receivedMoneyController.text) ?? 0;

    if (received < total && !_hasShownWarning) {
      _hasShownWarning = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Received money must be greater than or equal to total amount."),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() => change = null);
      Future.delayed(const Duration(seconds: 2), () {
        _hasShownWarning = false;
      });
      return;
    }

    if (received >= total) {
      setState(() {
        change = received - total;
      });
    }
  }

  Future<void> _loadPatientName() async {
    try {
      // Fetch via bookings table to ensure RLS allows access
      // (Dentists can see bookings, and thus the linked patient details)
      final response = await supabase
          .from('bookings')
          .select('patients(firstname, lastname, phone, age)')
          .eq('booking_id', widget.bookingId)
          .maybeSingle();

      if (response != null && response['patients'] != null) {
        final p = response['patients'];
        setState(() {
          patientName = "${p['firstname']} ${p['lastname']}";
          patientPhone = p['phone'] ?? 'No phone';
          patientAge = p['age']?.toString() ?? 'Not specified';
        });
      } else {
        // Fallback to direct fetch if join fails for some reason
        final directResponse = await supabase
            .from('patients')
            .select('firstname, lastname, phone, age')
            .eq('patient_id', widget.patientId)
            .maybeSingle();

        if (directResponse != null) {
          setState(() {
            patientName =
                "${directResponse['firstname']} ${directResponse['lastname']}";
            patientPhone = directResponse['phone'] ?? 'No phone';
            patientAge = directResponse['age']?.toString() ?? 'Not specified';
          });
        } else {
          throw Exception("Patient not found");
        }
      }
    } catch (e) {
      debugPrint("Error loading patient: $e");
      setState(() {
        patientName = "Unknown Patient";
        patientPhone = "No phone";
        patientAge = "Not specified";
      });
    }
  }

  Future<void> _loadBill() async {
    try {
      final result = await supabase
          .from('services')
          .select('service_name, service_price')
          .eq('service_id', widget.serviceId)
          .maybeSingle();

      if (result != null) {
        serviceNameController.text = result['service_name'] ?? '';
        servicePriceController.text = (result['service_price'] != null)
            ? result['service_price'].toString()
            : '';

        // Auto-calculate total
        _calculateTotal();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No service found.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading bill: ${e.toString()}")),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  // Validators
  String? _requiredValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return null;
  }

  String? _numberValidator(String? v, {bool required = false}) {
    if ((v == null || v.trim().isEmpty)) {
      return required ? 'Required' : null;
    }
    final d = double.tryParse(v);
    if (d == null) return 'Enter a valid number';
    if (d < 0) return 'Must be >= 0';
    return null;
  }

  /// Pick image from camera or gallery
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _billImage = File(pickedFile.path);
      });
    }
  }

  /// Upload image to Supabase storage
  Future<String?> _uploadBillImage() async {
    if (_billImage == null) return null;

    try {
      final fileName =
          'bill_${widget.bookingId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await _billImage!.readAsBytes();

      await supabase.storage.from('bills').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      final publicUrl = supabase.storage.from('bills').getPublicUrl(fileName);
      debugPrint('Bill image uploaded successfully: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading bill image: $e');

      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading photo: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      return null;
    }
  }

  Future<void> _submitBill() async {
    // Ensure all required fields/validators pass before submit
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete all required fields.")),
      );
      return;
    }

    final serviceName = serviceNameController.text.trim();
    final servicePrice = servicePriceController.text.trim();
    final additionalPriceText = additionalPriceController.text.trim();
    // final medicineFee = medicineFeeController.text.trim(); // Removed
    final doctorFee =
        doctorFeeController.text.trim(); // Now "Additional Items / Details"
    if (serviceName.isEmpty || servicePrice.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter valid service data.")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final existingBill = await supabase
          .from('bills')
          .select()
          .eq('booking_id', widget.bookingId)
          .maybeSingle();

      if (existingBill != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("A bill already exists for this booking."),
          ),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      final receivedMoney = double.tryParse(receivedMoneyController.text) ?? 0;
      final totalAmount = double.tryParse(totalAmountController.text) ?? 0;

      if (receivedMoney < totalAmount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Received money must be greater than or equal to total amount."),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      final billChange = receivedMoney - totalAmount;

      // Upload bill image if available
      String? imageUrl;
      if (_billImage != null) {
        imageUrl = await _uploadBillImage();

        // Warn user if image upload failed but continue with bill submission
        if (imageUrl == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Warning: Receipt image could not be uploaded. Bill will be saved without image.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }

      final Map<String, dynamic> billData = {
        'service_id': widget.serviceId,
        'service_name': serviceName,
        'service_price': servicePrice,
        'medicine_fee': double.tryParse(additionalPriceText) ??
            0, // Saving Additional Price in medicine_fee column
        'doctor_fee':
            doctorFee, // Storing "details" in doctor_fee column for now (or rename col in DB if needed)
        'clinic_id': widget.clinicId,
        'patient_id': widget.patientId,
        'booking_id': widget.bookingId,
        'total_amount': totalAmount,
        'recieved_money': receivedMoney,
        'bill_change': billChange,
        'payment_mode': selectedPaymentMode,
        if (imageUrl != null) 'image_url': imageUrl,
      };

      await supabase.from('bills').insert(billData);

      // Update booking status to completed
      await supabase.from('bookings').update({
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('booking_id', widget.bookingId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Bill sent and treatment marked as completed!"),
            backgroundColor: Colors.green.shade600,
          ),
        );
        Navigator.pop(context, true); // Return true to refresh list
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Submission failed: $e")),
      );
      setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    serviceNameController.dispose();
    servicePriceController.dispose();
    // medicineFeeController.dispose();
    doctorFeeController.dispose();
    totalAmountController.dispose();
    receivedMoneyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            "Bill for ${patientName ?? 'Loading...'}",
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                physics: const BouncingScrollPhysics(),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    children: [
                      // Patient Information Card
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle(
                              icon: Icons.person,
                              title: 'Patient Information',
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(Icons.person, 'Name',
                                patientName ?? 'Loading...'),
                            _buildInfoRow(Icons.phone, 'Phone',
                                patientPhone ?? 'Loading...'),
                            _buildInfoRow(
                                Icons.cake, 'Age', patientAge ?? 'Loading...'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Service details
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle(
                              icon: Icons.design_services,
                              title: 'Service Details',
                            ),
                            const SizedBox(height: 12),
                            _buildFormField(
                              controller: serviceNameController,
                              label: 'Service Name',
                              icon: Icons.badge_outlined,
                              readOnly: true,
                            ),
                            const SizedBox(height: 10),
                            _buildFormField(
                              controller: servicePriceController,
                              label: 'Service Price',
                              icon: Icons.payments_outlined,
                              number: true,
                              readOnly: true,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Additional Items
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle(
                              icon: Icons.medical_services,
                              title: 'Additional Items / Details',
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller:
                                  doctorFeeController, // Repurposing doctorFee controller for details
                              keyboardType: TextInputType.multiline,
                              maxLines: 4,
                              minLines: 2,
                              decoration: InputDecoration(
                                labelText:
                                    "List used medicine, anesthesia, etc...",
                                prefixIcon: const Icon(Icons.list_alt,
                                    color: AppTheme.primaryBlue),
                                filled: true,
                                fillColor: Colors.white,
                                alignLabelWithHint: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildFormField(
                              controller: additionalPriceController,
                              label: 'Additional Fees',
                              icon: Icons.attach_money,
                              number: true,
                              validator: (v) => _numberValidator(v),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Payment
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle(
                              icon: Icons.payment_rounded,
                              title: 'Payment',
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue:
                                  selectedPaymentMode, // This will now default to 'Cash'
                              items: paymentModes
                                  .map(
                                    (mode) => DropdownMenuItem(
                                      value: mode,
                                      child: Text(mode),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedPaymentMode = value;
                                });
                              },
                              validator: (v) => v == null
                                  ? 'Please select a payment mode'
                                  : null,
                              decoration: InputDecoration(
                                labelText: "Mode of Payment",
                                prefixIcon: const Icon(Icons.credit_card),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildFormField(
                              controller: totalAmountController,
                              label: 'Total Amount',
                              icon: Icons.calculate_outlined,
                              number: true,
                              validator: (v) =>
                                  _numberValidator(v, required: true),
                            ),
                            const SizedBox(height: 10),
                            _buildFormField(
                              controller: receivedMoneyController,
                              label: 'Received Money',
                              icon: Icons.account_balance_wallet_outlined,
                              number: true,
                              validator: (v) =>
                                  _numberValidator(v, required: true),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Summary
                      _SectionCard(
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long,
                                color: AppTheme.primaryBlue),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                change != null
                                    ? CurrencyFormatter.formatPesoWithText(
                                        change!)
                                    : "Enter received amount to compute change",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: change != null
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: change != null
                                      ? Colors.green.shade700
                                      : Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Bill Photo Section
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle(
                              icon: Icons.camera_alt,
                              title: 'Bill Photo (Optional)',
                            ),
                            const SizedBox(height: 12),
                            if (_billImage != null)
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      _billImage!,
                                      width: double.infinity,
                                      height: 200,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _billImage = null;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _pickImage(ImageSource.camera),
                                    icon: const Icon(Icons.camera_alt),
                                    label: const Text('Take Photo'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryBlue,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _pickImage(ImageSource.gallery),
                                    icon: const Icon(Icons.photo_library),
                                    label: const Text('Gallery'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.textGrey,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitBill,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "Send Bill & Complete",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // Info row for patient details
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryBlue),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textGrey,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textDark,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // TextFormField with validator
  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool number = false,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      validator: validator,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryBlue),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.dividerColor),
        ),
      ),
    );
  }
}

// UI helpers
class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

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
