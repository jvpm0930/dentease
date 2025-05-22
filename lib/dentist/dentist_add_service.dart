import 'package:dentease/widgets/background_container.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DentistAddService extends StatefulWidget {
  final String clinicId;

  const DentistAddService({super.key, required this.clinicId});

  @override
  _DentistAddServiceState createState() => _DentistAddServiceState();
}

class _DentistAddServiceState extends State<DentistAddService> {
  final supabase = Supabase.instance.client;

  final servNameController = TextEditingController();
  final servPriceController = TextEditingController();
  late TextEditingController clinicController;

  @override
  void initState() {
    super.initState();
    clinicController = TextEditingController(text: widget.clinicId);
  }

  Future<void> signUp() async {
    try {
      final servname = servNameController.text.trim();
      final servprice = servPriceController.text.trim();
      final clinicId = clinicController.text.trim();

      if (servname.isEmpty || servprice.isEmpty) {
        _showSnackbar('Please fill in all required fields.');
        return;
      }

      await supabase.from('services').insert({
        'service_name': servname,
        'service_price': servprice,
        'clinic_id': clinicId,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add Service successfully!')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      _showSnackbar('Error: $e');
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            "Add Services",
            style: TextStyle(color: Colors.white),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent, // Transparent AppBar
          elevation: 0, // Remove shadow
          iconTheme: const IconThemeData(color: Colors.white), // White icons
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 10),
                _buildTextField(
                    servNameController, 'Service Name', Icons.medical_services),
                const SizedBox(height: 10),
                _buildTextField(
                    servPriceController, 'Service Price', Icons.price_change),
                const SizedBox(height: 20),
                _buildSignUpButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword,
      readOnly: readOnly,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(icon, color: Colors.indigo[900]),
        ),
      ),
    );
  }

  Widget _buildSignUpButton() {
    return ElevatedButton(
      onPressed: signUp,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[300],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        padding: const EdgeInsets.symmetric(vertical: 13),
        minimumSize: const Size(400, 20),
        elevation: 0,
      ),
      child: Text(
        'Add Service',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.indigo[900], // Fixed this line
        ),
      ),
    );
  }
}
