import 'package:dentease/dentist/dentist_profile_update.dart';
import 'package:dentease/login/login_screen.dart';
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
      setState(() => isLoading = false);
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context, false),
            ),
            ElevatedButton(
              child: const Text('Logout'),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await Supabase.instance.client.auth.signOut();

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
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
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Profile Picture
                    Center(
                      child: CircleAvatar(
                        radius: 80,
                        backgroundColor: Colors.grey[300],
                        backgroundImage:
                            profileUrl != null && profileUrl!.isNotEmpty
                                ? NetworkImage(profileUrl!)
                                : const AssetImage('assets/default_profile.png')
                                    as ImageProvider,
                        child: profileUrl == null || profileUrl!.isEmpty
                            ? const Icon(Icons.person,
                                size: 60, color: Colors.grey)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Dentist Info Fields (read-only)
                    _buildInfoField(
                      label: "Firstname",
                      value: dentistDetails?['firstname'] ?? '',
                      icon: Icons.person,
                    ),
                    _buildInfoField(
                      label: "Lastname",
                      value: dentistDetails?['lastname'] ?? '',
                      icon: Icons.person_outline,
                    ),
                    _buildInfoField(
                      label: "Phone Number",
                      value: dentistDetails?['phone'] ?? '',
                      icon: Icons.phone,
                    ),
                    _buildInfoField(
                      label: "Role",
                      value: dentistDetails?['role'] ?? '',
                      icon: Icons.badge,
                    ),

                    const SizedBox(height: 30),

                    // Edit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final updated = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DentistProfUpdate(
                                  dentistId: widget.dentistId),
                            ),
                          );
                          if (updated == true) {
                            _fetchDentistDetails(); // refresh details
                          }
                        },
                        icon: const Icon(Icons.edit, color: Colors.white),
                        label: const Text(
                          'Edit Details',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await _logout(
                            (context),
                          );
                        },
                        icon: const Icon(Icons.logout, color: Colors.white),
                        label: const Text(
                          'Logout',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  /// Styled info display field (readonly)
  Widget _buildInfoField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          filled: true,
          fillColor: Colors.grey[200],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        controller: TextEditingController(text: value),
      ),
    );
  }
}
