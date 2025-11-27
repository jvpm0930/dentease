import 'package:dentease/widgets/background_cont.dart';
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
          .select('firstname, lastname, email, phone, role, profile_url')
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching dentist details')),
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
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: const Text('Dentist Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),)
          ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Center(child: _buildProfilePicture()),
                    const SizedBox(height: 16),
                    _buildInfoTile(Icons.person, "Firstname",
                        dentistDetails?['firstname'] ?? ''),
                    _buildInfoTile(Icons.person_outline, "Lastname",
                        dentistDetails?['lastname'] ?? ''),
                    _buildInfoTile(Icons.email, "Email",
                        dentistDetails?['email'] ?? ''),
                    _buildInfoTile(Icons.phone, "Phone",
                        dentistDetails?['phone'] ?? ''),
                    _buildInfoTile(Icons.badge, "Role",
                        dentistDetails?['role'] ?? ''),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
      ),
    );
  }
}
