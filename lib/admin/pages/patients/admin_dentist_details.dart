import 'package:dentease/admin/pages/dentists/admin_dentist_update.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdmPatientDetailsPage extends StatefulWidget {
  final String patientId;

  const AdmPatientDetailsPage({super.key, required this.patientId});

  @override
  State<AdmPatientDetailsPage> createState() => _AdmPatientDetailsPageState();
}

class _AdmPatientDetailsPageState extends State<AdmPatientDetailsPage> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? patientDetails;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPatientDetails();
  }

  Future<void> _fetchPatientDetails() async {
    try {
      final response = await supabase
          .from('patients')
          .select('firstname, lastname, email, phone, role')
          .eq('patient_id', widget.patientId)
          .single();

      setState(() {
        patientDetails = response;
        isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching patient details: $e')),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildTextField(String hint) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        readOnly: true,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.grey[300],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patient Details')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/profile.png', height: 100, width: 100),
                  _buildTextField(patientDetails?['firstname'] ?? 'Firstname'),
                  _buildTextField(patientDetails?['lastname'] ?? 'Lastname'),
                  _buildTextField(patientDetails?['email'] ?? 'Email'),
                  _buildTextField(patientDetails?['phone'] ?? 'Phone'),
                  _buildTextField(patientDetails?['role'] ?? 'Role'),

                  const SizedBox(height: 16),

                  // "Edit Details" Button
                  ElevatedButton(
                    onPressed: () async {
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AdmEditDentistPage(dentistId: widget.patientId),
                        ),
                      );

                      if (updated == true) {
                        _fetchPatientDetails(); // Refresh after update
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.indigo,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Edit Details'),
                  ),
                ],
              ),
            ),
    );
  }
}
