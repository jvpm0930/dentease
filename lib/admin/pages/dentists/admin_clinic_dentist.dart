import 'package:dentease/admin/pages/dentists/admin_dentist_details.dart';
import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdmClinicDentistsPage extends StatefulWidget {
  final String clinicId;

  const AdmClinicDentistsPage({super.key, required this.clinicId});

  @override
  State<AdmClinicDentistsPage> createState() => _AdmClinicDentistsPageState();
}

class _AdmClinicDentistsPageState extends State<AdmClinicDentistsPage > {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> dentists = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDentists();
  }

  Future<void> _fetchDentists() async {
    try {
      // Fetching data including dentist_id
      final response = await supabase
          .from('dentists')
          .select(
              'dentist_id, firstname, lastname, email') // Include dentist_id
          .eq('clinic_id', widget.clinicId);

      setState(() {
        dentists = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching dentists')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: const Text('Dentists List', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : dentists.isEmpty
                ? const Center(child: Text('No dentists found.'))
                : ListView.builder(
                    itemCount: dentists.length,
                    itemBuilder: (context, index) {
                      final dentist = dentists[index];
                      final String fullName =
                          'DR. ${dentist['firstname'] ?? ''} ${dentist['lastname'] ?? ''} M.D.';
      
                      return GestureDetector(
                        onTap: () {
                          // Navigate to DentistDetailsPage with dentist_id
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AdmDentistDetailsPage(
                                dentistId: dentist['dentist_id'],
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
                                    dentist['email'] ?? 'No email available',
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
      
      ),
    );
  }
}
