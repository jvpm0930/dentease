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

  double? change;
  String? billId;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadBill();

    servicePriceController.addListener(_calculateChange);
    doctorFeeController.addListener(_calculateChange);
    medicineFeeController.addListener(_calculateChange);
    receivedMoneyController.addListener(_calculateChange);
  }

  void _calculateChange() {
    final price = double.tryParse(servicePriceController.text);
    final doctorfee = double.tryParse(doctorFeeController.text);
    final medicincefee = double.tryParse(medicineFeeController.text);
    final received = double.tryParse(receivedMoneyController.text);

    setState(() {
      change = (price != null &&
              received != null &&
              doctorfee != null &&
              medicincefee != null)
          ? (received - (price + doctorfee + medicincefee))
          : null;
    });
  }

  Future<void> _loadBill() async {
    try {
      final result = await supabase
          .from('bills')
          .select()
          .eq('booking_id', widget.bookingId)
          .maybeSingle();

      if (result != null) {
        billId = result['id'].toString(); // assuming 'id' is the primary key
        serviceNameController.text = result['service_name'] ?? '';
        servicePriceController.text = result['service_price'].toString();
        doctorFeeController.text = result['doctor_fee'].toString();
        medicineFeeController.text = result['medicine_fee'].toString();
        receivedMoneyController.text = result['recieved_money'].toString();
        _calculateChange();
      }

      setState(() => loading = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading bill: ${e.toString()}")),
      );
      setState(() => loading = false);
    }
  }

  Future<void> _updateBill() async {
    final serviceName = serviceNameController.text.trim();
    final servicePrice = double.tryParse(servicePriceController.text);
    final medicineFee = double.tryParse(medicineFeeController.text);
    final doctorFee = double.tryParse(doctorFeeController.text);
    final receivedMoney = double.tryParse(receivedMoneyController.text);

    //  Basic validation
    if (serviceName.isEmpty ||
        servicePrice == null ||
        medicineFee == null ||
        doctorFee == null ||
        receivedMoney == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter valid inputs.")),
      );
      return;
    }

    final totalAmount = servicePrice + medicineFee + doctorFee;

    // Validation for received money
    if (receivedMoney < totalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Received money cannot be less than total amount."),
        ),
      );
      return;
    }

    final billChange = receivedMoney - totalAmount;

    try {
      await supabase.from('bills').update({
        'service_name': serviceName,
        'service_price': servicePrice,
        'doctor_fee': doctorFee,
        'medicine_fee': medicineFee,
        'recieved_money': receivedMoney,
        'bill_change': billChange,
        'total_amount': totalAmount,
      }).eq('booking_id', widget.bookingId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bill updated successfully.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }


  @override
  void dispose() {
    serviceNameController.dispose();
    servicePriceController.dispose();
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
                child: Column(
                  children: [
                    _buildTextField(serviceNameController, 'Service Name',
                        Icons.design_services, readOnly: true),
                    const SizedBox(height: 12),
                    _buildTextField(servicePriceController, 'Service Price',
                        Icons.money,
                        number: true, readOnly: true),
                    const SizedBox(height: 12),
                    _buildTextField(
                        doctorFeeController, 'Doctor Fee', Icons.money,
                        number: true),
                    const SizedBox(height: 12),
                    _buildTextField(
                        medicineFeeController, 'Medicine Price', Icons.money,
                        number: true),
                    const SizedBox(height: 12),
                    _buildTextField(receivedMoneyController, 'Received Money',
                        Icons.money_rounded,
                        number: true),
                    const SizedBox(height: 20),
                    if (change != null)
                      Text(
                        "Change: ${change!.toStringAsFixed(2)} php",
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black),
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
                    )
                  ],
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
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
