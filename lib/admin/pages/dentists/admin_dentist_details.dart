import 'package:dentease/admin/pages/dentists/admin_dentist_update.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdmDentistDetailsPage extends StatefulWidget {
  final String dentistId;

  const AdmDentistDetailsPage({super.key, required this.dentistId});

  @override
  State<AdmDentistDetailsPage> createState() => _AdmDentistDetailsPageState();
}

class _AdmDentistDetailsPageState extends State<AdmDentistDetailsPage> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? dentistDetails;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDentistDetails();
  }

  Future<void> _fetchDentistDetails() async {
    try {
      final response = await supabase
          .from('dentists')
          .select('firstname, lastname, email, phone, role')
          .eq('dentist_id', widget.dentistId)
          .single();

      setState(() {
        dentistDetails = response;
        isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching dentist details')),
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
      appBar: AppBar(title: const Text('Dentist Details')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/profile.png', height: 100, width: 100),
                  _buildTextField(dentistDetails?['firstname'] ?? 'Firstname'),
                  _buildTextField(dentistDetails?['lastname'] ?? 'Lastname'),
                  _buildTextField(dentistDetails?['email'] ?? 'Email'),
                  _buildTextField(dentistDetails?['phone'] ?? 'Phone'),
                  _buildTextField(dentistDetails?['role'] ?? 'Role'),

                  const SizedBox(height: 16),

                  // "Edit Details" Button
                  ElevatedButton(
                    onPressed: () async {
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AdmEditDentistPage(dentistId: widget.dentistId),
                        ),
                      );

                      if (updated == true) {
                        _fetchDentistDetails(); // Refresh after update
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
