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

  String? selectedPaymentMode;
  final List<String> paymentModes = ['Cash', 'GCash', 'PayMaya', 'Go Tyme', 'Bank Transfer',
    'Others'
  ];

  @override
  void initState() {
    super.initState();
    _loadBill();
    _loadPatientName();

    receivedMoneyController.addListener(_calculateChange);
  }

  bool _hasShownWarning = false;

  void _calculateChange() {
    final total = double.tryParse(totalAmountController.text) ?? 0;
    final received = double.tryParse(receivedMoneyController.text) ?? 0;

    if (received < total && !_hasShownWarning) {
      _hasShownWarning = true; // prevent multiple SnackBars
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
    final servicePrice = servicePriceController.text.trim();
    final medicineFee = medicineFeeController.text.trim();
    final doctorFee = doctorFeeController.text.trim();
    final receivedMoney = receivedMoneyController.text;

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
      final receivedMoney = double.tryParse(receivedMoneyController.text) ?? 0;
      final totalAmount = double.tryParse(totalAmountController.text) ?? 0;

      if (receivedMoney < totalAmount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Received money must be greater than total amount."),
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


      if (selectedPaymentMode != null) {
        billData['payment_mode'] = selectedPaymentMode;
      }

      billData['recieved_money'] = receivedMoney;
      billData['bill_change'] = billChange ?? 0;
    
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
            style: const TextStyle(color: Colors.white),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  readOnly: true,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  medicineFeeController,
                  'Medicine Fee',
                  Icons.money,
                  number: true,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  doctorFeeController,
                  'Additional Fee',
                  Icons.money,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  minLines: 1, // starting height
                  maxLines: 5,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  totalAmountController,
                  'Total Amount',
                  Icons.calculate,
                  number: true,
                  readOnly: false,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedPaymentMode,
                  items: paymentModes
                      .map((mode) => DropdownMenuItem(
                            value: mode,
                            child: Text(mode),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedPaymentMode = value;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: "Mode of Payment",
                    prefixIcon: const Icon(Icons.payment),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  receivedMoneyController,
                  'Received Money',
                  Icons.money_rounded,
                  number: true,
                ),
                const SizedBox(height: 20),
                if (change != null)
                  Text(
                    "Change: PHP ${change!.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
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
