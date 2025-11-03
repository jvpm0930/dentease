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
          .select(
              'firstname, lastname, phone, role, profile_url, gender, age, password')
          .eq('patient_id', widget.patientId)
          .single();

      setState(() {
        patientDetails = response;

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
      radius: 80,
      backgroundColor: Colors.grey[300],
      backgroundImage: profileUrl != null && profileUrl!.isNotEmpty
          ? NetworkImage(profileUrl!)
          : const AssetImage('assets/profile.png') as ImageProvider,
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 14, color: Colors.grey, height: 1.3)),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : 'N/A',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
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
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListView(
                  children: [
                    const SizedBox(height: 10),
                    Center(child: _buildProfilePicture()),
                    const SizedBox(height: 16),

                    // Profile Information
                    _buildInfoTile(Icons.person, "Firstname",
                        patientDetails?['firstname'] ?? ''),
                    _buildInfoTile(Icons.person_outline, "Lastname",
                        patientDetails?['lastname'] ?? ''),
                    _buildInfoTile(Icons.calculate, "Age",
                        patientDetails?['age']?.toString() ?? ''),
                    _buildInfoTile(Icons.wc_rounded, "Gender",
                        patientDetails?['gender'] ?? ''),
                    _buildInfoTile(Icons.phone, "Phone Number",
                        patientDetails?['phone'] ?? ''),
                    _buildInfoTile(
                        Icons.badge, "Role", patientDetails?['role'] ?? ''),
                    _buildInfoTile(Icons.lock, "Password",
                        patientDetails?[''] ?? '******'),

                    const SizedBox(height: 30),

                    // Edit Button
                    ElevatedButton.icon(
                        onPressed: () async {
                          final updated = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PatientProfUpdate(
                                  patientId: widget.patientId),
                            ),
                          );

                          if (updated == true) {
                            _fetchPatientDetails();
                          }
                        },
                        icon: const Icon(Icons.edit, color: Colors.white),
                        label: const Text(
                          'Edit Profile',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
      ),
    );
  }
}
