import 'package:dentease/widgets/background_container.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';


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
  final servDetController = TextEditingController();
  late TextEditingController clinicController;

  List<Map<String, dynamic>> diseases = []; // store disease_id + name
  String? selectedDiseaseId; // store UUID

  @override
  void initState() {
    super.initState();
    clinicController = TextEditingController(text: widget.clinicId);
    _fetchDiseases();
  }

  ///  Fetch diseases (id + name)
  Future<void> _fetchDiseases() async {
  try {
    final response =
        await supabase.from('disease').select('disease_id, disease_name');

    // Convert to List<Map<String, dynamic>>
    final fetchedDiseases = (response as List)
        .map((d) => {
              'id': d['disease_id'].toString(),
              'name': d['disease_name'].toString(),
            })
        .toList();

    //  Sort alphabetically by name
    fetchedDiseases.sort((a, b) => a['name']!.compareTo(b['name']!));

    //  Ensure "None" is always at the top
    final noneItem = fetchedDiseases.firstWhere(
      (d) => d['name']!.toLowerCase() == 'none',
      orElse: () => {},
    );

    if (noneItem.isNotEmpty) {
      fetchedDiseases.remove(noneItem);
      fetchedDiseases.insert(0, noneItem);
    }

    // Update state
    setState(() {
      diseases = fetchedDiseases;
    });
  } catch (e) {
    _showSnackbar("Error fetching diseases");
  }
}


  /// 🔹 Insert service
  Future<void> signUp() async {
    try {
      final servname = servNameController.text.trim();
      final servprice = servPriceController.text.trim();
      final servdet = servDetController.text.trim();
      final clinicId = clinicController.text.trim();

      if (servname.isEmpty || servprice.isEmpty || selectedDiseaseId == null) {
        _showSnackbar('Please fill in all required fields.');
        return;
      }

      await supabase.from('services').insert({
        'service_name': servname,
        'service_price': servprice,
        'service_detail': servdet,
        'clinic_id': clinicId,
        'disease_id': selectedDiseaseId, //  send disease_id (UUID)
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
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 10),
                _buildTextField(
                  servNameController,
                  'Service Name',
                  Icons.medical_services,
                  isMultiline: true,
                ),
                const SizedBox(height: 10),
                _buildTextField(
                    servPriceController, 'Service Price', Icons.money, isMultiline: true
                ),
                const SizedBox(height: 10),
                _buildTextField(
                    servDetController, 'Service Details', Icons.info, isMultiline:true ),
                const SizedBox(height: 10),

                /// Dropdown showing disease_name but storing disease_id
                DropdownButtonFormField<String>(
                  initialValue: selectedDiseaseId,
                  items: diseases
                      .map((disease) => DropdownMenuItem<String>(
                            value: disease['id'] as String, // UUID
                            child: Text(disease['name']), // Show name
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedDiseaseId = value;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: "Select Oral Problem",
                    prefixIcon:
                        Icon(Icons.coronavirus , color: Colors.indigo),
                  ),
                ),
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
      bool readOnly = false,
      bool isPassword = false,
      bool isMultiline = false,
      List<TextInputFormatter>? inputFormatters,
    }) {
      return TextField(
        controller: controller,
        obscureText: isPassword,
        inputFormatters: inputFormatters,
        readOnly: readOnly,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(icon, color: Colors.indigo[900]),
          ),
        ),
        keyboardType: isMultiline ? TextInputType.multiline : TextInputType.text,
        maxLines: isMultiline ? null : 1, // null = grow dynamically
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
          color: Colors.indigo[900],
        ),
      ),
    );
  }
}
