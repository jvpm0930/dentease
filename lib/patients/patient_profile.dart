import 'package:dentease/patients/patient_prof_update.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PatientProfile extends StatefulWidget {
  final String patientId;

  const PatientProfile({super.key, required this.patientId});

  @override
  State<PatientProfile> createState() => _PatientProfileState();
}

class _PatientProfileState extends State<PatientProfile> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? patientDetails;
  bool isLoading = true;
  String? profileUrl;

  @override
  void initState() {
    super.initState();
    _fetchPatientDetails();
  }

  Future<void> _fetchPatientDetails() async {
    try {
      final response = await supabase
          .from('patients')
          .select('firstname, lastname, phone, role, profile_url')
          .eq('patient_id', widget.patientId)
          .single();

      setState(() {
        patientDetails = response;

        // Add cache-busting timestamp to profile URL
        final url = response['profile_url'];
        if (url != null && url.isNotEmpty) {
          profileUrl =
              '$url?timestamp=${DateTime.now().millisecondsSinceEpoch}';
        } else {
          profileUrl = null;
        }

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

  Widget _buildProfilePicture() {
    return CircleAvatar(
      radius: 50,
      backgroundColor: Colors.grey[300],
      backgroundImage: profileUrl != null && profileUrl!.isNotEmpty
          ? NetworkImage(profileUrl!)
          : const AssetImage('assets/profile.png') as ImageProvider,
    );
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
    return BackgroundCont(
        child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          "My Profile",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent, // Transparent AppBar
        elevation: 0, // Remove shadow
        iconTheme: const IconThemeData(color: Colors.white), // White icons
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _buildProfilePicture(),
                  const SizedBox(height: 16),
                  _buildTextField(patientDetails?['firstname'] ?? 'Firstname'),
                  _buildTextField(patientDetails?['lastname'] ?? 'Lastname'),
                  _buildTextField(patientDetails?['phone'] ?? 'Phone Number'),
                  _buildTextField(patientDetails?['role'] ?? 'Role'),

                  const SizedBox(height: 16),

                  // "Edit Details" Button
                  ElevatedButton(
                    onPressed: () async {
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PatientProfUpdate(patientId: widget.patientId),
                        ),
                      );

                      if (updated == true) {
                        _fetchPatientDetails(); // Refresh after update
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue, // Button color
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Edit Changes',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
    ));
  }
}
