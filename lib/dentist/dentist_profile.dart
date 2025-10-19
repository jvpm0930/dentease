import 'package:dentease/clinic/models/adminChat_supportList.dart';
import 'package:dentease/clinic/models/clinicChat_support.dart';
import 'package:dentease/dentist/dentist_profile_update.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DentistProfile extends StatefulWidget {
  final String dentistId;

  const DentistProfile({super.key, required this.dentistId});

  @override
  State<DentistProfile> createState() => _DentistProfileState();
}

class _DentistProfileState extends State<DentistProfile> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? dentistDetails;
  bool isLoading = true;
  String? profileUrl;

  @override
  void initState() {
    super.initState();
    _fetchDentistDetails();
  }

  Future<void> _fetchDentistDetails() async {
    try {
      final response = await supabase
          .from('dentists')
          .select('firstname, lastname, phone, role, profile_url')
          .eq('dentist_id', widget.dentistId)
          .single();

      setState(() {
        dentistDetails = response;

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
        SnackBar(content: Text('Error fetching dentist details: $e')),
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
          : const AssetImage('assets/default_profile.png') as ImageProvider,
      child: profileUrl == null || profileUrl!.isEmpty
          ? const Icon(Icons.person, size: 50, color: Colors.grey)
          : null,
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
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Profile Picture
                    _buildProfilePicture(),
                    const SizedBox(height: 16),
                    _buildTextField(
                        dentistDetails?['firstname'] ?? 'Firstname'),
                    _buildTextField(dentistDetails?['lastname'] ?? 'Lastname'),
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
                                DentistProfUpdate(dentistId: widget.dentistId),
                          ),
                        );

                        // If details were updated, refresh profile and update cache
                        if (updated == true) {
                          _fetchDentistDetails(); // Refresh after update
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue, // Button color
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 12),
                      ),
                      child: const Text(
                        'Edit Details',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
