import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BillCalculatorPage extends StatefulWidget {
  final String clinicId;
  final String patientId;
  final String bookingId;

  const BillCalculatorPage({
    super.key,
    required this.clinicId,
    required this.patientId,
    required this.bookingId,
  });

  @override
  State<BillCalculatorPage> createState() => _BillCalculatorPageState();
}

class _BillCalculatorPageState extends State<BillCalculatorPage> {
  final supabase = Supabase.instance.client;

  final serviceNameController = TextEditingController();
  final servicePriceController = TextEditingController();
  final receivedMoneyController = TextEditingController();

  double? change;
  String? patientName;

  @override
  void initState() {
    super.initState();
    _loadPatientName();
    servicePriceController.addListener(_calculateChange);
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
    final price = double.tryParse(servicePriceController.text);
    final received = double.tryParse(receivedMoneyController.text);

    setState(() {
      change = (price != null && received != null) ? (received - price) : null;
    });
  }

  Future<void> _submitBill() async {
    final serviceName = serviceNameController.text.trim();
    final servicePrice = double.tryParse(servicePriceController.text);
    final receivedMoney = double.tryParse(receivedMoneyController.text);

    if (serviceName.isEmpty || servicePrice == null) {
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
              content: Text("A bill already exists for this booking.")),
        );
        return;
      }

      final billChange =
          receivedMoney != null ? (receivedMoney - servicePrice) : null;

      final billData = {
        'service_name': serviceName,
        'service_price': servicePrice,
        'clinic_id': widget.clinicId,
        'patient_id': widget.patientId,
        'booking_id': widget.bookingId,
      };

      if (receivedMoney != null) {
        billData['recieved_money'] = receivedMoney;
        if (billChange != null) {
          billData['bill_change'] = billChange;
        } else {
          const SnackBar(content: Text("bill change = null"));
        }
      }

      await supabase.from('bills').insert(billData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bill submitted successfully.")),
      );

      serviceNameController.clear();
      servicePriceController.clear();
      receivedMoneyController.clear();
      setState(() {
        change = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Submission failed: ${e.toString()}")),
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
                  serviceNameController, 'Service Name', Icons.design_services),
              const SizedBox(height: 12),
              _buildTextField(
                  servicePriceController, 'Service Price', Icons.money,
                  number: true),
              const SizedBox(height: 12),
              _buildTextField(
                  receivedMoneyController, 'Received Money', Icons.money,
                  number: true),
              const SizedBox(height: 20),
              if (change != null)
                Text(
                  "Change: \$${change!.toStringAsFixed(2)}",
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green),
                ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _submitBill,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                child: const Text("Submit Bill",
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {bool number = false}) {
    return TextField(
      controller: controller,
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
