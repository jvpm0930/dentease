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

    // Only calculate if received >= total
    if (received >= total) {
      final change = received - total;
      setState(() {
        changeController.text = change.toStringAsFixed(2);
      });
    } else {
      // Clear change if received is less than total
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
        receivedMoneyController.text = result['recieved_money']?.toString() ?? '';
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
        SnackBar(content: Text("Error: Dind't update bill.")),
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
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            "Edit Bill",
            style: TextStyle(color: Colors.white),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(20.0),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildTextField(
                        serviceNameController,
                        'Service Name',
                        Icons.design_services,
                        readOnly: true,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        servicePriceController,
                        'Service Price',
                        Icons.money,
                        number: true,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        medicineFeeController,
                        'Medicine Fee',
                        Icons.medication,
                        number: true,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        doctorFeeController,
                        'Additional Fee',
                        Icons.person,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        minLines: 1, // starting height
                        maxLines: 5,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: "Payment Mode",
                          prefixIcon: const Icon(Icons.payment),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        value: selectedPaymentMode,
                        items: const [
                          DropdownMenuItem(value: 'Cash', child: Text('Cash')),
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
                        Icons.calculate,
                        number: true,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        receivedMoneyController,
                        'Received Money',
                        Icons.money_rounded,
                        number: true,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        changeController,
                        'Change',
                        Icons.change_circle,
                        number: true,
                        readOnly: true,
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _updateBill,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            "Update Bill",
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
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
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
