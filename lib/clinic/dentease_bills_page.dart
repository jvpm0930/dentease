import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final TextEditingController serviceNameController = TextEditingController();
  final TextEditingController servicePriceController = TextEditingController();
  final TextEditingController doctorFeeController = TextEditingController();
  final TextEditingController medicineFeeController = TextEditingController();
  final TextEditingController totalAmountController = TextEditingController();
  final TextEditingController receivedMoneyController = TextEditingController();

  double? change;
  bool loading = true;
  String? patientName;

  String? selectedPaymentMode;
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
      final response = await supabase
          .from('patients')
          .select('firstname, lastname')
          .eq('patient_id', widget.patientId)
          .single();

      setState(() {
        patientName = "${response['firstname']} ${response['lastname']}";
      });
    } catch (e) {
      setState(() {
        patientName = "Unknown Patient";
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

  Future<void> _submitBill() async {
    // Ensure all required fields/validators pass before submit
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete all required fields.")),
      );
      return;
    }

    final serviceName = serviceNameController.text.trim();
    final servicePrice =servicePriceController.text.trim();
    final medicineFee = double.tryParse(
            medicineFeeController.text.trim().isEmpty
                ? '0'
                : medicineFeeController.text.trim()) ??
        0;
    final doctorFee = double.tryParse(doctorFeeController.text.trim().isEmpty
            ? '0'
            : doctorFeeController.text.trim()) ??
        0;

    if (serviceName.isEmpty || servicePrice.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter valid service data.")),
      );
      return;
    }

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
        return;
      }

      final billChange = receivedMoney - totalAmount;

      final Map<String, dynamic> billData = {
        'service_id': widget.serviceId,
        'service_name': serviceName,
        'service_price': servicePrice,
        'medicine_fee': medicineFee,
        'doctor_fee': doctorFee,
        'clinic_id': widget.clinicId,
        'patient_id': widget.patientId,
        'booking_id': widget.bookingId,
        'total_amount': totalAmount,
        'recieved_money': receivedMoney,
        'bill_change': billChange,
        'payment_mode': selectedPaymentMode,
      };

      await supabase.from('bills').insert(billData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bill submitted successfully.")),
      );

      serviceNameController.clear();
      servicePriceController.clear();
      medicineFeeController.clear();
      doctorFeeController.clear();
      receivedMoneyController.clear();
      setState(() {
        selectedPaymentMode = null;
        totalAmountController.clear();
        change = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Submission failed: $e")),
      );
    }
  }

  @override
  void dispose() {
    serviceNameController.dispose();
    servicePriceController.dispose();
    medicineFeeController.dispose();
    doctorFeeController.dispose();
    totalAmountController.dispose();
    receivedMoneyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const kPrimary = Color(0xFF103D7E);

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
                              readOnly: true,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Fees
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle(
                              icon: Icons.medical_services,
                              title: 'Fees',
                            ),
                            const SizedBox(height: 12),
                            _buildFormField(
                              controller: medicineFeeController,
                              label: 'Medicine Fee',
                              icon: Icons.local_pharmacy_outlined,
                              number: true,
                              validator: (v) =>
                                  _numberValidator(v, required: false),
                            ),
                            const SizedBox(height: 10),
                            _buildFormField(
                              controller: doctorFeeController,
                              label: 'Additional Fee',
                              icon: Icons.medical_services_outlined,
                              number: true,
                              validator: (v) =>
                                  _numberValidator(v, required: false),
                            )
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
                              value: selectedPaymentMode,
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
                            const Icon(Icons.receipt_long, color: kPrimary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                change != null
                                    ? "Change: PHP ${change!.toStringAsFixed(2)}"
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

                      const SizedBox(height: 18),

                      // Submit
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitBill,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: const Text(
                            "Submit Bill",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
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
        prefixIcon: Icon(icon, color: const Color(0xFF103D7E)),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
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
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF103D7E);
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
