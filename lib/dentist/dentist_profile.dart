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
          // Cache-buster
          profileUrl =
              '$url?timestamp=${DateTime.now().millisecondsSinceEpoch}';
        } else {
          profileUrl = null;
        }
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching dentist details: $e')),
        );
      }
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

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    }
  }

  // Match PatientProfile UI
  Widget _buildProfilePicture() {
    return CircleAvatar(
      radius: 80,
      backgroundColor: Colors.grey[300],
      backgroundImage: profileUrl != null && profileUrl!.isNotEmpty
          ? NetworkImage(profileUrl!)
          : const AssetImage('assets/profile.png') as ImageProvider,
    );
  }

  // Match PatientProfile UI
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
          Icon(icon, color: const Color(0xFF103D7E)),
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
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
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

                    // Info tiles (aligned with PatientProfile UI)
                    _buildInfoTile(Icons.person, "Firstname",
                        dentistDetails?['firstname'] ?? ''),
                    _buildInfoTile(Icons.person_outline, "Lastname",
                        dentistDetails?['lastname'] ?? ''),
                    _buildInfoTile(Icons.phone, "Phone Number",
                        dentistDetails?['phone'] ?? ''),
                    _buildInfoTile(
                        Icons.badge, "Role", dentistDetails?['role'] ?? ''),

                    const SizedBox(height: 20),

                    // Edit Button (style matches PatientProfile)
                    ElevatedButton.icon(
                      onPressed: () async {
                        final updated = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DentistProfUpdate(dentistId: widget.dentistId),
                          ),
                        );
                        if (updated == true) {
                          _fetchDentistDetails();
                        }
                      },
                      icon: const Icon(Icons.edit, color: Colors.white),
                      label: const Text(
                        'Edit Profile',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF103D7E),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Logout button (style matches PatientProfile)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async => await _logout(context),
                    ),

                    const SizedBox(height: 50),
                  ],
                ),
              ),
      ),
    );
  }
}
