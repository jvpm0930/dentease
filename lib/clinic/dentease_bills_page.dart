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

  final TextEditingController serviceNameController = TextEditingController();
  final TextEditingController servicePriceController = TextEditingController();
  final TextEditingController doctorFeeController = TextEditingController();
  final TextEditingController medicineFeeController = TextEditingController();
  final TextEditingController totalAmountController = TextEditingController();
  final TextEditingController receivedMoneyController = TextEditingController();

  double? change;
  String? billId;
  bool loading = true;
  String? patientName;

  @override
  void initState() {
    super.initState();
    _loadBill();
    _loadPatientName();
    servicePriceController.addListener(_calculateChange);
    doctorFeeController.addListener(_calculateChange);
    medicineFeeController.addListener(_calculateChange);
    receivedMoneyController.addListener(_calculateChange);
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

  void _calculateChange() {
    final price = double.tryParse(servicePriceController.text) ?? 0;
    final doctorFee = double.tryParse(doctorFeeController.text) ?? 0;
    final medicineFee = double.tryParse(medicineFeeController.text) ?? 0;
    final received = double.tryParse(receivedMoneyController.text);

    final total = price + doctorFee + medicineFee;
    totalAmountController.text = total.toStringAsFixed(2); // show total

    setState(() {
      change = (received != null) ? received - total : null;
    });
  }


  Future<void> _loadBill() async {
    try {
      // Fetch the specific service using its ID (widget.serviceId)
      final result = await supabase
          .from('services')
          .select('service_name, service_price')
          .eq('service_id', widget.serviceId) // or 'service_id', depending on your column name
          .maybeSingle();

      if (result != null) {
        // Set the values into text controllers
        serviceNameController.text = result['service_name'] ?? '';
        servicePriceController.text = result['service_price']?.toString() ?? '';
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


  Future<void> _submitBill() async {
    final serviceName = serviceNameController.text.trim();
    final servicePrice = double.tryParse(servicePriceController.text) ?? 0;
    final medicineFee = double.tryParse(medicineFeeController.text) ?? 0;
    final doctorFee = double.tryParse(doctorFeeController.text) ?? 0;
    final receivedMoney = double.tryParse(receivedMoneyController.text);

    if (serviceName.isEmpty || servicePrice == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter valid service data.")),
      );
      return;
    }

    try {
      // Check if a bill already exists for this booking_id
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

      // Safely calculate total and change
      final totalAmount = servicePrice + medicineFee + doctorFee;
      double? billChange;
      if (receivedMoney != null) {
        billChange = receivedMoney - totalAmount;
      }

      final billData = {
        'service_id': widget.serviceId,
        'service_name': serviceName,
        'service_price': servicePrice,
        'medicine_fee': medicineFee,
        'doctor_fee': doctorFee,
        'clinic_id': widget.clinicId,
        'patient_id': widget.patientId,
        'booking_id': widget.bookingId,
        'total_amount': totalAmount,
      };

      if (receivedMoney != null) {
        billData['recieved_money'] = receivedMoney;
        billData['bill_change'] = billChange ?? 0;
      }

      // Insert to Supabase
      await supabase.from('bills').insert(billData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bill submitted successfully.")),
      );

      // Clear fields and state
      serviceNameController.clear();
      servicePriceController.clear();
      medicineFeeController.clear();
      doctorFeeController.clear();
      receivedMoneyController.clear();
      setState(() {
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
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            "Bill for ${patientName ?? 'Loading...'}",
            style: TextStyle(color: Colors.white),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              _buildTextField(
                  serviceNameController, 'Service Name', Icons.design_services, readOnly: true,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                  servicePriceController, 'Service Price', Icons.money,
                  number: true, readOnly: true,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                  doctorFeeController, 'Doctor Fee', Icons.money,
                  number: true),
              const SizedBox(height: 12),
              _buildTextField(
                  medicineFeeController, 'Medicine Fee', Icons.money,
                  number: true),
              const SizedBox(height: 12),
              _buildTextField(
                totalAmountController,
                'Total Amount',
                Icons.calculate,
                number: true,
                readOnly: true, // make it not editable
              ),
              const SizedBox(height: 12),
              _buildTextField(receivedMoneyController, 'Received Money',
                  Icons.money_rounded,
                  number: true),
              const SizedBox(height: 20),
              if (change != null)
                Text(
                  "Change: PHP ${change!.toStringAsFixed(2)}",
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitBill,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    "Submit Bill",
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
