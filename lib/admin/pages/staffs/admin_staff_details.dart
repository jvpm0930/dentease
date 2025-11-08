import 'package:dentease/admin/pages/staffs/admin_staff_update.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdmStaffDetailsPage extends StatefulWidget {
  final String staffId;

  const AdmStaffDetailsPage({super.key, required this.staffId});

  @override
  State<AdmStaffDetailsPage> createState() => _AdmStaffDetailsPageState();
}

class _AdmStaffDetailsPageState extends State<AdmStaffDetailsPage> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? staffDetails;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStaffDetails();
  }

  Future<void> _fetchStaffDetails() async {
    try {
      final response = await supabase
          .from('staffs')
          .select('firstname, lastname, email, phone, role')
          .eq('staff_id', widget.staffId)
          .single();

      setState(() {
        staffDetails = response;
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
      appBar: AppBar(title: const Text('Staff Details')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/profile.png', height: 100, width: 100),
                  _buildTextField(staffDetails?['firstname'] ?? 'Firstname'),
                  _buildTextField(staffDetails?['lastname'] ?? 'Lastname'),
                  _buildTextField(staffDetails?['email'] ?? 'Email'),
                  _buildTextField(staffDetails?['phone'] ?? 'Phone'),
                  _buildTextField(staffDetails?['role'] ?? 'Role'),

                  const SizedBox(height: 16),

                  // "Edit Details" Button
                  ElevatedButton(
                    onPressed: () async {
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AdmEditStaffPage(staffId: widget.staffId),
                        ),
                      );

                      if (updated == true) {
                        _fetchStaffDetails(); // Refresh after update
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
