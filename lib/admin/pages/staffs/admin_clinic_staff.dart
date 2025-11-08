import 'package:dentease/admin/pages/staffs/admin_staff_details.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdmClinicStaffsPage extends StatefulWidget {
  final String clinicId;

  const AdmClinicStaffsPage({super.key, required this.clinicId});

  @override
  State<AdmClinicStaffsPage> createState() => _AdmClinicStaffsPageState();
}

class _AdmClinicStaffsPageState extends State<AdmClinicStaffsPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> staffs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStaffs();
  }

  Future<void> _fetchStaffs() async {
    try {
      // Fetching data including dentist_id
      final response = await supabase
          .from('staffs')
          .select(
              'staff_id, firstname, lastname, email') // Include dentist_id
          .eq('clinic_id', widget.clinicId);

      setState(() {
        staffs = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching staffs')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staffs List'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : staffs.isEmpty
              ? const Center(child: Text('No staffs found.'))
              : ListView.builder(
                  itemCount: staffs.length,
                  itemBuilder: (context, index) {
                    final staff = staffs[index];
                    final String fullName =
                        'Sec. ${staff['firstname'] ?? ''} ${staff['lastname'] ?? ''}';

                    return GestureDetector(
                      onTap: () {
                        // Navigate to DentistDetailsPage with dentist_id
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdmStaffDetailsPage(
                              staffId: staff['staff_id'],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 16),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color:
                              Colors.purple.shade50, // Light purple background
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fullName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  staff['email'] ?? 'No email available',
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.grey),
                                ),
                              ],
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
