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
  String selectedStatus = 'pending';
  static const kPrimary = Color(0xFF1134A6);

  @override
  void initState() {
    super.initState();
    _fetchDentistDetails();
  }

  Future<void> _fetchDentistDetails() async {
    try {
      final response = await supabase
          .from('dentists')
          .select(
              'firstname, lastname, email, phone, role, profile_url, status, specialization, qualification, experience_years')
          .eq('dentist_id', widget.dentistId)
          .single();

      setState(() {
        dentistDetails = response;
        selectedStatus = response['status'] ?? 'pending';
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
        const SnackBar(content: Text('Error fetching dentist details')),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateStatus() async {
    try {
      await supabase.from('dentists').update({'status': selectedStatus}).eq(
          'dentist_id', widget.dentistId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status updated successfully')),
        );
        Navigator.pop(context); // Optional: go back to list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
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
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1134A6)),
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

  Widget _buildStatusSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Update Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: kPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedStatus,
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(
                        value: 'approved', child: Text('Approved')),
                    DropdownMenuItem(
                        value: 'rejected', child: Text('Rejected')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => selectedStatus = val);
                  },
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _updateStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Update'),
              ),
            ],
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
            leading: const BackButton(color: Colors.black),
            foregroundColor: Colors.white,
            title: const Text(
              'Dentist Details',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            )),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
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
                    _buildInfoTile(
                        Icons.email, "Email", dentistDetails?['email'] ?? ''),
                    _buildInfoTile(
                        Icons.phone, "Phone", dentistDetails?['phone'] ?? ''),
                    _buildInfoTile(
                        Icons.badge, "Role", dentistDetails?['role'] ?? ''),
                    _buildInfoTile(Icons.medical_services, "Specialization",
                        dentistDetails?['specialization'] ?? ''),
                    _buildInfoTile(Icons.school, "Qualification",
                        dentistDetails?['qualification'] ?? ''),
                    _buildInfoTile(Icons.work_history, "Years of Experience",
                        dentistDetails?['experience_years']?.toString() ?? ''),
                    _buildInfoTile(
                        Icons.info_outline,
                        "Status",
                        dentistDetails?['status']?.toString().toUpperCase() ??
                            'PENDING'),
                    const SizedBox(height: 20),
                    _buildStatusSection(),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
      ),
    );
  }
}
