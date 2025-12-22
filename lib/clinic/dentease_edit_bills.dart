import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditBillPage extends StatefulWidget {
  final String clinicId;
  final String patientId;
  final String bookingId;

  const EditBillPage({
    super.key,
    required this.clinicId,
    required this.patientId,
    required this.bookingId,
  });

  @override
  State<EditBillPage> createState() => _EditBillPageState();
}

class _EditBillPageState extends State<EditBillPage> {
  final supabase = Supabase.instance.client;

  final TextEditingController serviceNameController = TextEditingController();
  final TextEditingController servicePriceController = TextEditingController();
  final TextEditingController doctorFeeController = TextEditingController();
  final TextEditingController medicineFeeController = TextEditingController();
  final TextEditingController receivedMoneyController = TextEditingController();
  final TextEditingController totalController = TextEditingController();
  final TextEditingController changeController = TextEditingController();

  String? selectedPaymentMode;
  String? billId;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadBill();

    totalController.addListener(_calculateChange);
    receivedMoneyController.addListener(_calculateChange);
  }

  void _calculateChange() {
    final total = double.tryParse(totalController.text) ?? 0;
    final received = double.tryParse(receivedMoneyController.text) ?? 0;

    if (received >= total) {
      final change = received - total;
      setState(() {
        changeController.text = change.toStringAsFixed(2);
      });
    } else {
      setState(() {
        changeController.text = '';
      });
    }
  }

  Future<void> _loadBill() async {
    try {
      final result = await supabase
          .from('bills')
          .select()
          .eq('booking_id', widget.bookingId)
          .maybeSingle();

      if (result != null) {
        billId = result['id']?.toString();
        serviceNameController.text = result['service_name'] ?? '';
        servicePriceController.text = result['service_price']?.toString() ?? '';
        doctorFeeController.text = result['doctor_fee']?.toString() ?? '';
        medicineFeeController.text = result['medicine_fee']?.toString() ?? '';
        receivedMoneyController.text =
            result['recieved_money']?.toString() ?? '';
        totalController.text = result['total_amount']?.toString() ?? '';
        changeController.text = result['bill_change']?.toString() ?? '';
        selectedPaymentMode = result['payment_mode'];
      }

      setState(() => loading = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading bill: $e")),
      );
      setState(() => loading = false);
    }
  }

  Future<void> _updateBill() async {
    final serviceName = serviceNameController.text.trim();
    final servicePrice = servicePriceController.text.trim();
    final medicineFee = medicineFeeController.text.trim();
    final doctorFee = doctorFeeController.text.trim();
    final receivedMoney = double.tryParse(receivedMoneyController.text);
    final totalAmount = double.tryParse(totalController.text);
    final billChange = double.tryParse(changeController.text);

    if (serviceName.isEmpty ||
        receivedMoney == null ||
        totalAmount == null ||
        billChange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter valid inputs.")),
      );
      return;
    }

    if (selectedPaymentMode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a payment mode.")),
      );
      return;
    }

    if (receivedMoney < totalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Received money cannot be less than total amount."),
        ),
      );
      return;
    }

    try {
      await supabase.from('bills').update({
        'service_name': serviceName,
        'service_price': servicePrice,
        'doctor_fee': doctorFee,
        'medicine_fee': medicineFee,
        'recieved_money': receivedMoney,
        'bill_change': billChange,
        'total_amount': totalAmount,
        'payment_mode': selectedPaymentMode,
      }).eq('booking_id', widget.bookingId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bill updated successfully.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Dind't update bill.")),
      );
    }
  }

  @override
  void dispose() {
    serviceNameController.dispose();
    servicePriceController.dispose();
    doctorFeeController.dispose();
    medicineFeeController.dispose();
    receivedMoneyController.dispose();
    totalController.dispose();
    changeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const kPrimary = Color(0xFF103D7E);

    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            "Edit Bill",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                          _buildTextField(
                            serviceNameController,
                            'Service Name',
                            Icons.badge_outlined,
                            readOnly: true,
                          ),
                          const SizedBox(height: 10),
                          _buildTextField(
                            servicePriceController,
                            'Service Price',
                            Icons.sell_outlined, // no dollar icon
                            number: true,
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
                            icon: Icons.rule_folder_outlined,
                            title: 'Fees',
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            medicineFeeController,
                            'Medicine Fee',
                            Icons.medication, // medical icon
                          ),
                          const SizedBox(height: 10),
                          _buildTextField(
                            doctorFeeController,
                            'Additional Fee',
                            Icons.home_repair_service, // neutral icon
                            minLines: 1,
                            maxLines: 5,
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
                            decoration: InputDecoration(
                              labelText: "Payment Mode",
                              prefixIcon: const Icon(Icons.credit_card),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            initialValue: selectedPaymentMode,
                            items: const [
                              DropdownMenuItem(
                                  value: 'Cash', child: Text('Cash')),
                              DropdownMenuItem(
                                  value: 'GCash', child: Text('GCash')),
                              DropdownMenuItem(
                                  value: 'PayMaya', child: Text('PayMaya')),
                              DropdownMenuItem(
                                  value: 'Go Tyme', child: Text('Go Tyme')),
                              DropdownMenuItem(
                                  value: 'Bank Transfer',
                                  child: Text('Bank Transfer')),
                              DropdownMenuItem(
                                  value: 'Others', child: Text('Others')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                selectedPaymentMode = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            totalController,
                            'Total Amount',
                            Icons.summarize_outlined, // neutral summary icon
                            number: true,
                          ),
                          const SizedBox(height: 10),
                          _buildTextField(
                            receivedMoneyController,
                            'Received Money',
                            Icons
                                .account_balance_wallet_outlined, // wallet icon
                            number: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Totals
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField(
                            changeController,
                            'Change',
                            Icons.change_circle, // change icon
                            number: true,
                            readOnly: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Update button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _updateBill,
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
                          "Update Bill",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  // Styled TextField
  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool number = false,
    bool readOnly = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    int? minLines,
    int? maxLines,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType ??
          (number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text),
      textInputAction: textInputAction,
      minLines: minLines,
      maxLines: maxLines,
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

// Helpers
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
